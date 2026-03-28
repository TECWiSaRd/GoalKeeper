// GoalStore.swift
// State management and persistence — macOS

import Foundation
import SwiftUI
import Combine

class GoalStore: ObservableObject {
    @Published var goals: [Goal] = []
    @Published var scheduleItems: [ScheduleItem] = []
    @Published var studyGuides: [UUID: StudyGuide] = [:]  // keyed by ScheduleItem.id
    @Published var selectedGoalID: UUID?
    @Published var selectedScheduleItemID: UUID?
    @Published var selectedDate: Date = Date()

    // Track which detail panel is showing
    enum DetailSelection { case goal, scheduleItem, none }
    @Published var detailSelection: DetailSelection = .none

    private let goalsKey    = "GoalPlannerMac_Goals_v1"
    private let scheduleKey    = "GoalPlannerMac_Schedule_v1"
    private let studyGuideKey  = "GoalPlannerMac_StudyGuides_v1"

    init() {
        load()
        if goals.isEmpty { insertSampleData() }
    }

    // MARK: - Goal CRUD
    func add(_ goal: Goal) {
        goals.append(goal)
        selectedGoalID = goal.id
        detailSelection = .goal
        save()
    }

    func update(_ goal: Goal) {
        if let idx = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[idx] = goal
            save()
        }
    }

    func delete(id: UUID) {
        goals.removeAll { $0.id == id }
        if selectedGoalID == id {
            selectedGoalID = goals.first?.id
            detailSelection = goals.isEmpty ? .none : .goal
        }
        save()
    }

    func toggleStep(goalID: UUID, stepID: UUID) {
        guard let gIdx = goals.firstIndex(where: { $0.id == goalID }) else { return }
        if let sIdx = goals[gIdx].steps.firstIndex(where: { $0.id == stepID }) {
            goals[gIdx].steps[sIdx].isCompleted.toggle()
            let next = goals[gIdx].steps.firstIndex(where: { !$0.isCompleted })
            goals[gIdx].currentStepIndex = next ?? goals[gIdx].steps.count
        }
        save()
    }

    var selectedGoal: Goal? { goals.first(where: { $0.id == selectedGoalID }) }
    var activeGoals: [Goal] { goals.filter { !$0.isComplete } }
    var completedGoals: [Goal] { goals.filter { $0.isComplete } }
    var overdueGoals: [Goal] { goals.filter { $0.isOverdue } }

    // MARK: - Schedule CRUD
    func addScheduleItem(_ item: ScheduleItem) {
        scheduleItems.append(item)
        selectedScheduleItemID = item.id
        detailSelection = .scheduleItem
        save()
    }

    func addScheduleItems(_ items: [ScheduleItem]) {
        scheduleItems.append(contentsOf: items)
        if let first = items.first {
            selectedScheduleItemID = first.id
            detailSelection = .scheduleItem
        }
        save()
    }

    func updateScheduleItem(_ item: ScheduleItem) {
        if let idx = scheduleItems.firstIndex(where: { $0.id == item.id }) {
            scheduleItems[idx] = item
            save()
        }
    }

    func deleteScheduleItem(id: UUID) {
        scheduleItems.removeAll { $0.id == id }
        if selectedScheduleItemID == id {
            selectedScheduleItemID = scheduleItems.first?.id
            detailSelection = scheduleItems.isEmpty ? .none : .scheduleItem
        }
        save()
    }

    func toggleScheduleItem(id: UUID) {
        if let idx = scheduleItems.firstIndex(where: { $0.id == id }) {
            scheduleItems[idx].isCompleted.toggle()
            save()
        }
    }

    var selectedScheduleItem: ScheduleItem? {
        scheduleItems.first(where: { $0.id == selectedScheduleItemID })
    }

    // Group schedule items by subject
    var scheduleBySubject: [String: [ScheduleItem]] {
        Dictionary(grouping: scheduleItems.filter { !$0.isCompleted }) { $0.subject }
    }

    // All subjects sorted alphabetically
    var subjects: [String] {
        Array(Set(scheduleItems.map { $0.subject })).sorted()
    }

    // Items for a subject sorted by due date
    func items(for subject: String) -> [ScheduleItem] {
        scheduleItems
            .filter { $0.subject == subject }
            .sorted { $0.dueDate < $1.dueDate }
    }

    // Upcoming items for same subject (not yet due, not completed)
    func upcomingItems(for subject: String, excluding id: UUID) -> [ScheduleItem] {
        scheduleItems
            .filter { $0.subject == subject && $0.id != id && !$0.isCompleted }
            .sorted { $0.dueDate < $1.dueDate }
    }

    // MARK: - Calendar helpers
    func goalsWithDueDates(in month: Date) -> [Date: [Goal]] {
        var result: [Date: [Goal]] = [:]
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: month)
        for goal in goals {
            let ref = goal.dueDate ?? goal.createdDate
            let rc = cal.dateComponents([.year, .month], from: ref)
            if rc.year == comps.year && rc.month == comps.month {
                result[cal.startOfDay(for: ref), default: []].append(goal)
            }
        }
        return result
    }

    func scheduleItemsWithDates(in month: Date) -> [Date: [ScheduleItem]] {
        var result: [Date: [ScheduleItem]] = [:]
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: month)
        for item in scheduleItems {
            let rc = cal.dateComponents([.year, .month], from: item.dueDate)
            if rc.year == comps.year && rc.month == comps.month {
                result[cal.startOfDay(for: item.dueDate), default: []].append(item)
            }
        }
        return result
    }

    // MARK: - Persistence
    private func save() {
        if let data = try? JSONEncoder().encode(goals) {
            UserDefaults.standard.set(data, forKey: goalsKey)
        }
        if let data = try? JSONEncoder().encode(scheduleItems) {
            UserDefaults.standard.set(data, forKey: scheduleKey)
        }
        if let data = try? JSONEncoder().encode(studyGuides) {
            UserDefaults.standard.set(data, forKey: studyGuideKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: goalsKey),
           let decoded = try? JSONDecoder().decode([Goal].self, from: data) {
            goals = decoded
        }
        if let data = UserDefaults.standard.data(forKey: scheduleKey),
           let decoded = try? JSONDecoder().decode([ScheduleItem].self, from: data) {
            scheduleItems = decoded
        }
        if let data = UserDefaults.standard.data(forKey: studyGuideKey),
           let decoded = try? JSONDecoder().decode([UUID: StudyGuide].self, from: data) {
            studyGuides = decoded
        }
    }

    // MARK: - Study Guide
    func saveStudyGuide(_ guide: StudyGuide, for itemID: UUID) {
        studyGuides[itemID] = guide
        save()
    }

    func studyGuide(for itemID: UUID) -> StudyGuide? {
        studyGuides[itemID]
    }

    // MARK: - Sample Data
    private func insertSampleData() {
        var g1 = Goal(title: "Research Paper on Climate Change",
                      description: "Write a 10-page research paper covering recent climate data and solutions",
                      type: .assignment, priority: .high)
        g1.dueDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())
        g1.isAnalyzed = true
        g1.aiSummary = "A structured paper requiring literature review, data analysis, and clear argumentation."
        g1.steps = [
            GoalStep(title: "Define research scope", detail: "Narrow your topic to 2–3 specific climate issues", estimatedTime: "30 min", isCompleted: true, tips: ["Focus on peer-reviewed sources"]),
            GoalStep(title: "Gather sources", detail: "Find 8–10 credible academic sources", estimatedTime: "2 hrs", isCompleted: true),
            GoalStep(title: "Create outline", detail: "Draft a detailed outline for all sections", estimatedTime: "45 min", isCompleted: false),
            GoalStep(title: "Write first draft", detail: "Write the full paper without stopping to edit", estimatedTime: "4 hrs", isCompleted: false),
            GoalStep(title: "Revise & cite", detail: "Add citations, fix grammar, and polish the argument", estimatedTime: "2 hrs", isCompleted: false),
        ]
        g1.currentStepIndex = 2

        var g2 = Goal(title: "Learn SwiftUI in 30 Days",
                      description: "Master SwiftUI by building 5 real apps",
                      type: .project, priority: .medium)
        g2.dueDate = Calendar.current.date(byAdding: .day, value: 22, to: Date())
        g2.isAnalyzed = true
        g2.aiSummary = "A self-paced learning project broken into progressive weekly milestones."
        g2.steps = [
            GoalStep(title: "SwiftUI basics", detail: "Views, modifiers, state management", estimatedTime: "3 days", isCompleted: true),
            GoalStep(title: "Navigation & data flow", detail: "NavigationStack, Environment, bindings", estimatedTime: "4 days", isCompleted: false),
            GoalStep(title: "Animations & gestures", detail: "withAnimation, matchedGeometryEffect", estimatedTime: "3 days", isCompleted: false),
            GoalStep(title: "Networking & persistence", detail: "async/await, SwiftData", estimatedTime: "4 days", isCompleted: false),
            GoalStep(title: "Final capstone app", detail: "Build and submit a polished app", estimatedTime: "1 week", isCompleted: false),
        ]
        g2.currentStepIndex = 1

        goals = [g1, g2]
        selectedGoalID = g1.id
        detailSelection = .goal

        // Sample schedule items
        let cal = Calendar.current
        scheduleItems = [
            ScheduleItem(title: "Chapter 5 Problems", subject: "Math", type: .homework,
                         dueDate: cal.date(byAdding: .day, value: 1, to: Date())!),
            ScheduleItem(title: "Midterm Exam", subject: "Math", type: .test,
                         dueDate: cal.date(byAdding: .day, value: 8, to: Date())!),
            ScheduleItem(title: "Chapter 6 Problems", subject: "Math", type: .homework,
                         dueDate: cal.date(byAdding: .day, value: 10, to: Date())!),
            ScheduleItem(title: "Read Chapter 3", subject: "History", type: .reading,
                         dueDate: cal.date(byAdding: .day, value: 2, to: Date())!),
            ScheduleItem(title: "Essay Draft", subject: "History", type: .homework,
                         dueDate: cal.date(byAdding: .day, value: 6, to: Date())!),
            ScheduleItem(title: "Quiz on WWII", subject: "History", type: .quiz,
                         dueDate: cal.date(byAdding: .day, value: 4, to: Date())!),
            ScheduleItem(title: "Lab Report", subject: "Biology", type: .homework,
                         dueDate: cal.date(byAdding: .day, value: 3, to: Date())!),
        ]

        save()
    }
}
