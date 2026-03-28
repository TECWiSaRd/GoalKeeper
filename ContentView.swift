// ContentView.swift
// macOS root layout: 3-column NavigationSplitView

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: GoalStore
    @State private var showAddGoal     = false
    @State private var showImport      = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(showAddGoal: $showAddGoal, showImport: $showImport)
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 280)
        } content: {
            CalendarDashboardView()
                .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 420)
        } detail: {
            switch store.detailSelection {
            case .goal:
                if let goal = store.selectedGoal {
                    GoalDetailView(goal: goal)
                } else {
                    EmptyDetailView()
                }
            case .scheduleItem:
                if let item = store.selectedScheduleItem {
                    ScheduleDetailView(item: item)
                } else {
                    EmptyDetailView()
                }
            case .none:
                EmptyDetailView()
            }
        }
        .sheet(isPresented: $showAddGoal) {
            AddGoalView(isPresented: $showAddGoal)
                .environmentObject(store)
        }
        .sheet(isPresented: $showImport) {
            ImportScheduleView(isPresented: $showImport)
                .environmentObject(store)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showAddGoal)) { _ in
            showAddGoal = true
        }
        .background(Color(hex: "0D0D12"))
    }
}
