// SettingsView.swift
// Settings window — API key entry + in-app update checker

import SwiftUI
import AppKit
import Combine

struct SettingsView: View {
    // API key state
    @State private var keyInput  = ""
    @State private var isSaved   = false
    @State private var isVisible = false
    @State private var selectedModel: String = KeychainService.selectedModel

    // Updates
    @ObservedObject private var updater = UpdateService.shared
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                apiKeySection
                Divider().background(Color.white.opacity(0.08))
                modelSection
                Divider().background(Color.white.opacity(0.08))
                updatesSection
            }
            .padding(28)
        }
        .frame(width: 480, height: 520)
        .background(Color(hex: "111118"))
        .onAppear {
            keyInput = KeychainService.load() ?? ""
            Task { await updater.checkForUpdates() }
        }
    }

    // MARK: - API Key Section
    var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Anthropic API Key", icon: "key.fill")

            Text("GoalKeeper uses the Anthropic Claude API to analyze your goals. Each user needs their own free API key from console.anthropic.com.")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "8E8EA0"))
                .lineSpacing(4)

            // Key field
            VStack(alignment: .leading, spacing: 6) {
                Text("API KEY")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "5A5A72"))
                    .kerning(0.8)

                HStack {
                    Group {
                        if isVisible {
                            TextField("sk-ant-...", text: $keyInput)
                        } else {
                            SecureField("sk-ant-...", text: $keyInput)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white)

                    Button {
                        isVisible.toggle()
                    } label: {
                        Image(systemName: isVisible ? "eye.slash" : "eye")
                            .foregroundColor(Color(hex: "5A5A72"))
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(Color.white.opacity(0.06))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1)))
            }

            HStack(spacing: 10) {
                Button {
                    KeychainService.save(keyInput)
                    withAnimation { isSaved = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { isSaved = false }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isSaved ? "checkmark.circle.fill" : "key.fill")
                        Text(isSaved ? "Saved!" : "Save Key")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(isSaved ? Color.green : Color(hex: "4ECDC4"))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty)

                if KeychainService.hasKey {
                    Button {
                        KeychainService.delete()
                        keyInput = ""
                    } label: {
                        Text("Remove Key")
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Link("Get a free key →", destination: URL(string: "https://console.anthropic.com")!)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "4ECDC4"))
            }

            if KeychainService.hasKey && keyInput.isEmpty {
                Label("API key is saved", systemImage: "checkmark.shield.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
            }
        }
    }

    
    
    var modelSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("AI Model", icon: "cpu.fill")

            Text("Choose the Claude model used to analyze your goals. Faster models are cheaper but slightly less detailed.")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "8E8EA0"))
                .lineSpacing(4)

            VStack(spacing: 6) {
                modelOption(
                    id: "claude-haiku-4-5",
                    name: "Haiku",
                    description: "Fastest · Cheapest · Great for most goals",
                    badge: "Recommended",
                    badgeColor: Color(hex: "4ECDC4")
                )
                modelOption(
                    id: "claude-sonnet-4-6",
                    name: "Sonnet",
                    description: "Balanced speed and quality",
                    badge: "~5× more",
                    badgeColor: .orange
                )
                modelOption(
                    id: "claude-opus-4-5",
                    name: "Opus",
                    description: "Most detailed · Best for complex goals",
                    badge: "~25× more",
                    badgeColor: .red
                )
            }
        }
    }

    func modelOption(id: String, name: String, description: String, badge: String, badgeColor: Color) -> some View {
        let isSelected = selectedModel == id
        return Button {
            selectedModel = id
            KeychainService.selectedModel = id
        } label: {
            HStack(spacing: 12) {
                // Radio circle
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color(hex: "4ECDC4") : Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 18, height: 18)
                    if isSelected {
                        Circle()
                            .fill(Color(hex: "4ECDC4"))
                            .frame(width: 10, height: 10)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "8E8EA0"))
                }

                Spacer()

                Text(badge)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(badgeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(badgeColor.opacity(0.15))
                    .cornerRadius(6)
            }
            .padding(10)
            .background(isSelected ? Color(hex: "4ECDC4").opacity(0.07) : Color.white.opacity(0.04))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color(hex: "4ECDC4").opacity(0.3) : Color.white.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }
    // MARK: - Updates Section
    var updatesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Updates", icon: "arrow.down.circle.fill")

            HStack(alignment: .center, spacing: 14) {
                // App icon placeholder
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "4ECDC4").opacity(0.15))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(hex: "4ECDC4"))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("GoalKeeper")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Version \(updater.currentVersion)")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "8E8EA0"))
                }

                Spacer()

                updateStatusBadge
            }

            updateActionArea
        }
    }

    // MARK: - Update status badge
    @ViewBuilder
    var updateStatusBadge: some View {
        switch updater.state {
        case .idle, .checking:
            HStack(spacing: 6) {
                if case .checking = updater.state {
                    ProgressView().controlSize(.small).tint(Color(hex: "8E8EA0"))
                }
                Text(updater.state == .checking ? "Checking…" : "")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "8E8EA0"))
            }

        case .upToDate:
            Label("Up to date", systemImage: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.green)

        case .available(let manifest):
            Text("v\(manifest.version) available")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(hex: "FFE66D"))
                .cornerRadius(6)

        case .downloading(let progress):
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(Color(hex: "4ECDC4"))
                    .frame(width: 80)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "8E8EA0"))
            }

        case .readyToInstall:
            Label("Downloaded", systemImage: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.green)

        case .error:
            Label("Error", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(.red)
        }
    }

    // MARK: - Update action area
    @ViewBuilder
    var updateActionArea: some View {
        switch updater.state {
        case .available(let manifest):
            VStack(alignment: .leading, spacing: 10) {
                if !manifest.notes.isEmpty {
                    Text(manifest.notes)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "8E8EA0"))
                        .lineSpacing(3)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(8)
                }

                HStack(spacing: 10) {
                    Button {
                        updater.downloadUpdate(from: manifest.url)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Download Update")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: "4ECDC4"))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task { await updater.checkForUpdates() }
                    } label: {
                        Text("Later")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "8E8EA0"))
                    }
                    .buttonStyle(.plain)
                }
            }

        case .downloading:
            Button {
                updater.cancelDownload()
            } label: {
                Text("Cancel")
                    .font(.system(size: 13))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)

        case .readyToInstall(let dmgURL):
            VStack(alignment: .leading, spacing: 8) {
                Text("Ready to install. GoalKeeper will quit and you'll need to reopen it manually.")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "8E8EA0"))
                    .lineSpacing(3)

                HStack(spacing: 10) {
                    Button {
                        updater.installUpdate(dmgURL)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.forward.app.fill")
                            Text("Install")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: "4ECDC4"))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }

        case .error(let msg):
            HStack(spacing: 10) {
                Text(msg)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .lineLimit(2)
                Spacer()
                Button {
                    Task { await updater.checkForUpdates() }
                } label: {
                    Text("Retry")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "4ECDC4"))
                }
                .buttonStyle(.plain)
            }

        case .upToDate:
            Button {
                Task { await updater.checkForUpdates() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                    Text("Check Again")
                        .font(.system(size: 12))
                }
                .foregroundColor(Color(hex: "8E8EA0"))
            }
            .buttonStyle(.plain)

        default:
            EmptyView()
        }
    }

    // MARK: - Section header helper
    func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundColor(.white)
    }
}
