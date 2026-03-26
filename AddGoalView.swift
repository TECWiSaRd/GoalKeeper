// AddGoalView.swift
// New goal sheet — macOS native (NSOpenPanel for file picking, no PhotosUI)

import SwiftUI
import AppKit
internal import UniformTypeIdentifiers

struct AddGoalView: View {
    @EnvironmentObject var store: GoalStore
    @Binding var isPresented: Bool

    @State private var title        = ""
    @State private var description  = ""
    @State private var selectedType: GoalType     = .assignment
    @State private var selectedPriority: GoalPriority = .medium
    @State private var hasDueDate   = false
    @State private var dueDate      = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var rubricText   = ""
    @State private var showRubric   = false
    @State private var attachedImage: NSImage?
    @State private var isAnalyzing  = false
    @State private var errorMessage = ""
    @State private var showError    = false
    @State private var analysisResult: GoalAnalysis?

    var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("New Goal")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "5A5A72"))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Divider().background(Color.white.opacity(0.08))

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Type picker
                    typePicker

                    // Form fields
                    VStack(spacing: 0) {
                        field(label: "Title") {
                            TextField("e.g. Research Paper on Climate Change", text: $title)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                        rowDivider
                        field(label: "Description") {
                            ZStack(alignment: .topLeading) {
                                if description.isEmpty {
                                    Text("Describe the goal, requirements, or what success looks like…")
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(hex: "5A5A72"))
                                        .allowsHitTesting(false)
                                }
                                TextEditor(text: $description)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white)
                                    .frame(minHeight: 70)
                                    .scrollContentBackground(.hidden)
                                    .background(Color.clear)
                            }
                        }
                        rowDivider
                        field(label: "Priority") {
                            HStack(spacing: 6) {
                                ForEach(GoalPriority.allCases, id: \.self) { p in
                                    Button {
                                        withAnimation(.spring(response: 0.25)) { selectedPriority = p }
                                    } label: {
                                        Text(p.rawValue)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(selectedPriority == p ? .black : p.color)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(selectedPriority == p ? p.color : p.color.opacity(0.1))
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                                Spacer()
                            }
                        }
                        rowDivider
                        field(label: "Due Date") {
                            VStack(alignment: .leading, spacing: 6) {
                                Toggle("Set a due date", isOn: $hasDueDate)
                                    .toggleStyle(.switch)
                                    .tint(Color(hex: "4ECDC4"))
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "8E8EA0"))
                                if hasDueDate {
                                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                        .colorScheme(.dark)
                                }
                            }
                        }
                        rowDivider
                        field(label: "Rubric / Requirements") {
                            VStack(alignment: .leading, spacing: 8) {
                                Button {
                                    withAnimation { showRubric.toggle() }
                                } label: {
                                    HStack {
                                        Text(showRubric ? "Hide rubric" : "Add rubric or grading criteria")
                                            .font(.system(size: 13))
                                            .foregroundColor(Color(hex: "4ECDC4"))
                                        Spacer()
                                        Image(systemName: showRubric ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 10))
                                            .foregroundColor(Color(hex: "4ECDC4"))
                                    }
                                }
                                .buttonStyle(.plain)

                                if showRubric {
                                    ZStack(alignment: .topLeading) {
                                        if rubricText.isEmpty {
                                            Text("Paste rubric, criteria, or requirements…")
                                                .font(.system(size: 12))
                                                .foregroundColor(Color(hex: "5A5A72"))
                                                .allowsHitTesting(false)
                                        }
                                        TextEditor(text: $rubricText)
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                            .frame(minHeight: 80)
                                            .scrollContentBackground(.hidden)
                                            .background(Color.white.opacity(0.04))
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        rowDivider
                        field(label: "Attach Image") {
                            HStack(spacing: 10) {
                                Button {
                                    pickImage()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: attachedImage == nil ? "photo.badge.plus" : "photo.fill")
                                        Text(attachedImage == nil ? "Choose Image…" : "Change Image…")
                                            .font(.system(size: 13))
                                    }
                                    .foregroundColor(Color(hex: "4ECDC4"))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(hex: "4ECDC4").opacity(0.1))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)

                                if let img = attachedImage {
                                    Image(nsImage: img)
                                        .resizable().scaledToFill()
                                        .frame(width: 44, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            Button {
                                                attachedImage = nil
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .background(Color.black.opacity(0.5))
                                                    .clipShape(Circle())
                                                    .font(.system(size: 14))
                                            }
                                            .buttonStyle(.plain)
                                            .offset(x: 5, y: -5),
                                            alignment: .topTrailing
                                        )
                                }
                            }
                        }
                    }
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08)))

                    // Analyze button
                    analyzeButton

                    // Preview
                    if let result = analysisResult {
                        previewCard(result)
                    }

                    Spacer().frame(height: 16)
                }
                .padding(18)
            }
        }
        .background(Color(hex: "111118"))
        .frame(width: 560, height: 680)
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: { Text(errorMessage) }
    }

    // MARK: - Type Picker
    var typePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(GoalType.allCases, id: \.self) { t in
                    Button {
                        withAnimation(.spring(response: 0.25)) { selectedType = t }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: t.icon)
                                .font(.system(size: 13))
                            Text(t.rawValue)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(selectedType == t ? .black : t.accentColor.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(selectedType == t ? t.accentColor : t.accentColor.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Form helpers
    var rowDivider: some View {
        Divider().background(Color.white.opacity(0.07)).padding(.horizontal, 14)
    }

    func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Color(hex: "5A5A72"))
                .kerning(0.8)
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Analyze button
    var analyzeButton: some View {
        Button {
            if !KeychainService.hasKey {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                return
            }
            Task { await analyze() }
        } label: {
            HStack(spacing: 8) {
                if isAnalyzing {
                    ProgressView().controlSize(.small).tint(.black)
                    Text("Claude is analyzing…")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                    Text("Analyze with Claude AI")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                isValid
                ? LinearGradient(colors: [Color(hex: "4ECDC4"), Color(hex: "2ECC71")], startPoint: .leading, endPoint: .trailing)
                : LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(!isValid || isAnalyzing)
    }

    // MARK: - Preview card
    func previewCard(_ result: GoalAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("AI Plan Preview", systemImage: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: "4ECDC4"))
                Spacer()
                Text("\(result.steps.count) steps")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "8E8EA0"))
            }

            Text(result.summary)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "8E8EA0"))
                .lineSpacing(3)

            VStack(spacing: 6) {
                ForEach(Array(result.steps.enumerated()), id: \.element.id) { i, step in
                    HStack(alignment: .top, spacing: 10) {
                        ZStack {
                            Circle().fill(selectedType.accentColor.opacity(0.2)).frame(width: 22, height: 22)
                            Text("\(i + 1)").font(.system(size: 10, weight: .bold)).foregroundColor(selectedType.accentColor)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            HStack {
                                Text(step.title).font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
                                Spacer()
                                Text(step.estimatedTime).font(.system(size: 10)).foregroundColor(Color(hex: "5A5A72"))
                            }
                            Text(step.detail).font(.system(size: 11)).foregroundColor(Color(hex: "8E8EA0")).lineSpacing(3)
                        }
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(8)
                }
            }

            Button { saveGoal(analysis: result) } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Save Goal & Start Tracking")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(hex: "4ECDC4"))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color(hex: "4ECDC4").opacity(0.05))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "4ECDC4").opacity(0.2)))
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Image picker (macOS NSOpenPanel)
    func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Attach Image"
        if panel.runModal() == .OK, let url = panel.url,
           let img = NSImage(contentsOf: url) {
            attachedImage = img
        }
    }

    // MARK: - Analyze
    func analyze() async {
        guard isValid else { return }
        withAnimation { isAnalyzing = true; analysisResult = nil }
        do {
            let result = try await AnthropicService.analyzeGoal(
                title: title,
                description: description,
                type: selectedType,
                dueDate: hasDueDate ? dueDate : nil,
                rubric: rubricText,
                image: attachedImage
            )
            withAnimation(.spring()) { analysisResult = result }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        withAnimation { isAnalyzing = false }
    }

    // MARK: - Save
    func saveGoal(analysis: GoalAnalysis) {
        var goal = Goal(title: title, description: description, type: selectedType, priority: selectedPriority)
        if hasDueDate { goal.dueDate = dueDate }
        goal.rubricText = rubricText
        goal.attachedImageData = attachedImage.flatMap {
            guard let tiff = $0.tiffRepresentation,
                  let bm = NSBitmapImageRep(data: tiff)
            else { return nil }
            return bm.representation(using: .jpeg, properties: [.compressionFactor: 0.7])
        }
        goal.isAnalyzed = true
        goal.aiSummary = analysis.summary
        goal.steps = analysis.steps.map {
            GoalStep(title: $0.title, detail: $0.detail, estimatedTime: $0.estimatedTime, tips: $0.tips)
        }
        store.add(goal)
        isPresented = false
    }
}
