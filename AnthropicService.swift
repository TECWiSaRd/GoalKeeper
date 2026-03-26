// AnthropicService.swift
// Anthropic Claude API — macOS version (NSImage instead of UIImage)

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

// MARK: - Service
class AnthropicService {

    // ⚠️ Replace with your Anthropic API key from console.anthropic.com
    static let apiKey = "YOUR_ANTHROPIC_API_KEY_HERE"

    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    static let model    = "claude-opus-4-5"

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

        // Attach image if provided
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
        return try parseAnalysis(from: text)
    }

    private static func parseAnalysis(from text: String) throws -> GoalAnalysis {
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
