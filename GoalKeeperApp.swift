// GoalKeeperApp.swift
// macOS entry point for GoalKeeper

import SwiftUI

@main
struct GoalKeeperApp: App {
    @StateObject private var goalStore = GoalStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(goalStore)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1200, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Goal…") {
                    NotificationCenter.default.post(name: .showAddGoal, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }

        // Settings window — appears under GoalKeeper → Settings… (⌘,)
        Settings {
            SettingsView()
        }
    }
}

extension Notification.Name {
    static let showAddGoal = Notification.Name("ShowAddGoal")
}
