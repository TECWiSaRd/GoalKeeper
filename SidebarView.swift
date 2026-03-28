// SidebarView.swift
// Left sidebar: goals + schedule grouped by subject

import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: GoalStore
    @Binding var showAddGoal: Bool
    @Binding var showImport: Bool

    // Track which subject groups are expanded
    @State private var expandedSubjects: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.08))

            if !store.overdueGoals.isEmpty {
                overdueWarning
            }

            ScrollView {
                LazyVStack(spacing: 2) {
                    goalsSection
                    scheduleSection
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
        }
        .background(Color(hex: "111118"))
        .onAppear {
            // Expand all subjects by default
            expandedSubjects = Set(store.subjects)
        }
        .onChange(of: store.subjects) { _, new in
            // Auto-expand newly added subjects
            for s in new where !expandedSubjects.contains(s) {
                expandedSubjects.insert(s)
            }
        }
    }

    // MARK: - Header
    var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("GoalKeeper")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("\(store.activeGoals.count) goals · \(store.scheduleItems.filter { !$0.isCompleted }.count) assignments")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "5A5A72"))
            }
            Spacer()
            HStack(spacing: 8) {
                Button { showImport = true } label: {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: "FFE66D"))
                }
                .buttonStyle(.plain)
                .help("Import Schedule")

                Button { showAddGoal = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(hex: "4ECDC4"))
                }
                .buttonStyle(.plain)
                .help("New Goal (⌘N)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Overdue warning
    var overdueWarning: some View {
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

    // MARK: - Goals section
    var goalsSection: some View {
        Group {
            if !store.goals.isEmpty {
                sectionHeader("Goals")

                if !store.activeGoals.isEmpty {
                    ForEach(store.activeGoals) { goal in
                        SidebarGoalRow(goal: goal)
                    }
                }
                if !store.completedGoals.isEmpty {
                    subSectionHeader("Completed")
                    ForEach(store.completedGoals) { goal in
                        SidebarGoalRow(goal: goal)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "4ECDC4").opacity(0.5))
                    Text("No goals yet")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "5A5A72"))
                    Button("Add First Goal") { showAddGoal = true }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "4ECDC4"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
    }

    // MARK: - Schedule section grouped by subject
    var scheduleSection: some View {
        Group {
            if !store.scheduleItems.isEmpty {
                sectionHeader("Schedule")

                ForEach(store.subjects, id: \.self) { subject in
                    subjectGroup(subject)
                }
            }
        }
    }

    func subjectGroup(_ subject: String) -> some View {
        let items = store.items(for: subject)
        let isExpanded = expandedSubjects.contains(subject)
        let overdue = items.filter { $0.isOverdue }.count
        let upcoming = items.filter { !$0.isCompleted }.count

        return VStack(spacing: 0) {
            // Subject header row — tap to expand/collapse
            Button {
                withAnimation(.spring(response: 0.3)) {
                    if isExpanded { expandedSubjects.remove(subject) }
                    else          { expandedSubjects.insert(subject) }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(hex: "5A5A72"))
                        .frame(width: 10)

                    Text(subject)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    if overdue > 0 {
                        Text("\(overdue) overdue")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.red)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.12))
                            .cornerRadius(4)
                    } else {
                        Text("\(upcoming)")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "5A5A72"))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            // Items in the group
            if isExpanded {
                ForEach(items) { item in
                    SidebarScheduleRow(item: item)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .background(Color.white.opacity(0.02))
        .cornerRadius(8)
        .padding(.vertical, 1)
    }

    // MARK: - Section header helpers
    func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(hex: "5A5A72"))
                .kerning(0.8)
            Spacer()
        }
        .padding(.horizontal, 6)
        .padding(.top, 12)
        .padding(.bottom, 2)
    }

    func subSectionHeader(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Color(hex: "3A3A50"))
                .kerning(0.8)
            Spacer()
        }
        .padding(.horizontal, 6)
        .padding(.top, 6)
        .padding(.bottom, 1)
    }
}

// MARK: - Sidebar Goal Row
struct SidebarGoalRow: View {
    @EnvironmentObject var store: GoalStore
    var goal: Goal

    var isSelected: Bool {
        store.selectedGoalID == goal.id && store.detailSelection == .goal
    }

    var body: some View {
        Button {
            store.selectedGoalID = goal.id
            store.detailSelection = .goal
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
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? goal.type.accentColor.opacity(0.3) : Color.clear))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete", role: .destructive) { store.delete(id: goal.id) }
        }
    }
}

// MARK: - Sidebar Schedule Row
struct SidebarScheduleRow: View {
    @EnvironmentObject var store: GoalStore
    var item: ScheduleItem

    var isSelected: Bool {
        store.selectedScheduleItemID == item.id && store.detailSelection == .scheduleItem
    }

    var body: some View {
        Button {
            store.selectedScheduleItemID = item.id
            store.detailSelection = .scheduleItem
        } label: {
            HStack(spacing: 8) {
                // Completion toggle
                Button {
                    store.toggleScheduleItem(id: item.id)
                } label: {
                    ZStack {
                        Circle()
                            .stroke(item.isCompleted ? item.type.color : Color.white.opacity(0.2), lineWidth: 1.5)
                            .frame(width: 16, height: 16)
                        if item.isCompleted {
                            Circle().fill(item.type.color).frame(width: 16, height: 16)
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.black)
                        }
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(item.isCompleted ? Color(hex: "5A5A72") : .white)
                        .lineLimit(1)
                        .strikethrough(item.isCompleted)

                    HStack(spacing: 4) {
                        Image(systemName: item.type.icon)
                            .font(.system(size: 8))
                            .foregroundColor(item.type.color.opacity(0.7))
                        Text(dueDateLabel)
                            .font(.system(size: 10))
                            .foregroundColor(item.isOverdue ? .red : Color(hex: "8E8EA0"))
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.white.opacity(0.08) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Mark Complete") { store.toggleScheduleItem(id: item.id) }
            Divider()
            Button("Delete", role: .destructive) { store.deleteScheduleItem(id: item.id) }
        }
    }

    var dueDateLabel: String {
        let days = item.daysUntilDue
        if item.isCompleted { return "Done" }
        if days < 0  { return "Overdue \(-days)d" }
        if days == 0 { return "Due today" }
        if days == 1 { return "Due tomorrow" }
        return "Due in \(days)d"
    }
}
