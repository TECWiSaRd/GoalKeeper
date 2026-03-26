// UpdateService.swift
// Checks for app updates via version.json on GitHub and installs from GoalKeeper.zip

import Foundation
import AppKit
import Combine

// MARK: - Version manifest (matches version.json on GitHub)
struct VersionManifest: Decodable {
    let version: String
    let url: String
    let notes: String
}

// MARK: - Comparable version struct
struct AppVersion: Comparable, Equatable {
    let major: Int
    let minor: Int
    let patch: Int

    init?(_ string: String) {
        let parts = string
            .trimmingCharacters(in: CharacterSet(charactersIn: "v"))
            .split(separator: ".")
            .compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        major = parts[0]; minor = parts[1]; patch = parts[2]
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    var string: String { "\(major).\(minor).\(patch)" }
}

// MARK: - Update state
enum UpdateState: Equatable {
    case idle
    case checking
    case upToDate
    case available(manifest: VersionManifest)
    case downloading(progress: Double)
    case readyToInstall(zipURL: URL)
    case error(String)

    static func == (lhs: UpdateState, rhs: UpdateState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.checking, .checking), (.upToDate, .upToDate): return true
        case (.downloading(let a), .downloading(let b)): return a == b
        case (.readyToInstall(let a), .readyToInstall(let b)): return a == b
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - Service
class UpdateService: NSObject, ObservableObject, URLSessionDownloadDelegate {

    static let shared = UpdateService()

    // Replace with your GitHub raw URL:
    // https://raw.githubusercontent.com/YOUR_USERNAME/GoalKeeper/main/version.json
    static let manifestURL = "https://raw.githubusercontent.com/TECWiSaRd/GoalKeeper/main/version.json"

    @Published var state: UpdateState = .idle
    @Published var currentVersion: String = {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return v
    }()

    private var downloadTask: URLSessionDownloadTask?
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForResource = 300
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()

    // MARK: - Check for updates
    func checkForUpdates() async {
           await MainActor.run { state = .checking }
           do {
               guard let url = URL(string: Self.manifestURL) else {
                   await MainActor.run { state = .error("Invalid manifest URL") }
                   return
               }
               let (data, response) = try await URLSession.shared.data(from: url)
               guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                   await MainActor.run { state = .error("Could not reach update server") }
                   return
               }
               let manifest = try JSONDecoder().decode(VersionManifest.self, from: data)
               guard let remote = AppVersion(manifest.version),
                     let local  = AppVersion(currentVersion) else {
                   await MainActor.run { state = .error("Could not parse version numbers") }
                   return
               }
               await MainActor.run {
                   state = remote > local ? .available(manifest: manifest) : .upToDate
               }
           } catch {
               await MainActor.run { state = .error(error.localizedDescription) }
           }
       }
    // MARK: - Download update
    func downloadUpdate(from urlString: String) {
        guard let url = URL(string: urlString) else {
            state = .error("Invalid download URL"); return
        }
        state = .downloading(progress: 0)
        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        state = .idle
    }
    
    nonisolated func urlSession(_ session: URLSession,
                                task: URLSessionTask,
                                willPerformHTTPRedirection response: HTTPURLResponse,
                                newRequest request: URLRequest,
                                completionHandler: @escaping (URLRequest?) -> Void) {
        print("↪️ Redirecting to: \(request.url?.absoluteString ?? "nil")")
        completionHandler(request)
    }

    // MARK: - URLSessionDownloadDelegate
    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didWriteData bytesWritten: Int64,
                                totalBytesWritten: Int64,
                                totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in self.state = .downloading(progress: progress) }
    }

    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didFinishDownloadingTo location: URL) {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GoalKeeper_update.zip")
        try? FileManager.default.removeItem(at: tmp)
        do {
            try FileManager.default.moveItem(at: location, to: tmp)
            Task { @MainActor in self.state = .readyToInstall(zipURL: tmp) }
        } catch {
            Task { @MainActor in
                self.state = .error("Could not save update: \(error.localizedDescription)")
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession,
                                task: URLSessionTask,
                                didCompleteWithError error: Error?) {
        guard let error = error else { return }
        if (error as NSError).code == NSURLErrorCancelled { return }
        Task { @MainActor in self.state = .error(error.localizedDescription) }
    }

    // MARK: - Install from ZIP
    func installUpdate(_ zipURL: URL) {
        state = .downloading(progress: 1.0)
        Task.detached {
            do {
                let fm = FileManager.default

                // 1. Unzip into a temp directory
                let extractDir = fm.temporaryDirectory
                    .appendingPathComponent("GoalKeeper_extracted")
                try? fm.removeItem(at: extractDir)
                            try fm.createDirectory(at: extractDir, withIntermediateDirectories: true)

                            let zipExists = fm.fileExists(atPath: zipURL.path)
                            let zipSize = (try? fm.attributesOfItem(atPath: zipURL.path)[.size] as? Int) ?? 0
                            print("📥 ZIP exists: \(zipExists), size: \(zipSize) bytes")

                            let unzipOutput = try await self.runProcess("/usr/bin/unzip",
                                                     arguments: [zipURL.path,
                                                                 "-d", extractDir.path])
                            print("📦 Unzip output: \(unzipOutput)")

                            let debugItems = try fm.contentsOfDirectory(atPath: extractDir.path)
                            print("📂 Extracted contents: \(debugItems)")

                // 2. Find GoalKeeper.app inside the extracted folder
                guard let newApp = try self.findApp(in: extractDir) else {
                    throw InstallError.appNotFoundInZip
                }

                // 3. Replace the running app in-place — no duplicate created
                let currentApp = URL(fileURLWithPath: Bundle.main.bundlePath)
                _ = try fm.replaceItemAt(currentApp, withItemAt: newApp)

                // 4. Clean up
                try? fm.removeItem(at: zipURL)
                try? fm.removeItem(at: extractDir)

                // 5. Relaunch updated app and quit old one
                
                    let task = Process()
                    task.launchPath = "/usr/bin/open"
                    task.arguments  = ["/Applications/GoalKeeper.app"]
                    try? task.run()
                    
                    // Wait a moment to ensure the open command fires before quitting
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    
                    await MainActor.run {
                        NSApp.terminate(nil)
                    
                }
            } catch {
                await MainActor.run {
                    self.state = .error("Install failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // Recursively finds the first .app bundle in a directory
    private func findApp(in dir: URL) throws -> URL? {
        let fm    = FileManager.default
        let items = try fm.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isDirectoryKey])
        if let app = items.first(where: { $0.pathExtension == "app" }) { return app }
        for item in items {
            let vals = try item.resourceValues(forKeys: [.isDirectoryKey])
            if vals.isDirectory == true, let app = try findApp(in: item) { return app }
        }
        return nil
    }

    // MARK: - Process runner
    @discardableResult
    private func runProcess(_ launchPath: String, arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let pipe    = Pipe()
            process.launchPath     = launchPath
            process.arguments      = arguments
            process.standardOutput = pipe
            process.standardError  = pipe
            process.terminationHandler = { _ in
                let data   = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
            }
            do    { try process.run() }
            catch { continuation.resume(throwing: error) }
        }
    }

    // MARK: - Errors
    enum InstallError: LocalizedError {
        case appNotFoundInZip
        var errorDescription: String? {
            "Could not find GoalKeeper.app inside the downloaded ZIP."
        }
    }
}
