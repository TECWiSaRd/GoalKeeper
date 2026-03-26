// ProgressRingView.swift
// Activity-ring progress indicators — macOS

import SwiftUI

// MARK: - Single Ring
struct ProgressRing: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat = 12
    var size: CGFloat = 70

    private var clamped: Double { max(0, min(1, progress)) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    AngularGradient(
                        colors: [color, color.opacity(0.55)],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: clamped)

            if clamped > 0.01 {
                Circle()
                    .fill(color)
                    .frame(width: lineWidth * 0.8, height: lineWidth * 0.8)
                    .shadow(color: color.opacity(0.9), radius: 3)
                    .offset(y: -size / 2)
                    .rotationEffect(.degrees(-90 + clamped * 360))
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: clamped)
            }
        }
    }
}

// MARK: - Triple Stacked Rings (Fitness-style)
struct ActivityRingsView: View {
    var goal: Goal
    var size: CGFloat = 90

    private let lw: CGFloat = 9
    private let gap: CGFloat = 5

    var body: some View {
        ZStack {
            ProgressRing(progress: goal.progress, color: goal.type.accentColor, lineWidth: lw, size: size)

            let done   = Double(goal.steps.filter { $0.isCompleted }.count)
            let total  = Double(max(1, goal.steps.count))
            ProgressRing(progress: done / total, color: goal.type.accentColor.opacity(0.7), lineWidth: lw, size: size - (lw + gap) * 2)

            let urgency: Double = {
                guard let due = goal.dueDate else { return 0 }
                let total = due.timeIntervalSince(goal.createdDate)
                let elapsed = Date().timeIntervalSince(goal.createdDate)
                return max(0, min(1, elapsed / max(1, total)))
            }()
            ProgressRing(progress: urgency,
                         color: goal.isOverdue ? .red : goal.type.accentColor.opacity(0.45),
                         lineWidth: lw,
                         size: size - (lw + gap) * 4)

            VStack(spacing: 0) {
                Text("\(goal.progressPercent)%")
                    .font(.system(size: size * 0.165, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("done")
                    .font(.system(size: size * 0.095, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Mini ring for sidebar rows
struct MiniRingView: View {
    var progress: Double
    var color: Color
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(), value: progress)
            Text("\(Int(progress * 100))")
                .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .frame(width: size, height: size)
    }
}
