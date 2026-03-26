// GoalDetailView.swift
// Right-column detail view for macOS — step tracking, rings, re-analyze

import SwiftUI
import AppKit

struct GoalDetailView: View {
    @EnvironmentObject var store: GoalStore
    var goal: Goal

    @State private var localGoal: Goal
    @State private var expandedStep: UUID?
    @State private var isReanalyzing = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showDeleteAlert = false

    init(goal: Goal) {
        self.goal = goal
        self._localGoal = State(initialValue: goal)
    }

    @ViewBuilder
    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                heroHeader
                if !localGoal.aiSummary.isEmpty {
                    summaryCard
                }
                stepsSection
                metaCard
                Spacer()
            }
            .padding(20)
        }
    }

    var body: some View {
        let base = content

        let withBackground = base
            .background(Color(hex: "0D0D12"))

        let withNavigation = withBackground
            .navigationTitle("")

        let withToolbar = withNavigation
            .toolbar { toolbarContent }

        let withDeleteAlert = withToolbar
            .alert(
                "Delete Goal",
                isPresented: $showDeleteAlert,
                actions: deleteAlertActions,
                message: deleteAlertMessage
            )

        let withErrorAlert = withDeleteAlert
            .alert(
                "Error",
                isPresented: $showError,
                actions: errorAlertActions,
                message: errorAlertMessage
            )

        return withErrorAlert
            .onChange(of: store.goals.flatMap { $0.steps.map(\.isCompleted) }) { _, _ in
                if let updated = store.goals.first(where: { $0.id == localGoal.id }) {
                    localGoal = updated
                }
            }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Button {
                Task { await reanalyze() }
            } label: {
                Label("Re-analyze", systemImage: isReanalyzing ? "ellipsis" : "sparkles")
            }
            .disabled(isReanalyzing)
            .help("Re-analyze with Claude AI")

            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .help("Delete goal")
        }
    }

    @ViewBuilder
    private func deleteAlertActions() -> some View {
        Button("Delete", role: .destructive) { store.delete(id: localGoal.id) }
        Button("Cancel", role: .cancel) {}
    }

    @ViewBuilder
    private func deleteAlertMessage() -> some View {
        Text("Permanently delete \"\(localGoal.title)\" and all its steps?")
    }

    @ViewBuilder
    private func errorAlertActions() -> some View {
        Button("OK") {}
    }

    @ViewBuilder
    private func errorAlertMessage() -> some View {
        Text(errorMessage)
    }

    // MARK: - Hero
    @ViewBuilder var heroHeader: some View {
        HStack(alignment: .center, spacing: 24) {
            ActivityRingsView(goal: localGoal, size: 110)

            heroTextBlock()
            
            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
    }

    @ViewBuilder
    private func heroTextBlock() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: localGoal.type.icon)
                    .foregroundColor(localGoal.type.accentColor)
                Text(localGoal.type.rawValue.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(localGoal.type.accentColor)
                    .kerning(0.8)
            }

            Text(localGoal.title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            if !localGoal.description.isEmpty {
                Text(localGoal.description)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "8E8EA0"))
                    .lineSpacing(3)
            }

            statsChips()
        }
    }

    func chip(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .cornerRadius(6)
    }

    @ViewBuilder
    private func statsChips() -> some View {
        HStack(spacing: 8) {
            chip("\(localGoal.progressPercent)% done", color: localGoal.type.accentColor)
            chip("\(localGoal.steps.filter { $0.isCompleted }.count)/\(localGoal.steps.count) steps", color: .white.opacity(0.6))
            if let days = localGoal.daysUntilDue {
                chip(days < 0 ? "⚠ Overdue \(-days)d" : "\(days)d left",
                     color: days < 0 ? .red : .orange)
            }
        }
    }

    // MARK: - AI Summary
    @ViewBuilder var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Claude's Analysis", systemImage: "sparkles")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "4ECDC4"))
            Text(localGoal.aiSummary)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "8E8EA0"))
                .lineSpacing(4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "4ECDC4").opacity(0.06))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "4ECDC4").opacity(0.18)))
    }

    // MARK: - Steps
    @ViewBuilder var stepsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            let completedCount = localGoal.steps.filter { $0.isCompleted }.count
            let totalCount = localGoal.steps.count

            HStack {
                Text("Action Plan")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("\(completedCount) of \(totalCount) completed")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "8E8EA0"))
            }

            if localGoal.steps.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 26))
                            .foregroundColor(Color(hex: "3A3A50"))
                        Text("Click ✦ in the toolbar to analyze with Claude")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "3A3A50"))
                    }
                    .padding(.vertical, 30)
                    Spacer()
                }
            } else {
                ForEach(localGoal.steps.indices, id: \.self) { i in
                    let step = localGoal.steps[i]
                    stepRow(step: step, index: i)
                }
            }
        }
    }

    @ViewBuilder
    func stepRow(step: GoalStep, index: Int) -> some View {
        let isCurrent = !step.isCompleted && localGoal.steps.prefix(index).allSatisfy { $0.isCompleted }

        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    expandedStep = expandedStep == step.id ? nil : step.id
                }
            } label: {
                stepRowLabel(step: step, index: index, isCurrent: isCurrent)
            }
            .buttonStyle(.plain)

            if expandedStep == step.id {
                stepExpandedContent(step: step)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isCurrent ? localGoal.type.accentColor.opacity(0.06) : Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(isCurrent ? localGoal.type.accentColor.opacity(0.25) : Color.white.opacity(0.06)))
        )
    }

    @ViewBuilder
    private func stepRowLabel(step: GoalStep, index: Int, isCurrent: Bool) -> some View {
        HStack(spacing: 10) {
            Button {
                store.toggleStep(goalID: localGoal.id, stepID: step.id)
            } label: {
                ZStack {
                    Circle()
                        .stroke(step.isCompleted ? localGoal.type.accentColor : Color.white.opacity(0.2), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if step.isCompleted {
                        Circle().fill(localGoal.type.accentColor).frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                    } else {
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isCurrent ? localGoal.type.accentColor : Color(hex: "5A5A72"))
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(step.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(step.isCompleted ? Color(hex: "5A5A72") : .white)
                    .strikethrough(step.isCompleted)
                Text(step.estimatedTime)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "5A5A72"))
            }

            Spacer()

            if isCurrent {
                Text("NOW")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(localGoal.type.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(localGoal.type.accentColor.opacity(0.15))
                    .cornerRadius(4)
            }

            Image(systemName: expandedStep == step.id ? "chevron.up" : "chevron.down")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "5A5A72"))
        }
    }

    @ViewBuilder
    private func stepExpandedContent(step: GoalStep) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().background(Color.white.opacity(0.07))
            Text(step.detail)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "8E8EA0"))
                .lineSpacing(4)
                .padding(.horizontal, 12)

            if !step.tips.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("TIPS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(hex: "5A5A72"))
                        .kerning(0.8)
                    ForEach(step.tips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 9))
                                .foregroundColor(Color(hex: "FFE66D"))
                            Text(tip)
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "8E8EA0"))
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            Spacer().frame(height: 4)
        }
    }

    // MARK: - Meta
    @ViewBuilder var metaCard: some View {
        VStack(spacing: 0) {
            metaRow(icon: "tag.fill", label: "Type", value: localGoal.type.rawValue, color: localGoal.type.accentColor)
            Divider().background(Color.white.opacity(0.07)).padding(.horizontal, 12)
            metaRow(icon: "exclamationmark.triangle.fill", label: "Priority", value: localGoal.priority.rawValue, color: localGoal.priority.color)
            Divider().background(Color.white.opacity(0.07)).padding(.horizontal, 12)
            metaRow(icon: "calendar.badge.plus", label: "Created", value: fmt(localGoal.createdDate), color: .white)
            if let due = localGoal.dueDate {
                Divider().background(Color.white.opacity(0.07)).padding(.horizontal, 12)
                metaRow(icon: "calendar.badge.clock", label: "Due", value: fmt(due), color: localGoal.isOverdue ? .red : .orange)
            }
            if let imgData = localGoal.attachedImageData,
               let nsImg = NSImage(data: imgData) {
                Divider().background(Color.white.opacity(0.07)).padding(.horizontal, 12)
                HStack {
                    Label("Attachment", systemImage: "photo.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "8E8EA0"))
                    Spacer()
                    Image(nsImage: nsImg)
                        .resizable().scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
    }

    func metaRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "8E8EA0"))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    func fmt(_ date: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium
        return f.string(from: date)
    }

    // MARK: - Reanalyze
    func reanalyze() async {
        isReanalyzing = true
        do {
            let img = localGoal.attachedImageData.flatMap { NSImage(data: $0) }
            let result = try await AnthropicService.analyzeGoal(
                title: localGoal.title,
                description: localGoal.description,
                type: localGoal.type,
                dueDate: localGoal.dueDate,
                rubric: localGoal.rubricText,
                image: img
            )
            localGoal.aiSummary = result.summary
            localGoal.steps = result.steps.map {
                GoalStep(title: $0.title, detail: $0.detail, estimatedTime: $0.estimatedTime, tips: $0.tips)
            }
            localGoal.currentStepIndex = 0
            localGoal.isAnalyzed = true
            store.update(localGoal)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isReanalyzing = false
    }
}

// MARK: - Empty detail placeholder
struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundColor(Color(hex: "4ECDC4").opacity(0.3))
            Text("Select a goal")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hex: "5A5A72"))
            Text("Choose a goal from the sidebar, or press ⌘N to create one.")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "3A3A50"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "0D0D12"))
    }
}
