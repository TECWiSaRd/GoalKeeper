// AnthropicService.swift
// Anthropic Claude API — macOS version

import Foundation
import AppKit

// MARK: - Request / Response types
private struct AnthropicRequest: Encodable {
    let model: String
    let max_tokens: Int
    let system: String
    let messages: [Message]

    struct Message: Encodable {
        let role: String
        let content: [ContentBlock]
    }

    struct ContentBlock: Encodable {
        let type: String
        var text: String?
        var source: ImageSource?

        struct ImageSource: Encodable {
            let type: String
            let media_type: String
            let data: String
        }
    }
}

private struct AnthropicResponse: Decodable {
    let content: [ContentItem]
    struct ContentItem: Decodable {
        let type: String
        let text: String?
    }
}

// MARK: - Output models
struct AnalyzedStep: Identifiable {
    var id = UUID()
    var title: String
    var detail: String
    var estimatedTime: String
    var tips: [String]
}

struct GoalAnalysis {
    var summary: String
    var steps: [AnalyzedStep]
}

struct ParsedScheduleItem {
    var title: String
    var subject: String
    var type: ScheduleItemType
    var dueDate: Date
    var notes: String
}

// MARK: - Service
class AnthropicService {

    static var apiKey: String { KeychainService.load() ?? "" }
    static var model: String  { KeychainService.selectedModel }

    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    // MARK: - Analyze Goal
    static func analyzeGoal(
        title: String,
        description: String,
        type: GoalType,
        dueDate: Date?,
        rubric: String,
        image: NSImage?
    ) async throws -> GoalAnalysis {

        let dueDateStr: String = {
            guard let d = dueDate else { return "No specific deadline" }
            let f = DateFormatter(); f.dateStyle = .medium
            return f.string(from: d)
        }()

        let systemPrompt = """
        You are an expert academic and personal productivity coach. Analyze a goal or assignment and break it into clear, actionable steps.

        Respond ONLY in this exact JSON format:
        {
          "summary": "2-3 sentence overview of what success looks like",
          "steps": [
            {
              "title": "Short step title (5 words max)",
              "detail": "Specific 1-2 sentence action description",
              "estimatedTime": "Realistic time estimate (e.g. '30 min', '2 hrs', '1 day')",
              "tips": ["Practical tip 1", "Practical tip 2"]
            }
          ]
        }

        Rules:
        - 4–8 steps, ordered logically
        - Each step specific and actionable
        - If rubric provided, steps must address every criterion
        - No text outside the JSON object
        """

        var userPrompt = """
        Goal Title: \(title)
        Goal Type: \(type.rawValue)
        Description: \(description)
        Due Date: \(dueDateStr)
        """
        if !rubric.isEmpty { userPrompt += "\n\nRubric/Requirements:\n\(rubric)" }
        userPrompt += "\n\nPlease analyze and produce a detailed plan."

        var contentBlocks: [AnthropicRequest.ContentBlock] = []

        if let image = image,
           let tiff = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) {
            let base64 = jpegData.base64EncodedString()
            contentBlocks.append(.init(type: "image", source: .init(type: "base64", media_type: "image/jpeg", data: base64)))
            userPrompt += "\n\n(An image is attached — incorporate any relevant details from it.)"
        }

        contentBlocks.append(.init(type: "text", text: userPrompt))

        let body = AnthropicRequest(
            model: model,
            max_tokens: 2000,
            system: systemPrompt,
            messages: [.init(role: "user", content: contentBlocks)]
        )

        let text = try await sendRequest(body)
        return try parseGoalAnalysis(from: text)
    }

    // MARK: - Parse Schedule
    static func parseSchedule(
        text: String,
        image: NSImage?
    ) async throws -> [ParsedScheduleItem] {

        let today = DateFormatter().string(from: Date())
        let systemPrompt = """
        You are a homework schedule parser. Extract all assignments, tests, quizzes, and due dates from the provided schedule.
        Today's date is \(Date().formatted(date: .long, time: .omitted)).

        Respond ONLY in this exact JSON format:
        {
          "items": [
            {
              "title": "Assignment or test name",
              "subject": "Class or subject name",
              "type": "homework|test|quiz|project|reading|other",
              "dueDate": "YYYY-MM-DD",
              "notes": "Any extra details (optional, can be empty string)"
            }
          ]
        }

        Rules:
        - Extract every assignment, test, quiz, reading, and project
        - Use the exact class/subject name as written
        - Dates must be in YYYY-MM-DD format
        - If a year is not specified, assume the current or next upcoming date
        - No text outside the JSON object
        """

        var userPrompt = "Please extract all assignments and due dates from this schedule."
        if !text.isEmpty { userPrompt += "\n\nSchedule text:\n\(text)" }

        var contentBlocks: [AnthropicRequest.ContentBlock] = []

        if let image = image,
           let tiff = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
            let base64 = jpegData.base64EncodedString()
            contentBlocks.append(.init(type: "image", source: .init(type: "base64", media_type: "image/jpeg", data: base64)))
        }

        contentBlocks.append(.init(type: "text", text: userPrompt))

        let body = AnthropicRequest(
            model: model,
            max_tokens: 2000,
            system: systemPrompt,
            messages: [.init(role: "user", content: contentBlocks)]
        )

        let responseText = try await sendRequest(body)
        return try parseScheduleItems(from: responseText)
    }

    // MARK: - Generate Study Guide
    static func generateStudyGuide(
        topic: String,
        subject: String,
        itemType: ScheduleItemType,
        dueDate: Date,
        notes: String
    ) async throws -> StudyGuide {

        let dueDateStr = dueDate.formatted(date: .long, time: .omitted)
        let daysLeft   = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0

        let systemPrompt = """
        You are an expert tutor and study guide creator. Create a comprehensive study guide for a student.

        Respond ONLY in this exact JSON format:
        {
          "title": "Study Guide title",
          "overview": "2-3 sentence summary of what to focus on",
          "sections": [
            {
              "heading": "Section heading",
              "content": "Detailed explanation, key concepts, formulas, definitions etc.",
              "keyPoints": ["Key point 1", "Key point 2", "Key point 3"]
            }
          ],
          "practiceQuestions": [
            {
              "question": "Practice question text",
              "answer": "Full answer"
            }
          ],
          "studyTips": ["Tip 1", "Tip 2", "Tip 3"]
        }

        Rules:
        - Create 3-6 sections covering all major topics
        - Each section should have 2-5 key points
        - Include 3-6 practice questions with full answers
        - 3-4 study tips specific to this subject/topic
        - Make content accurate and educationally appropriate
        - Tailor depth to the time available before due date
        - No text outside the JSON object
        """

        let userPrompt = """
        Subject: \(subject)
        Topic/Assignment: \(topic)
        Type: \(itemType.rawValue)
        Due Date: \(dueDateStr) (\(daysLeft) day\(daysLeft == 1 ? "" : "s") away)
        \(notes.isEmpty ? "" : "Additional notes: \(notes)")

        Please create a comprehensive study guide for this topic.
        """

        let body = AnthropicRequest(
            model: model,
            max_tokens: 4000,
            system: systemPrompt,
            messages: [.init(role: "user", content: [.init(type: "text", text: userPrompt)])]
        )

        let text = try await sendRequest(body)
        return try parseStudyGuide(from: text)
    }

    // MARK: - Parse Study Guide JSON
    private static func parseStudyGuide(from text: String) throws -> StudyGuide {
        var clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("```json") { clean = String(clean.dropFirst(7)) }
        if clean.hasPrefix("```")    { clean = String(clean.dropFirst(3)) }
        if clean.hasSuffix("```")   { clean = String(clean.dropLast(3)) }
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = clean.data(using: .utf8) else { throw APIError.parseError }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let title       = json?["title"]    as? String,
              let overview    = json?["overview"] as? String,
              let sectionsRaw = json?["sections"] as? [[String: Any]]
        else { throw APIError.parseError }

        let sections: [StudyGuideSection] = sectionsRaw.compactMap { d in
            guard let heading = d["heading"] as? String,
                  let content = d["content"] as? String else { return nil }
            return StudyGuideSection(
                heading:   heading,
                content:   content,
                keyPoints: d["keyPoints"] as? [String] ?? []
            )
        }

        let questionsRaw = json?["practiceQuestions"] as? [[String: Any]] ?? []
        let questions: [PracticeQuestion] = questionsRaw.compactMap { d in
            guard let q = d["question"] as? String,
                  let a = d["answer"]   as? String else { return nil }
            return PracticeQuestion(question: q, answer: a)
        }

        return StudyGuide(
            title:             title,
            overview:          overview,
            sections:          sections,
            practiceQuestions: questions,
            studyTips:         json?["studyTips"] as? [String] ?? []
        )
    }

        // MARK: - Shared request sender
    private static func sendRequest(_ body: AnthropicRequest) async throws -> String {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.httpBody = try JSONEncoder().encode(body)
        req.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard http.statusCode == 200 else {
            throw APIError.serverError(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        guard let text = decoded.content.first?.text else { throw APIError.emptyResponse }
        return text
    }

    // MARK: - Parse Goal Analysis JSON
    private static func parseGoalAnalysis(from text: String) throws -> GoalAnalysis {
        var clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("```json") { clean = String(clean.dropFirst(7)) }
        if clean.hasPrefix("```")    { clean = String(clean.dropFirst(3)) }
        if clean.hasSuffix("```")   { clean = String(clean.dropLast(3)) }
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = clean.data(using: .utf8) else { throw APIError.parseError }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let summary = json?["summary"] as? String,
              let stepsRaw = json?["steps"] as? [[String: Any]] else { throw APIError.parseError }

        let steps: [AnalyzedStep] = stepsRaw.compactMap { d in
            guard let t = d["title"] as? String,
                  let det = d["detail"] as? String,
                  let time = d["estimatedTime"] as? String else { return nil }
            return AnalyzedStep(title: t, detail: det, estimatedTime: time, tips: d["tips"] as? [String] ?? [])
        }
        return GoalAnalysis(summary: summary, steps: steps)
    }

    // MARK: - Parse Schedule JSON
    private static func parseScheduleItems(from text: String) throws -> [ParsedScheduleItem] {
        var clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("```json") { clean = String(clean.dropFirst(7)) }
        if clean.hasPrefix("```")    { clean = String(clean.dropFirst(3)) }
        if clean.hasSuffix("```")   { clean = String(clean.dropLast(3)) }
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = clean.data(using: .utf8) else { throw APIError.parseError }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let itemsRaw = json?["items"] as? [[String: Any]] else { throw APIError.parseError }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        return itemsRaw.compactMap { d in
            guard let title   = d["title"]   as? String,
                  let subject = d["subject"] as? String,
                  let typeStr = d["type"]    as? String,
                  let dateStr = d["dueDate"] as? String,
                  let date    = formatter.date(from: dateStr) else { return nil }

            let itemType: ScheduleItemType = {
                switch typeStr.lowercased() {
                case "test":     return .test
                case "quiz":     return .quiz
                case "project":  return .project
                case "reading":  return .reading
                case "homework": return .homework
                default:         return .other
                }
            }()

            return ParsedScheduleItem(
                title:   title,
                subject: subject,
                type:    itemType,
                dueDate: date,
                notes:   d["notes"] as? String ?? ""
            )
        }
    }

    // MARK: - Errors
    enum APIError: LocalizedError {
        case invalidResponse, serverError(Int, String), emptyResponse, parseError
        var errorDescription: String? {
            switch self {
            case .invalidResponse:           return "Invalid server response."
            case .serverError(let c, let m): return "Server error \(c): \(m)"
            case .emptyResponse:             return "No content returned from AI."
            case .parseError:                return "Could not parse the AI response. Please try again."
            }
        }
    }
}
