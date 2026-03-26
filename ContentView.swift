// ContentView.swift
// macOS root layout: 3-column NavigationSplitView

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: GoalStore
    @State private var showAddGoal = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // ── Sidebar ──────────────────────────────────
            SidebarView(showAddGoal: $showAddGoal)
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 280)
        } content: {
            // ── Middle: Calendar dashboard ───────────────
            CalendarDashboardView()
                .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 420)
        } detail: {
            // ── Detail: Goal steps ───────────────────────
            if let goal = store.selectedGoal {
                GoalDetailView(goal: goal)
            } else {
                EmptyDetailView()
            }
        }
        .sheet(isPresented: $showAddGoal) {
            AddGoalView(isPresented: $showAddGoal)
                .environmentObject(store)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showAddGoal)) { _ in
            showAddGoal = true
        }
        .background(Color(hex: "0D0D12"))
    }
}
