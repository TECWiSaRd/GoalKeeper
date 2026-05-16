// lib/services/anthropic_service.dart
// Anthropic Claude API — translated from Swift AnthropicService.swift

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:goalkeeper_flutter/models/models.dart';
import 'package:goalkeeper_flutter/services/keychain_service.dart';

// ─── Result models ────────────────────────────────────────────────────────────

class AnalyzedStep {
  final String title;
  final String detail;
  final String estimatedTime;
  final List<String> tips;
  AnalyzedStep({required this.title, required this.detail, required this.estimatedTime, required this.tips});
}

class GoalAnalysis {
  final String summary;
  final List<AnalyzedStep> steps;
  GoalAnalysis({required this.summary, required this.steps});
}

class ParsedScheduleItem {
  final String title;
  final String subject;
  final ScheduleItemType type;
  final DateTime dueDate;
  final String notes;
  ParsedScheduleItem({required this.title, required this.subject, required this.type, required this.dueDate, required this.notes});
}

// ─── Service ──────────────────────────────────────────────────────────────────

class AnthropicService {
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _apiVersion = '2023-06-01';

  // ── Shared request helper ─────────────────────────────────────────────────
  static Future<String> _sendRequest({
    required String model,
    required String apiKey,
    required int maxTokens,
    required String systemPrompt,
    required List<Map<String, dynamic>> contentBlocks,
  }) async {
    final body = jsonEncode({
      'model': model,
      'max_tokens': maxTokens,
      'system': systemPrompt,
      'messages': [
        {'role': 'user', 'content': contentBlocks}
      ],
    });

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': _apiVersion,
      },
      body: body,
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw AnthropicError('Server error ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final content = decoded['content'] as List<dynamic>;
    final text = (content.first as Map<String, dynamic>)['text'] as String?;
    if (text == null) throw AnthropicError('No content returned from AI.');
    return text;
  }

  // ── Parse JSON helper ─────────────────────────────────────────────────────
  static Map<String, dynamic> _parseJson(String text) {
    var clean = text.trim();
    if (clean.startsWith('```json')) clean = clean.substring(7);
    if (clean.startsWith('```'))     clean = clean.substring(3);
    if (clean.endsWith('```'))       clean = clean.substring(0, clean.length - 3);
    clean = clean.trim();
    return jsonDecode(clean) as Map<String, dynamic>;
  }

  // ── Analyze Goal ──────────────────────────────────────────────────────────
  static Future<GoalAnalysis> analyzeGoal({
    required String title,
    required String description,
    required GoalType type,
    DateTime? dueDate,
    String rubric = '',
    File? image,
  }) async {
    final apiKey = await KeychainService.loadApiKey() ?? '';
    final model  = await KeychainService.selectedModel;

    final dueDateStr = dueDate != null
        ? '${dueDate.month}/${dueDate.day}/${dueDate.year}'
        : 'No specific deadline';

    const systemPrompt = '''
You are an expert academic and personal productivity coach. Analyze a goal or assignment and break it into clear, actionable steps.

Respond ONLY in this exact JSON format:
{
  "summary": "2-3 sentence overview of what success looks like",
  "steps": [
    {
      "title": "Short step title (5 words max)",
      "detail": "Specific 1-2 sentence action description",
      "estimatedTime": "Realistic time estimate",
      "tips": ["Practical tip 1", "Practical tip 2"]
    }
  ]
}

Rules:
- 4–8 steps, ordered logically
- Each step specific and actionable
- If rubric provided, steps must address every criterion
- No text outside the JSON object''';

    var userPrompt = 'Goal Title: $title\nGoal Type: ${type.label}\nDescription: $description\nDue Date: $dueDateStr';
    if (rubric.isNotEmpty) userPrompt += '\n\nRubric/Requirements:\n$rubric';
    userPrompt += '\n\nPlease analyze and produce a detailed plan.';

    final contentBlocks = <Map<String, dynamic>>[];

    if (image != null) {
      final bytes  = await image.readAsBytes();
      final base64 = base64Encode(bytes);
      contentBlocks.add({
        'type': 'image',
        'source': {'type': 'base64', 'media_type': 'image/jpeg', 'data': base64},
      });
      userPrompt += '\n\n(An image is attached — incorporate any relevant details from it.)';
    }

    contentBlocks.add({'type': 'text', 'text': userPrompt});

    final text = await _sendRequest(
      model: model, apiKey: apiKey, maxTokens: 2000,
      systemPrompt: systemPrompt, contentBlocks: contentBlocks,
    );

    final json = _parseJson(text);
    final summary   = json['summary'] as String;
    final stepsRaw  = json['steps'] as List<dynamic>;
    final steps = stepsRaw.map((s) {
      final d = s as Map<String, dynamic>;
      return AnalyzedStep(
        title: d['title'] as String,
        detail: d['detail'] as String,
        estimatedTime: d['estimatedTime'] as String,
        tips: (d['tips'] as List<dynamic>?)?.cast<String>() ?? [],
      );
    }).toList();

    return GoalAnalysis(summary: summary, steps: steps);
  }

  // ── Parse Schedule ────────────────────────────────────────────────────────
  static Future<List<ParsedScheduleItem>> parseSchedule({
    String text = '',
    File? image,
  }) async {
    final apiKey = await KeychainService.loadApiKey() ?? '';
    final model  = await KeychainService.selectedModel;
    final today  = DateTime.now();

    final systemPrompt = '''
You are a homework schedule parser. Extract all assignments, tests, quizzes, and due dates.
Today\'s date is ${today.month}/${today.day}/${today.year}.

Respond ONLY in this exact JSON format:
{
  "items": [
    {
      "title": "Assignment or test name",
      "subject": "Class or subject name",
      "type": "homework|test|quiz|project|reading|other",
      "dueDate": "YYYY-MM-DD",
      "notes": ""
    }
  ]
}

Rules:
- Extract every assignment, test, quiz, reading, and project
- Dates must be YYYY-MM-DD format
- If year not specified, assume current or next upcoming date
- No text outside the JSON object''';

    var userPrompt = 'Please extract all assignments and due dates from this schedule.';
    if (text.isNotEmpty) userPrompt += '\n\nSchedule text:\n$text';

    final contentBlocks = <Map<String, dynamic>>[];

    if (image != null) {
      final bytes  = await image.readAsBytes();
      final base64 = base64Encode(bytes);
      contentBlocks.add({
        'type': 'image',
        'source': {'type': 'base64', 'media_type': 'image/jpeg', 'data': base64},
      });
    }

    contentBlocks.add({'type': 'text', 'text': userPrompt});

    final responseText = await _sendRequest(
      model: model, apiKey: apiKey, maxTokens: 2000,
      systemPrompt: systemPrompt, contentBlocks: contentBlocks,
    );

    final json     = _parseJson(responseText);
    final itemsRaw = json['items'] as List<dynamic>;

    return itemsRaw.map((i) {
      final d      = i as Map<String, dynamic>;
      final dateStr = d['dueDate'] as String;
      final parts  = dateStr.split('-');
      final date   = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      return ParsedScheduleItem(
        title:   d['title'] as String,
        subject: d['subject'] as String,
        type:    ScheduleItemType.fromString(d['type'] as String),
        dueDate: date,
        notes:   d['notes'] as String? ?? '',
      );
    }).toList();
  }

  // ── Generate Study Guide ──────────────────────────────────────────────────
  static Future<StudyGuide> generateStudyGuide({
    required String topic,
    required String subject,
    required ScheduleItemType itemType,
    required DateTime dueDate,
    String notes = '',
  }) async {
    final apiKey  = await KeychainService.loadApiKey() ?? '';
    final model   = await KeychainService.selectedModel;
    final daysLeft = dueDate.difference(DateTime.now()).inDays;
    final dueDateStr = '${dueDate.month}/${dueDate.day}/${dueDate.year}';

    const systemPrompt = '''
You are an expert tutor and study guide creator. Create a comprehensive study guide for a student.

Respond ONLY in this exact JSON format:
{
  "title": "Study Guide title",
  "overview": "2-3 sentence summary of what to focus on",
  "sections": [
    {
      "heading": "Section heading",
      "content": "Detailed explanation, key concepts, formulas, definitions etc.",
      "keyPoints": ["Key point 1", "Key point 2"]
    }
  ],
  "practiceQuestions": [
    {"question": "Practice question text", "answer": "Full answer"}
  ],
  "studyTips": ["Tip 1", "Tip 2", "Tip 3"]
}

Rules:
- Create 3-6 sections covering all major topics
- Include 3-6 practice questions with full answers
- 3-4 study tips specific to this subject/topic
- Tailor depth to the time available before due date
- No text outside the JSON object''';

    final userPrompt =
        'Subject: $subject\nTopic/Assignment: $topic\nType: ${itemType.label}\n'
        'Due Date: $dueDateStr ($daysLeft days away)\n'
        '${notes.isNotEmpty ? "Additional notes: $notes\n" : ""}'
        '\nPlease create a comprehensive study guide.';

    final text = await _sendRequest(
      model: model, apiKey: apiKey, maxTokens: 4000,
      systemPrompt: systemPrompt,
      contentBlocks: [{'type': 'text', 'text': userPrompt}],
    );

    final json = _parseJson(text);
    final sectionsRaw = json['sections'] as List<dynamic>;
    final questionsRaw = json['practiceQuestions'] as List<dynamic>;

    return StudyGuide(
      title:    json['title'] as String,
      overview: json['overview'] as String,
      sections: sectionsRaw.map((s) {
        final d = s as Map<String, dynamic>;
        return StudyGuideSection(
          heading:   d['heading'] as String,
          content:   d['content'] as String,
          keyPoints: (d['keyPoints'] as List<dynamic>?)?.cast<String>() ?? [],
        );
      }).toList(),
      practiceQuestions: questionsRaw.map((q) {
        final d = q as Map<String, dynamic>;
        return PracticeQuestion(question: d['question'] as String, answer: d['answer'] as String);
      }).toList(),
      studyTips: (json['studyTips'] as List<dynamic>).cast<String>(),
    );
  }
  // ── Chat about Goal ───────────────────────────────────────────────────────
  static Future<String> chatAboutGoal({
    required Goal goal,
    required List<dynamic> messages,
    required String userMessage,
  }) async {
    final apiKey = await KeychainService.loadApiKey() ?? '';
    final model  = await KeychainService.selectedModel;

    // Build context string about the goal
    final stepsText = goal.steps.asMap().entries.map((e) =>
        '  \${e.key + 1}. \${e.value.title} [\${e.value.isCompleted ? "✓" : "pending"}] — \${e.value.detail}'
    ).join('\n');

    final systemPrompt = '''
You are a helpful productivity and academic coach built into the GoalKeeper app. You are helping the user with a specific goal. Keep responses concise and actionable — this is a chat interface, not a document. Use short paragraphs. If you use lists, keep them short (3-5 items max).

GOAL CONTEXT:
Title: \${goal.title}
Type: \${goal.type.label}
Description: \${goal.description}
Progress: \${goal.progressPercent}% complete
\${goal.dueDate != null ? "Due: \${goal.dueDate!.month}/\${goal.dueDate!.day}/\${goal.dueDate!.year}" : "No due date"}
\${goal.aiSummary.isNotEmpty ? "Summary: \${goal.aiSummary}" : ""}
\${goal.steps.isEmpty ? "No steps yet." : "Steps:\n\$stepsText"}
\${goal.rubricText.isNotEmpty ? "Rubric: \${goal.rubricText}" : ""}
''';

    // Build conversation history from ChatMessage list
    final conversationMessages = <Map<String, dynamic>>[];
    for (final msg in messages) {
      // msg has .role (ChatRole) and .content (String)
      final roleStr = msg.role.toString().contains('user') ? 'user' : 'assistant';
      conversationMessages.add({'role': roleStr, 'content': msg.content});
    }

    final body = jsonEncode({
      'model': model,
      'max_tokens': 1000,
      'system': systemPrompt,
      'messages': conversationMessages,
    });

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': _apiVersion,
      },
      body: body,
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw AnthropicError('Server error \${response.statusCode}: \${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final responseContent = decoded['content'] as List<dynamic>;
    final text = (responseContent.first as Map<String, dynamic>)['text'] as String?;
    if (text == null) throw AnthropicError('No content returned from AI.');
    return text;
  }

}

// ─── Error type ───────────────────────────────────────────────────────────────

class AnthropicError implements Exception {
  final String message;
  AnthropicError(this.message);
  @override
  String toString() => message;
}
