// StudyGuideView.swift
// Full study guide panel shown when a study guide is generated for a schedule item

import SwiftUI

struct StudyGuideView: View {
    var guide: StudyGuide
    var accentColor: Color

    @State private var expandedSections: Set<UUID>  = []
    @State private var revealedAnswers:  Set<UUID>  = []
    @State private var selectedTab: GuideTab = .content

    enum GuideTab: String, CaseIterable {
        case content   = "Study Guide"
        case practice  = "Practice"
        case tips      = "Tips"
    }

    var body: some View {
        VStack(spacing: 0) {
            guideHeader
            tabBar
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    switch selectedTab {
                    case .content:  contentTab
                    case .practice: practiceTab
                    case .tips:     tipsTab
                    }
                    Spacer().frame(height: 20)
                }
                .padding(16)
            }
        }
        .background(Color(hex: "0D0D12"))
        .onAppear {
            // Expand first section by default
            if let first = guide.sections.first {
                expandedSections.insert(first.id)
            }
        }
    }

    // MARK: - Header
    var guideHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "book.fill")
                    .font(.system(size: 13))
                    .foregroundColor(accentColor)
                Text("STUDY GUIDE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(accentColor)
                    .kerning(0.8)
                Spacer()
                Text("Generated \(guide.generatedDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "5A5A72"))
            }

            Text(guide.title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(guide.overview)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "8E8EA0"))
                .lineSpacing(4)
        }
        .padding(16)
        .background(accentColor.opacity(0.07))
        .overlay(Rectangle().frame(height: 1).foregroundColor(accentColor.opacity(0.2)), alignment: .bottom)
    }

    // MARK: - Tab bar
    var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(GuideTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3)) { selectedTab = tab }
                } label: {
                    VStack(spacing: 4) {
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(selectedTab == tab ? accentColor : Color(hex: "8E8EA0"))
                        Rectangle()
                            .fill(selectedTab == tab ? accentColor : Color.clear)
                            .frame(height: 2)
                            .cornerRadius(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.white.opacity(0.04))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color.white.opacity(0.07)), alignment: .bottom)
    }

    // MARK: - Content tab (sections)
    var contentTab: some View {
        VStack(spacing: 8) {
            ForEach(guide.sections) { section in
                sectionCard(section)
            }
        }
    }

    func sectionCard(_ section: StudyGuideSection) -> some View {
        let isExpanded = expandedSections.contains(section.id)
        return VStack(spacing: 0) {
            // Section header
            Button {
                withAnimation(.spring(response: 0.3)) {
                    if isExpanded { expandedSections.remove(section.id) }
                    else          { expandedSections.insert(section.id) }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(accentColor)
                        .frame(width: 12)
                    Text(section.heading)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(section.keyPoints.count) key points")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "5A5A72"))
                }
                .padding(12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider().background(Color.white.opacity(0.07))

                    // Main content
                    Text(section.content)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "8E8EA0"))
                        .lineSpacing(5)
                        .padding(.horizontal, 12)

                    // Key points
                    if !section.keyPoints.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("KEY POINTS")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Color(hex: "5A5A72"))
                                .kerning(0.8)

                            ForEach(section.keyPoints, id: \.self) { point in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(accentColor)
                                        .frame(width: 5, height: 5)
                                        .padding(.top, 4)
                                    Text(point)
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.85))
                                        .lineSpacing(3)
                                }
                            }
                        }
                        .padding(10)
                        .background(accentColor.opacity(0.06))
                        .cornerRadius(8)
                        .padding(.horizontal, 12)
                    }

                    Spacer().frame(height: 4)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(isExpanded ? accentColor.opacity(0.2) : Color.white.opacity(0.06)))
        )
    }

    // MARK: - Practice tab
    var practiceTab: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Tap a question to reveal the answer")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "5A5A72"))
                Spacer()
                Button {
                    if revealedAnswers.count == guide.practiceQuestions.count {
                        revealedAnswers = []
                    } else {
                        revealedAnswers = Set(guide.practiceQuestions.map { $0.id })
                    }
                } label: {
                    Text(revealedAnswers.count == guide.practiceQuestions.count ? "Hide All" : "Reveal All")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(accentColor)
                }
                .buttonStyle(.plain)
            }

            ForEach(Array(guide.practiceQuestions.enumerated()), id: \.element.id) { i, q in
                practiceCard(q, index: i + 1)
            }
        }
    }

    func practiceCard(_ q: PracticeQuestion, index: Int) -> some View {
        let isRevealed = revealedAnswers.contains(q.id)
        return Button {
            withAnimation(.spring(response: 0.35)) {
                if isRevealed { revealedAnswers.remove(q.id) }
                else          { revealedAnswers.insert(q.id) }
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.15))
                            .frame(width: 22, height: 22)
                        Text("\(index)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(accentColor)
                    }
                    Text(q.question)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "5A5A72"))
                }

                if isRevealed {
                    Divider().background(Color.white.opacity(0.07))
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                            .padding(.top, 1)
                        Text(q.answer)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "A8E6CF"))
                            .lineSpacing(4)
                            .multilineTextAlignment(.leading)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isRevealed ? Color.green.opacity(0.06) : Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(isRevealed ? Color.green.opacity(0.2) : Color.white.opacity(0.06)))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tips tab
    var tipsTab: some View {
        VStack(spacing: 10) {
            ForEach(Array(guide.studyTips.enumerated()), id: \.offset) { i, tip in
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(hex: "FFE66D").opacity(0.15))
                            .frame(width: 28, height: 28)
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "FFE66D"))
                    }
                    Text(tip)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.85))
                        .lineSpacing(4)
                    Spacer()
                }
                .padding(12)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)
            }
        }
    }
}
