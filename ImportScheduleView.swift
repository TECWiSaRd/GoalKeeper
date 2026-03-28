// ImportScheduleView.swift
// Import a homework schedule via text or image — Claude extracts all items

import SwiftUI
import AppKit
internal import UniformTypeIdentifiers

struct ImportScheduleView: View {
    @EnvironmentObject var store: GoalStore
    @Binding var isPresented: Bool

    @State private var scheduleText  = ""
    @State private var attachedImage: NSImage?
    @State private var isParsing     = false
    @State private var parsedItems:  [EditableScheduleItem] = []
    @State private var errorMessage  = ""
    @State private var showError     = false

    var canParse: Bool {
        !scheduleText.trimmingCharacters(in: .whitespaces).isEmpty || attachedImage != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Import Schedule")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Paste your homework schedule or attach a photo — Claude will extract all assignments.")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "8E8EA0"))
                }
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
                    if parsedItems.isEmpty {
                        inputSection
                        parseButton
                    } else {
                        reviewSection
                    }
                    Spacer().frame(height: 16)
                }
                .padding(18)
            }
        }
        .background(Color(hex: "111118"))
        .frame(width: 580, height: 620)
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: { Text(errorMessage) }
    }

    // MARK: - Input section
    var inputSection: some View {
        VStack(spacing: 12) {
            // Text input
            VStack(alignment: .leading, spacing: 6) {
                Text("PASTE SCHEDULE TEXT")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "5A5A72"))
                    .kerning(0.8)

                ZStack(alignment: .topLeading) {
                    if scheduleText.isEmpty {
                        Text("e.g.\nMath – Chapter 5 Problems – due Mon 3/3\nHistory – Read Ch.3 – due Tue 3/4\nBiology – Lab Report – due Wed 3/5")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Color(hex: "3A3A50"))
                            .allowsHitTesting(false)
                            .padding(.top, 2)
                    }
                    TextEditor(text: $scheduleText)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(minHeight: 140)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                }
                .padding(10)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08)))
            }

            // Divider with "or"
            HStack {
                Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                Text("or")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "5A5A72"))
                    .padding(.horizontal, 8)
                Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
            }

            // Image attachment
            VStack(alignment: .leading, spacing: 6) {
                Text("ATTACH PHOTO OF SCHEDULE")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "5A5A72"))
                    .kerning(0.8)

                HStack(spacing: 12) {
                    Button { pickImage() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: attachedImage == nil ? "photo.badge.plus" : "photo.fill")
                            Text(attachedImage == nil ? "Choose Image…" : "Change Image…")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(Color(hex: "FFE66D"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color(hex: "FFE66D").opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    if let img = attachedImage {
                        Image(nsImage: img)
                            .resizable().scaledToFill()
                            .frame(width: 50, height: 50)
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
    }

    // MARK: - Parse button
    var parseButton: some View {
        Button {
            Task { await parseSchedule() }
        } label: {
            HStack(spacing: 8) {
                if isParsing {
                    ProgressView().controlSize(.small).tint(.black)
                    Text("Claude is reading your schedule…")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                } else {
                    Image(systemName: "sparkles")
                    Text("Extract Assignments with Claude")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                canParse
                ? LinearGradient(colors: [Color(hex: "FFE66D"), Color(hex: "FFB347")], startPoint: .leading, endPoint: .trailing)
                : LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(!canParse || isParsing)
    }

    // MARK: - Review section
    var reviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Review Extracted Assignments", systemImage: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "FFE66D"))
                Spacer()
                Text("\(parsedItems.count) found")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "8E8EA0"))
            }

            Text("Review and edit before saving. Uncheck any you don't want to add.")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "8E8EA0"))

            VStack(spacing: 6) {
                ForEach($parsedItems) { $editItem in
                    reviewRow(item: $editItem)
                }
            }

            HStack(spacing: 10) {
                Button {
                    parsedItems = []
                } label: {
                    Text("Start Over")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "8E8EA0"))
                }
                .buttonStyle(.plain)

                Spacer()

                let toAdd = parsedItems.filter { $0.include }.count
                Button {
                    saveItems()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Add \(toAdd) Assignment\(toAdd == 1 ? "" : "s")")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(toAdd > 0 ? Color(hex: "4ECDC4") : Color.gray.opacity(0.3))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(toAdd == 0)
            }
        }
        .padding(14)
        .background(Color(hex: "FFE66D").opacity(0.04))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "FFE66D").opacity(0.15)))
    }

    func reviewRow(item: Binding<EditableScheduleItem>) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: item.include)
                .toggleStyle(.checkbox)
                .labelsHidden()

            Image(systemName: item.wrappedValue.type.icon)
                .font(.system(size: 12))
                .foregroundColor(item.wrappedValue.type.color)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                TextField("Title", text: item.title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                HStack(spacing: 6) {
                    TextField("Subject", text: item.subject)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "8E8EA0"))
                    Text("·")
                        .foregroundColor(Color(hex: "5A5A72"))
                    Text(item.wrappedValue.type.rawValue)
                        .font(.system(size: 10))
                        .foregroundColor(item.wrappedValue.type.color)
                    Text("·")
                        .foregroundColor(Color(hex: "5A5A72"))
                    Text(shortDate(item.wrappedValue.dueDate))
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "8E8EA0"))
                }
            }

            Spacer()
        }
        .padding(8)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
        .opacity(item.wrappedValue.include ? 1 : 0.4)
    }

    // MARK: - Helpers
    func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url,
           let img = NSImage(contentsOf: url) {
            attachedImage = img
        }
    }

    func parseSchedule() async {
        withAnimation { isParsing = true }
        do {
            let results = try await AnthropicService.parseSchedule(
                text: scheduleText,
                image: attachedImage
            )
            withAnimation(.spring()) {
                parsedItems = results.map { EditableScheduleItem(from: $0) }
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        withAnimation { isParsing = false }
    }

    func saveItems() {
        let items = parsedItems.filter { $0.include }.map { $0.toScheduleItem() }
        store.addScheduleItems(items)
        isPresented = false
    }

    func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}

// MARK: - Editable wrapper for review
struct EditableScheduleItem: Identifiable {
    var id = UUID()
    var title: String
    var subject: String
    var type: ScheduleItemType
    var dueDate: Date
    var notes: String
    var include: Bool = true

    init(from parsed: ParsedScheduleItem) {
        self.title   = parsed.title
        self.subject = parsed.subject
        self.type    = parsed.type
        self.dueDate = parsed.dueDate
        self.notes   = parsed.notes
    }

    func toScheduleItem() -> ScheduleItem {
        ScheduleItem(title: title, subject: subject, type: type, dueDate: dueDate, notes: notes)
    }
}
