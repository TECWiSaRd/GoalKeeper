// ScheduleDetailView.swift
// Detail view for a schedule item — shows details + upcoming from same subject

import SwiftUI

struct ScheduleDetailView: View {
    @EnvironmentObject var store: GoalStore
    var item: ScheduleItem

    @State private var localItem: ScheduleItem
    @State private var expandedItemID: UUID?
    @State private var isGeneratingGuide = false
    @State private var showGuideError    = false
    @State private var guideErrorMessage = ""
    @State private var guideErrorStr     = ""
    @State private var showStudyGuide    = false

    init(item: ScheduleItem) {
        self.item = item
        self._localItem = State(initialValue: item)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                heroCard
                upcomingSection
                studyGuideSection
                Spacer()
            }
            .padding(20)
        }
        .background(Color(hex: "0D0D12"))
        .navigationTitle("")
        .alert("Study Guide Error", isPresented: $showGuideError) {
            Button("OK") {}
        } message: { Text(guideErrorMessage) }
        .onChange(of: store.scheduleItems) { _, _ in
            if let updated = store.scheduleItems.first(where: { $0.id == localItem.id }) {
                localItem = updated
            }
        }
    }

    // MARK: - Hero card
    var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Subject + type badge
            HStack(spacing: 8) {
                Text(localItem.subject.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(localItem.type.color)
                    .kerning(0.8)

                Spacer()

                // Type badge
                Label(localItem.type.rawValue, systemImage: localItem.type.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(localItem.type.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(localItem.type.color.opacity(0.12))
                    .cornerRadius(6)
            }

            // Title
            Text(localItem.title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(localItem.isCompleted ? Color(hex: "5A5A72") : .white)
                .strikethrough(localItem.isCompleted)

            // Due date
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                    .foregroundColor(localItem.isOverdue ? .red : Color(hex: "8E8EA0"))
                Text(dueDateString)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(localItem.isOverdue ? .red : Color(hex: "8E8EA0"))
            }

            // Notes
            if !localItem.notes.isEmpty {
                Text(localItem.notes)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "8E8EA0"))
                    .lineSpacing(4)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
            }

            // Mark complete button
            Button {
                store.toggleScheduleItem(id: localItem.id)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: localItem.isCompleted ? "arrow.uturn.left.circle.fill" : "checkmark.circle.fill")
                    Text(localItem.isCompleted ? "Mark Incomplete" : "Mark Complete")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(localItem.isCompleted ? Color(hex: "8E8EA0") : .black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(localItem.isCompleted ? Color.white.opacity(0.06) : localItem.type.color)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(localItem.type.color.opacity(0.2)))
    }

    // MARK: - Study Guide section
    var studyGuideSection: some View {
        let shouldShow = localItem.type == .test || localItem.type == .quiz ||
                         localItem.title.lowercased().contains("review") ||
                         localItem.title.lowercased().contains("study") ||
                         localItem.title.lowercased().contains("exam")
        let existingGuide = store.studyGuide(for: localItem.id)

        return Group {
            if shouldShow || existingGuide != nil {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Study Guide", systemImage: "book.fill")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        if existingGuide != nil {
                            Text("Generated")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.12))
                                .cornerRadius(6)
                        }
                    }

                    if let guide = existingGuide {
                        // Show preview + open button
                        VStack(alignment: .leading, spacing: 10) {
                            Text(guide.overview)
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "8E8EA0"))
                                .lineSpacing(4)
                                .lineLimit(3)

                            HStack(spacing: 10) {
                                Button {
                                    showStudyGuide = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "book.open.fill")
                                        Text("Open Study Guide")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(localItem.type.color)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                .sheet(isPresented: $showStudyGuide) {
                                    StudyGuideView(guide: guide, accentColor: localItem.type.color)
                                        .frame(width: 600, height: 700)
                                }

                                Button {
                                    Task { await generateStudyGuide() }
                                } label: {
                                    HStack(spacing: 5) {
                                        if isGeneratingGuide {
                                            ProgressView().controlSize(.mini).tint(Color(hex: "8E8EA0"))
                                        } else {
                                            Image(systemName: "arrow.clockwise")
                                                .font(.system(size: 11))
                                        }
                                        Text("Regenerate")
                                            .font(.system(size: 12))
                                    }
                                    .foregroundColor(Color(hex: "8E8EA0"))
                                }
                                .buttonStyle(.plain)
                                .disabled(isGeneratingGuide)
                            }
                        }
                        .padding(12)
                        .background(localItem.type.color.opacity(0.07))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(localItem.type.color.opacity(0.2)))
                    } else {
                        // Generate button
                        Button {
                            Task { await generateStudyGuide() }
                        } label: {
                            HStack(spacing: 8) {
                                if isGeneratingGuide {
                                    ProgressView().controlSize(.small).tint(.black)
                                    Text("Claude is researching…")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.black)
                                } else {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 13))
                                    Text("Generate Study Guide with Claude")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [localItem.type.color, localItem.type.color.opacity(0.7)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .disabled(isGeneratingGuide)
                    }
                }
            }
        }
    }

    // MARK: - Generate study guide
    func generateStudyGuide() async {
        isGeneratingGuide = true
        do {
            let guide = try await AnthropicService.generateStudyGuide(
                topic:    localItem.title,
                subject:  localItem.subject,
                itemType: localItem.type,
                dueDate:  localItem.dueDate,
                notes:    localItem.notes
            )
            store.saveStudyGuide(guide, for: localItem.id)
            showStudyGuide = true
        } catch {
            guideErrorMessage = error.localizedDescription
            showGuideError = true
        }
        isGeneratingGuide = false
    }

    // MARK: - Upcoming from same subject
    var upcomingSection: some View {
        let upcoming = store.upcomingItems(for: localItem.subject, excluding: localItem.id)

        return Group {
            if !upcoming.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Upcoming in \(localItem.subject)")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(upcoming.count) item\(upcoming.count == 1 ? "" : "s")")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "8E8EA0"))
                    }

                    ForEach(upcoming) { upcomingItem in
                        upcomingRow(upcomingItem)
                    }
                }
            }
        }
    }

    func upcomingRow(_ upcomingItem: ScheduleItem) -> some View {
        let isExpanded = expandedItemID == upcomingItem.id

        return VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    expandedItemID = isExpanded ? nil : upcomingItem.id
                }
            } label: {
                HStack(spacing: 10) {
                    // Type dot
                    Circle()
                        .fill(upcomingItem.type.color)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(upcomingItem.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(upcomingDueDateLabel(upcomingItem))
                            .font(.system(size: 11))
                            .foregroundColor(upcomingItem.isOverdue ? .red : Color(hex: "8E8EA0"))
                    }

                    Spacer()

                    Label(upcomingItem.type.rawValue, systemImage: upcomingItem.type.icon)
                        .font(.system(size: 10))
                        .foregroundColor(upcomingItem.type.color.opacity(0.7))

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "5A5A72"))
                }
                .padding(12)
            }
            .buttonStyle(.plain)

            // Expanded detail
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider().background(Color.white.opacity(0.07))

                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "8E8EA0"))
                        Text(fullDateString(upcomingItem.dueDate))
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "8E8EA0"))
                    }
                    .padding(.horizontal, 12)

                    if !upcomingItem.notes.isEmpty {
                        Text(upcomingItem.notes)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "8E8EA0"))
                            .padding(.horizontal, 12)
                    }

                    // Quick complete button
                    Button {
                        store.toggleScheduleItem(id: upcomingItem.id)
                        if isExpanded { expandedItemID = nil }
                    } label: {
                        Label("Mark Complete", systemImage: "checkmark.circle")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(upcomingItem.type.color)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.06)))
        )
    }

    // MARK: - Helpers
    var dueDateString: String {
        let days = localItem.daysUntilDue
        let full = fullDateString(localItem.dueDate)
        if localItem.isCompleted { return "Completed · \(full)" }
        if days < 0  { return "Overdue by \(-days) day\(-days == 1 ? "" : "s") · \(full)" }
        if days == 0 { return "Due today · \(full)" }
        if days == 1 { return "Due tomorrow · \(full)" }
        return "Due in \(days) days · \(full)"
    }

    func upcomingDueDateLabel(_ item: ScheduleItem) -> String {
        let days = item.daysUntilDue
        if days == 0 { return "Due today" }
        if days == 1 { return "Due tomorrow" }
        if days < 0  { return "Overdue \(-days)d" }
        return "Due in \(days)d"
    }

    func fullDateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }
}
