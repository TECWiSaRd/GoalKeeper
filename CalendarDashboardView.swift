// CalendarDashboardView.swift
// Middle column: Calendar grid + summary rings — macOS

import SwiftUI

struct CalendarDashboardView: View {
    @EnvironmentObject var store: GoalStore
    @State private var currentMonth: Date = Date()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                monthHeader
                summaryRingsRow
                calendarGrid
                todayGoalsSection
                Spacer()
            }
            .padding(16)
        }
        .background(Color(hex: "0D0D12"))
        .navigationTitle("")
    }

    // MARK: - Month header
    var monthHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(monthYearString)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(todayString)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "8E8EA0"))
            }
            Spacer()
            HStack(spacing: 4) {
                Button { changeMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "8E8EA0"))
                        .padding(6)
                        .background(Color.white.opacity(0.07))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                Button { changeMonth(1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "8E8EA0"))
                        .padding(6)
                        .background(Color.white.opacity(0.07))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Summary rings
    var summaryRingsRow: some View {
        HStack(spacing: 12) {
            // Overall
            overallCard

            // Per-goal mini cards
            ForEach(store.activeGoals.prefix(3)) { goal in
                Button {
                    store.selectedGoalID = goal.id
                } label: {
                    miniGoalCard(goal)
                }
                .buttonStyle(.plain)
            }
        }
    }

    var overallCard: some View {
        let avg = store.activeGoals.isEmpty ? 0.0
            : store.activeGoals.map(\.progress).reduce(0, +) / Double(store.activeGoals.count)
        return VStack(spacing: 6) {
            ZStack {
                ProgressRing(progress: avg, color: Color(hex: "4ECDC4"), lineWidth: 8, size: 52)
                Text("\(Int(avg * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            Text("Overall")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(hex: "8E8EA0"))
        }
        .padding(10)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
    }

    func miniGoalCard(_ goal: Goal) -> some View {
        VStack(spacing: 6) {
            ZStack {
                ProgressRing(progress: goal.progress, color: goal.type.accentColor, lineWidth: 8, size: 52)
                Image(systemName: goal.type.icon)
                    .font(.system(size: 13))
                    .foregroundColor(goal.type.accentColor)
            }
            Text(goal.title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(maxWidth: 72)
        }
        .padding(10)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(
            store.selectedGoalID == goal.id ? goal.type.accentColor.opacity(0.4) : Color.clear
        ))
    }

    // MARK: - Calendar grid
    var calendarGrid: some View {
        VStack(spacing: 8) {
            // Day labels
            HStack(spacing: 0) {
                ForEach(["Su","Mo","Tu","We","Th","Fr","Sa"], id: \.self) { d in
                    Text(d)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(hex: "5A5A72"))
                        .frame(maxWidth: .infinity)
                }
            }

            // Day cells
            let days = calendarDays
            let goalMap     = store.goalsWithDueDates(in: currentMonth)
            let scheduleMap = store.scheduleItemsWithDates(in: currentMonth)
            let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(days.indices, id: \.self) { i in
                    if let date = days[i] {
                        let isToday    = Calendar.current.isDateInToday(date)
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: store.selectedDate)
                        let startOfDay = Calendar.current.startOfDay(for: date)
                        let dayGoals   = goalMap[startOfDay] ?? []
                        let dayItems   = scheduleMap[startOfDay] ?? []

                        Button {
                            store.selectedDate = date
                        } label: {
                            VStack(spacing: 2) {
                                ZStack {
                                    if isToday {
                                        Circle().fill(Color(hex: "4ECDC4")).frame(width: 24, height: 24)
                                    } else if isSelected {
                                        Circle().fill(Color.white.opacity(0.12)).frame(width: 24, height: 24)
                                    }
                                    Text("\(Calendar.current.component(.day, from: date))")
                                        .font(.system(size: 12, weight: isToday ? .bold : .regular))
                                        .foregroundColor(isToday ? .black : .white)
                                }
                                HStack(spacing: 1) {
                                    ForEach(dayGoals.prefix(2)) { g in
                                        Circle().fill(g.type.accentColor).frame(width: 3.5, height: 3.5)
                                    }
                                    ForEach(dayItems.prefix(2)) { s in
                                        Circle().fill(s.type.color).frame(width: 3.5, height: 3.5)
                                    }
                                }
                                .frame(height: 5)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .cornerRadius(14)
    }

    // MARK: - Today's goals list
    var todayGoalsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Due This Month")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color(hex: "8E8EA0"))

            let allGoalsWithDates = store.goals.filter { $0.dueDate != nil || true }
            let sorted = store.goals.sorted {
                ($0.dueDate ?? $0.createdDate) < ($1.dueDate ?? $1.createdDate)
            }

            if sorted.isEmpty {
                Text("No goals yet — press ⌘N to add one")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "3A3A50"))
                    .padding(.vertical, 12)
            } else {
                ForEach(sorted) { goal in
                    Button {
                        store.selectedGoalID = goal.id
                    } label: {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(goal.type.accentColor)
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(goal.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                if let days = goal.daysUntilDue {
                                    Text(days < 0 ? "Overdue \(-days)d" : "Due in \(days)d")
                                        .font(.system(size: 10))
                                        .foregroundColor(days < 0 ? .red : Color(hex: "8E8EA0"))
                                }
                            }
                            Spacer()
                            MiniRingView(progress: goal.progress, color: goal.type.accentColor, size: 24)
                        }
                        .padding(8)
                        .background(store.selectedGoalID == goal.id
                                    ? Color.white.opacity(0.08)
                                    : Color.clear)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Helpers
    var monthYearString: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: currentMonth)
    }
    var todayString: String {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }
    func changeMonth(_ d: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentMonth = Calendar.current.date(byAdding: .month, value: d, to: currentMonth) ?? currentMonth
        }
    }
    var calendarDays: [Date?] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: currentMonth),
              let firstDay = cal.date(from: cal.dateComponents([.year, .month], from: currentMonth))
        else { return [] }
        let weekday = cal.component(.weekday, from: firstDay) - 1
        var days: [Date?] = Array(repeating: nil, count: weekday)
        for d in range {
            days.append(cal.date(byAdding: .day, value: d - 1, to: firstDay))
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }
}
