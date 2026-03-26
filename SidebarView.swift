// SidebarView.swift
// Left sidebar: goal list grouped by status

import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: GoalStore
    @Binding var showAddGoal: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Goals")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(store.activeGoals.count) active · \(store.completedGoals.count) done")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "5A5A72"))
                }
                Spacer()
                Button {
                    showAddGoal = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(hex: "4ECDC4"))
                }
                .buttonStyle(.plain)
                .help("New Goal (⌘N)")
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().background(Color.white.opacity(0.08))

            // Overdue warning
            if !store.overdueGoals.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                    Text("\(store.overdueGoals.count) overdue")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.08))
            }

            // Goal list
            ScrollView {
                LazyVStack(spacing: 2) {
                    if !store.activeGoals.isEmpty {
                        sectionHeader("In Progress")
                        ForEach(store.activeGoals) { goal in
                            SidebarGoalRow(goal: goal)
                        }
                    }
                    if !store.completedGoals.isEmpty {
                        sectionHeader("Completed")
                        ForEach(store.completedGoals) { goal in
                            SidebarGoalRow(goal: goal)
                        }
                    }
                    if store.goals.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 28))
                                .foregroundColor(Color(hex: "4ECDC4").opacity(0.5))
                            Text("No goals yet")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "5A5A72"))
                            Button("Add First Goal") { showAddGoal = true }
                                .buttonStyle(.plain)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "4ECDC4"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
        }
        .background(Color(hex: "111118"))
    }

    func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(hex: "5A5A72"))
                .kerning(0.8)
            Spacer()
        }
        .padding(.horizontal, 6)
        .padding(.top, 10)
        .padding(.bottom, 2)
    }
}

// MARK: - Sidebar Row
struct SidebarGoalRow: View {
    @EnvironmentObject var store: GoalStore
    var goal: Goal

    var isSelected: Bool { store.selectedGoalID == goal.id }

    var body: some View {
        Button {
            store.selectedGoalID = goal.id
        } label: {
            HStack(spacing: 10) {
                MiniRingView(progress: goal.progress, color: goal.type.accentColor, size: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: goal.type.icon)
                            .font(.system(size: 9))
                            .foregroundColor(goal.type.accentColor.opacity(0.7))
                        if let days = goal.daysUntilDue {
                            Text(days < 0 ? "Overdue" : "\(days)d left")
                                .font(.system(size: 10))
                                .foregroundColor(days < 0 ? .red : Color(hex: "8E8EA0"))
                        } else {
                            Text(goal.type.rawValue)
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "5A5A72"))
                        }
                    }
                }

                Spacer()

                Circle()
                    .fill(goal.priority.color)
                    .frame(width: 6, height: 6)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? goal.type.accentColor.opacity(0.3) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete", role: .destructive) {
                store.delete(id: goal.id)
            }
        }
    }
}
