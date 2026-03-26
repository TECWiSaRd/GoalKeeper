// GoalStore.swift
// State management and UserDefaults persistence — macOS

import Foundation
import SwiftUI
import Combine

class GoalStore: ObservableObject {
    @Published var goals: [Goal] = []
    @Published var selectedGoalID: UUID?
    @Published var selectedDate: Date = Date()

    private let saveKey = "GoalPlannerMac_Goals_v1"

    init() {
        load()
        if goals.isEmpty { insertSampleData() }
    }

    // MARK: - CRUD
    func add(_ goal: Goal) {
        goals.append(goal)
        selectedGoalID = goal.id
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
        if selectedGoalID == id { selectedGoalID = goals.first?.id }
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

    // MARK: - Persistence
    private func save() {
        if let data = try? JSONEncoder().encode(goals) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }
    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Goal].self, from: data) {
            goals = decoded
        }
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
        save()
    }
}
