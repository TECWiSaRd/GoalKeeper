// lib/views/goal_chat_view.dart
// Chat with Claude about a specific goal — Flutter version

import 'package:flutter/material.dart';
import 'package:goalkeeper_flutter/models/models.dart';
import 'package:goalkeeper_flutter/services/anthropic_service.dart';
import 'package:goalkeeper_flutter/theme/app_theme.dart';

// ─── Chat message model ───────────────────────────────────────────────────────

enum ChatRole { user, assistant }

class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  })  : id = DateTime.now().microsecondsSinceEpoch.toString(),
        timestamp = timestamp ?? DateTime.now();
}

// ─── View ─────────────────────────────────────────────────────────────────────

class GoalChatView extends StatefulWidget {
  final Goal goal;
  const GoalChatView({super.key, required this.goal});

  @override
  State<GoalChatView> createState() => _GoalChatViewState();
}

class _GoalChatViewState extends State<GoalChatView> {
  final List<ChatMessage> _messages = [];
  final _controller     = TextEditingController();
  final _scrollCtrl     = ScrollController();
  final _focusNode      = FocusNode();
  bool  _isThinking     = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _header,
        const Divider(height: 1, color: AppColors.divider),
        Expanded(
          child: _messages.isEmpty ? _welcome : _messageList,
        ),
        if (_error != null) _errorBar,
        const Divider(height: 1, color: AppColors.divider),
        _inputBar,
      ],
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget get _header => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          const Icon(Icons.forum_rounded, size: 13, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chat about this goal',
                    style: AppText.body(13, weight: FontWeight.w600)),
                Text(widget.goal.title,
                    style: AppText.body(11, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (_messages.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _messages.clear()),
              child: Text('Clear',
                  style: AppText.body(11, color: AppColors.textTertiary)),
            ),
        ]),
      );

  // ── Welcome / suggestions ──────────────────────────────────────────────────
  Widget get _welcome => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.auto_awesome_rounded,
              size: 32, color: AppColors.accent),
          const SizedBox(height: 12),
          Text(
            'Ask Claude anything about\n"${widget.goal.title}"',
            style: AppText.body(13, weight: FontWeight.w600,
                color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ..._suggestions.map((s) => GestureDetector(
                onTap: () {
                  _controller.text = s;
                  _send();
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.2)),
                  ),
                  child: Text(s,
                      style: AppText.body(12, color: AppColors.accent),
                      textAlign: TextAlign.center),
                ),
              )),
        ],
      );

  List<String> get _suggestions {
    switch (widget.goal.type) {
      case GoalType.assignment || GoalType.examPrep:
        return [
          'How should I approach this?',
          'What are the most important things to focus on?',
          'Can you suggest a study strategy?',
        ];
      case GoalType.project:
        return [
          'What could go wrong with this project?',
          'How do I stay motivated?',
          'What should I prioritize first?',
        ];
      default:
        return [
          'How do I stay on track?',
          "What's the best strategy for this?",
          'Can you break this down further?',
        ];
    }
  }

  // ── Message list ───────────────────────────────────────────────────────────
  Widget get _messageList => ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(14),
        itemCount: _messages.length + (_isThinking ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _messages.length) return _thinkingBubble;
          return _messageBubble(_messages[i]);
        },
      );

  Widget _messageBubble(ChatMessage msg) {
    final isUser = msg.role == ChatRole.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _avatar(isUser: false),
            const SizedBox(width: 8),
          ],
          if (isUser) const Spacer(flex: 2),
          Flexible(
            flex: 5,
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.accent
                        : Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: Radius.circular(isUser ? 14 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 14),
                    ),
                  ),
                  child: SelectableText(
                    msg.content,
                    style: AppText.body(13,
                        color: isUser ? Colors.black : AppColors.textPrimary),
                  ),
                ),
                const SizedBox(height: 3),
                Text(_timeStr(msg.timestamp),
                    style: AppText.body(9, color: AppColors.textTertiary)),
              ],
            ),
          ),
          if (!isUser) const Spacer(flex: 2),
          if (isUser) ...[
            const SizedBox(width: 8),
            _avatar(isUser: true),
          ],
        ],
      ),
    );
  }

  Widget _avatar({required bool isUser}) => Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: isUser
              ? Colors.white.withValues(alpha: 0.1)
              : AppColors.accent.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isUser ? Icons.person_rounded : Icons.auto_awesome_rounded,
          size: 13,
          color: isUser ? AppColors.textSecondary : AppColors.accent,
        ),
      );

  Widget get _thinkingBubble => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(isUser: false),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                  bottomLeft: Radius.circular(4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) => Container(
                  width: 6, height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                )),
              ),
            ),
          ],
        ),
      );

  // ── Error bar ──────────────────────────────────────────────────────────────
  Widget get _errorBar => Container(
        color: AppColors.danger.withValues(alpha: 0.1),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded,
              size: 13, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(child: Text(_error ?? '',
              style: AppText.body(11, color: AppColors.danger))),
          GestureDetector(
            onTap: () => setState(() => _error = null),
            child: const Icon(Icons.close, size: 13, color: AppColors.danger),
          ),
        ]),
      );

  // ── Input bar ──────────────────────────────────────────────────────────────
  Widget get _inputBar => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: AppText.body(13),
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Ask Claude about this goal…',
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.accent),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 9),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isThinking ? null : _send,
            child: Icon(
              Icons.arrow_upward_rounded,
              size: 28,
              color: _isThinking
                  ? AppColors.textDisabled
                  : AppColors.accent,
            ),
          ),
        ]),
      );

  // ── Send ───────────────────────────────────────────────────────────────────
  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || _isThinking) return;
    _controller.clear();

    setState(() {
      _messages.add(ChatMessage(role: ChatRole.user, content: text));
      _isThinking = true;
      _error = null;
    });
    _scrollToBottom();

    AnthropicService.chatAboutGoal(
      goal: widget.goal,
      messages: _messages,
      userMessage: text,
    ).then((response) {
      setState(() {
        _messages.add(ChatMessage(role: ChatRole.assistant, content: response));
        _isThinking = false;
      });
      _scrollToBottom();
    }).catchError((e) {
      setState(() {
        _error = e.toString();
        _isThinking = false;
      });
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _timeStr(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }
}
