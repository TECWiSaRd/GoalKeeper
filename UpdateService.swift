// UpdateService.swift
// Checks for app updates via a hosted version.json and downloads new DMG releases

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
    case readyToInstall(dmgURL: URL)
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

    // ⚠️ Replace with your GitHub raw URL after setting up your repo:
    // Format: https://raw.githubusercontent.com/USERNAME/REPO/main/version.json
    static let manifestURL = "https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/GoalKeeper/main/version.json"

    @Published var state: UpdateState = .idle
    @Published var currentVersion: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }()

    private var downloadTask: URLSessionDownloadTask?
    private lazy var session: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: .main)
    }()

    // MARK: - Check for updates
    func checkForUpdates() async {
        state = .checking
        do {
            guard let url = URL(string: Self.manifestURL) else {
                state = .error("Invalid manifest URL"); return
            }
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                state = .error("Could not reach update server"); return
            }
            let manifest = try JSONDecoder().decode(VersionManifest.self, from: data)
            guard let remote = AppVersion(manifest.version),
                  let local  = AppVersion(currentVersion) else {
                state = .error("Could not parse version numbers"); return
            }
            if remote > local {
                state = .available(manifest: manifest)
            } else {
                state = .upToDate
            }
        } catch {
            state = .error(error.localizedDescription)
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

    // MARK: - URLSessionDownloadDelegate
    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didWriteData bytesWritten: Int64,
                                totalBytesWritten: Int64,
                                totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in
            self.state = .downloading(progress: progress)
        }
    }

    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didFinishDownloadingTo location: URL) {
        // Move DMG to Downloads folder
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let filename   = downloadTask.originalRequest?.url?.lastPathComponent ?? "GoalKeeper.dmg"
        let dest       = downloads.appendingPathComponent(filename)

        try? FileManager.default.removeItem(at: dest)
        do {
            try FileManager.default.moveItem(at: location, to: dest)
            Task { @MainActor in
                self.state = .readyToInstall(dmgURL: dest)
            }
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
        // Ignore cancellation
        if (error as NSError).code == NSURLErrorCancelled { return }
        Task { @MainActor in
            self.state = .error(error.localizedDescription)
        }
    }

    // MARK: - Auto-install: mount DMG, replace existing app, relaunch
    func installUpdate(_ dmgURL: URL) {
        state = .downloading(progress: 1.0)
        Task.detached {
            do {
                // 1. Mount the DMG silently
                let mountPoint = try await self.mountDMG(dmgURL)

                // 2. Find the .app inside the mounted volume
                let contents = try FileManager.default.contentsOfDirectory(
                    at: mountPoint, includingPropertiesForKeys: nil)
                guard let appInDMG = contents.first(where: { $0.pathExtension == "app" }) else {
                    throw InstallError.appNotFoundInDMG
                }

                // 3. Destination = same location as the currently running app
                let destination = URL(fileURLWithPath: Bundle.main.bundlePath)

                // 4. Replace the existing app with the new one (no duplicate)
                _ = try FileManager.default.replaceItemAt(destination, withItemAt: appInDMG)

                // 5. Unmount the DMG
                try await self.unmountDMG(mountPoint)

                // 6. Delete the downloaded DMG from Downloads
                try? FileManager.default.removeItem(at: dmgURL)

                // 7. Relaunch from the updated location
                await MainActor.run {
                    let task = Process()
                    task.launchPath = "/usr/bin/open"
                    task.arguments  = [destination.path]
                    try? task.run()
                    NSApp.terminate(nil)
                }
            } catch {
                await MainActor.run {
                    self.state = .error("Install failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Mount / unmount helpers
    private func mountDMG(_ url: URL) async throws -> URL {
        let output = try await runProcess(
            "/usr/bin/hdiutil",
            arguments: ["attach", url.path, "-nobrowse", "-noautoopen", "-plist"]
        )
        guard let data = output.data(using: .utf8),
              let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]],
              let mountPath = entities.compactMap({ $0["mount-point"] as? String }).first
        else { throw InstallError.mountFailed }
        return URL(fileURLWithPath: mountPath)
    }

    private func unmountDMG(_ mountPoint: URL) async throws {
        try await runProcess("/usr/bin/hdiutil",
                             arguments: ["detach", mountPoint.path, "-quiet"])
    }

    @discardableResult
    private func runProcess(_ launchPath: String, arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let pipe    = Pipe()
            process.launchPath     = launchPath
            process.arguments      = arguments
            process.standardOutput = pipe
            process.terminationHandler = { _ in
                let data   = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: output)
            }
            do    { try process.run() }
            catch { continuation.resume(throwing: error) }
        }
    }

    enum InstallError: LocalizedError {
        case appNotFoundInDMG, mountFailed
        var errorDescription: String? {
            switch self {
            case .appNotFoundInDMG: return "Could not find GoalKeeper.app inside the update."
            case .mountFailed:      return "Could not mount the downloaded update file."
            }
        }
    }
}
