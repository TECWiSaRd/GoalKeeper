// Models.swift
// Core data models — macOS version (uses NSImage/AppKit)

import Foundation
import SwiftUI
import AppKit

// MARK: - Goal Step
struct GoalStep: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var detail: String
    var estimatedTime: String
    var isCompleted: Bool = false
    var tips: [String] = []
}

// MARK: - Goal Type
enum GoalType: String, Codable, CaseIterable {
    case assignment   = "Assignment"
    case project      = "Project"
    case personalGoal = "Personal Goal"
    case habit        = "Habit"
    case exam         = "Exam Prep"
    case creative     = "Creative"

    var icon: String {
        switch self {
        case .assignment:   return "doc.text.fill"
        case .project:      return "folder.fill"
        case .personalGoal: return "star.fill"
        case .habit:        return "repeat.circle.fill"
        case .exam:         return "graduationcap.fill"
        case .creative:     return "paintbrush.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .assignment:   return Color(hex: "FF6B6B")
        case .project:      return Color(hex: "4ECDC4")
        case .personalGoal: return Color(hex: "FFE66D")
        case .habit:        return Color(hex: "A8E6CF")
        case .exam:         return Color(hex: "C3B1E1")
        case .creative:     return Color(hex: "FFB347")
        }
    }
}

// MARK: - Goal Priority
enum GoalPriority: String, Codable, CaseIterable {
    case low    = "Low"
    case medium = "Medium"
    case high   = "High"

    var color: Color {
        switch self {
        case .low:    return .green
        case .medium: return .orange
        case .high:   return .red
        }
    }
}

// MARK: - Goal
struct Goal: Identifiable, Codable {
    var id = UUID()
    var title: String
    var description: String
    var type: GoalType
    var priority: GoalPriority = .medium
    var steps: [GoalStep] = []
    var createdDate: Date = Date()
    var dueDate: Date?
    var rubricText: String = ""
    var attachedImageData: Data?
    var isAnalyzed: Bool = false
    var aiSummary: String = ""
    var currentStepIndex: Int = 0

    var progress: Double {
        guard !steps.isEmpty else { return 0 }
        return Double(steps.filter { $0.isCompleted }.count) / Double(steps.count)
    }
    var progressPercent: Int { Int(progress * 100) }
    var currentStep: GoalStep? {
        guard currentStepIndex < steps.count else { return nil }
        return steps[currentStepIndex]
    }
    var isComplete: Bool { progress >= 1.0 }
    var daysUntilDue: Int? {
        guard let due = dueDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: due).day
    }
    var isOverdue: Bool {
        guard let days = daysUntilDue else { return false }
        return days < 0 && !isComplete
    }
}

// MARK: - Color hex init
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8)*17, (int >> 4 & 0xF)*17, (int & 0xF)*17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}
