// lib/views/goal_detail_view.dart
// Right column goal detail — steps, rings, AI summary, re-analyze

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:goalkeeper_flutter/store/goal_store.dart';
import 'package:goalkeeper_flutter/models/models.dart';
import 'package:goalkeeper_flutter/services/anthropic_service.dart';
import 'package:goalkeeper_flutter/theme/app_theme.dart';
import 'package:goalkeeper_flutter/widgets/progress_ring.dart';
import 'package:goalkeeper_flutter/views/goal_chat_view.dart';

class GoalDetailView extends StatefulWidget {
  final Goal goal;
  const GoalDetailView({super.key, required this.goal});

  @override
  State<GoalDetailView> createState() => _GoalDetailViewState();
}

class _GoalDetailViewState extends State<GoalDetailView> {
  final Set<String> _expandedSteps = {};
  bool _showChat = false;
  bool _isReanalyzing = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<GoalStore>();
    // Always use the live goal from store so steps update immediately
    final goal = store.goals.firstWhere(
      (g) => g.id == widget.goal.id,
      orElse: () => widget.goal,
    );

    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // Toolbar
          _toolbar(goal, store),
          // Tab bar
          _tabBar,
          Expanded(
            child: _showChat
                ? GoalChatView(goal: goal)
                : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _heroCard(goal),
                const SizedBox(height: 16),
                if (goal.aiSummary.isNotEmpty) ...[
                  _summaryCard(goal),
                  const SizedBox(height: 16),
                ],
                _stepsSection(goal, store),
                const SizedBox(height: 16),
                _metaCard(goal),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab bar ────────────────────────────────────────────────────────────────
  Widget get _tabBar => Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(children: [
          _tabItem('Action Plan', Icons.list_alt_rounded, false),
          _tabItem('Chat with Claude', Icons.forum_rounded, true),
        ]),
      );

  Widget _tabItem(String label, IconData icon, bool isChat) {
    final active = _showChat == isChat;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _showChat = isChat),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 12,
                  color: active ? AppColors.accent : AppColors.textSecondary),
              const SizedBox(width: 5),
              Text(label,
                  style: AppText.body(12,
                      weight: active ? FontWeight.w600 : FontWeight.w400,
                      color: active ? AppColors.accent : AppColors.textSecondary)),
            ]),
          ),
          Container(height: 2,
              color: active ? AppColors.accent : Colors.transparent),
        ]),
      ),
    );
  }

  // ── Toolbar ────────────────────────────────────────────────────────────────
  Widget _toolbar(Goal goal, GoalStore store) => Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.sidebarBg,
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            Icon(goal.type.icon, size: 13, color: goal.type.color),
            const SizedBox(width: 6),
            Text(goal.type.label.toUpperCase(),
                style: AppText.label(10, color: goal.type.color)),
            const Spacer(),
            if (_error != null)
              Text(_error!,
                  style: AppText.body(11, color: AppColors.danger)),
            // Re-analyze
            IconButton(
              icon: _isReanalyzing
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: AppColors.accent))
                  : const Icon(Icons.auto_awesome_rounded,
                      size: 16, color: AppColors.accent),
              tooltip: 'Re-analyze with Claude',
              onPressed: _isReanalyzing ? null : () => _reanalyze(goal, store),
            ),
            // Delete
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 16, color: AppColors.danger),
              tooltip: 'Delete goal',
              onPressed: () => _confirmDelete(goal, store),
            ),
          ],
        ),
      );

  // ── Hero card ──────────────────────────────────────────────────────────────
  Widget _heroCard(Goal goal) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ActivityRingsView(goal: goal, size: 110),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(goal.title,
                      style: AppText.display(20, weight: FontWeight.w700)),
                  if (goal.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(goal.description,
                        style: AppText.body(12, color: AppColors.textSecondary),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      _chip('${goal.progressPercent}% done', goal.type.color),
                      _chip(
                          '${goal.steps.where((s) => s.isCompleted).length}/'
                          '${goal.steps.length} steps',
                          Colors.white.withOpacity(0.6)),
                      if (goal.daysUntilDue != null)
                        _chip(
                          goal.daysUntilDue! < 0
                              ? '⚠ Overdue ${-goal.daysUntilDue!}d'
                              : '${goal.daysUntilDue}d left',
                          goal.daysUntilDue! < 0 ? AppColors.danger : AppColors.warning,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: AppText.body(11, weight: FontWeight.w600, color: color)),
      );

  // ── AI Summary card ────────────────────────────────────────────────────────
  Widget _summaryCard(Goal goal) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.accent.withOpacity(0.06),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.accent.withOpacity(0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    size: 12, color: AppColors.accent),
                const SizedBox(width: 6),
                Text("Claude's Analysis",
                    style: AppText.body(12,
                        weight: FontWeight.w700, color: AppColors.accent)),
              ],
            ),
            const SizedBox(height: 8),
            Text(goal.aiSummary,
                style: AppText.body(12, color: AppColors.textSecondary),
                textHeightBehavior: const TextHeightBehavior()),
          ],
        ),
      );

  // ── Steps section ──────────────────────────────────────────────────────────
  Widget _stepsSection(Goal goal, GoalStore store) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Action Plan',
                  style: AppText.display(15, weight: FontWeight.w700)),
              const Spacer(),
              Text(
                '${goal.steps.where((s) => s.isCompleted).length} of '
                '${goal.steps.length} completed',
                style: AppText.body(11, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (goal.steps.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Column(
                  children: [
                    const Icon(Icons.list_alt_rounded,
                        size: 28, color: AppColors.textDisabled),
                    const SizedBox(height: 8),
                    Text('Click ✦ in the toolbar to analyze with Claude',
                        style: AppText.body(12, color: AppColors.textDisabled)),
                  ],
                ),
              ),
            )
          else
            ...goal.steps.asMap().entries.map((e) =>
                _stepRow(e.value, e.key, goal, store)),
        ],
      );

  Widget _stepRow(GoalStep step, int index, Goal goal, GoalStore store) {
    final isCurrent = !step.isCompleted &&
        goal.steps.take(index).every((s) => s.isCompleted);
    final isExpanded = _expandedSteps.contains(step.id);

    return GestureDetector(
      onTap: () => setState(() {
        if (isExpanded) _expandedSteps.remove(step.id);
        else _expandedSteps.add(step.id);
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: isCurrent
              ? goal.type.color.withOpacity(0.06)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCurrent
                ? goal.type.color.withOpacity(0.25)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Checkbox
                  GestureDetector(
                    onTap: () => store.toggleStep(goal.id, step.id),
                    child: Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: step.isCompleted ? goal.type.color : Colors.transparent,
                        border: Border.all(
                          color: step.isCompleted
                              ? goal.type.color
                              : Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: step.isCompleted
                          ? const Icon(Icons.check, size: 12, color: Colors.black)
                          : Center(
                              child: Text('${index + 1}',
                                  style: AppText.body(10,
                                      weight: FontWeight.w700,
                                      color: isCurrent
                                          ? goal.type.color
                                          : AppColors.textTertiary)),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(step.title,
                            style: AppText.body(13,
                                weight: FontWeight.w600,
                                color: step.isCompleted
                                    ? AppColors.textTertiary
                                    : AppColors.textPrimary)),
                        Text(step.estimatedTime,
                            style: AppText.body(10, color: AppColors.textTertiary)),
                      ],
                    ),
                  ),
                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: goal.type.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('NOW',
                          style: AppText.body(8,
                              weight: FontWeight.w700, color: goal.type.color)),
                    ),
                  const SizedBox(width: 6),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 14, color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
            if (isExpanded) ...[
              const Divider(height: 1, color: AppColors.divider),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(step.detail,
                        style: AppText.body(12, color: AppColors.textSecondary)),
                    if (step.tips.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('TIPS', style: AppText.label(9)),
                      const SizedBox(height: 6),
                      ...step.tips.map((tip) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.lightbulb_outline_rounded,
                                    size: 11, color: AppColors.personalGoal),
                                const SizedBox(width: 6),
                                Expanded(
                                    child: Text(tip,
                                        style: AppText.body(11,
                                            color: AppColors.textSecondary))),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Meta card ──────────────────────────────────────────────────────────────
  Widget _metaCard(Goal goal) => Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          children: [
            _metaRow('Type', goal.type.label, goal.type.color),
            const Divider(height: 1, indent: 12, endIndent: 12, color: AppColors.divider),
            _metaRow('Priority', goal.priority.label, goal.priority.color),
            const Divider(height: 1, indent: 12, endIndent: 12, color: AppColors.divider),
            _metaRow('Created', _fmt(goal.createdDate), AppColors.textPrimary),
            if (goal.dueDate != null) ...[
              const Divider(height: 1, indent: 12, endIndent: 12, color: AppColors.divider),
              _metaRow('Due', _fmt(goal.dueDate!),
                  goal.isOverdue ? AppColors.danger : AppColors.warning),
            ],
          ],
        ),
      );

  Widget _metaRow(String label, String value, Color valueColor) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Text(label, style: AppText.body(12, color: AppColors.textSecondary)),
            const Spacer(),
            Text(value,
                style: AppText.body(12, weight: FontWeight.w600, color: valueColor)),
          ],
        ),
      );

  String _fmt(DateTime d) => '${d.month}/${d.day}/${d.year}';

  // ── Re-analyze ─────────────────────────────────────────────────────────────
  Future<void> _reanalyze(Goal goal, GoalStore store) async {
    setState(() { _isReanalyzing = true; _error = null; });
    try {
      final result = await AnthropicService.analyzeGoal(
        title: goal.title,
        description: goal.description,
        type: goal.type,
        dueDate: goal.dueDate,
        rubric: goal.rubricText,
      );
      final updated = goal.copyWith(
        aiSummary: result.summary,
        isAnalyzed: true,
        currentStepIndex: 0,
        steps: result.steps.map((s) => GoalStep(
          title: s.title, detail: s.detail,
          estimatedTime: s.estimatedTime, tips: s.tips,
        )).toList(),
      );
      store.updateGoal(updated);
    } catch (e) {
      setState(() => _error = e.toString());
    }
    setState(() => _isReanalyzing = false);
  }

  // ── Delete ─────────────────────────────────────────────────────────────────
  void _confirmDelete(Goal goal, GoalStore store) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.sidebarBg,
        title: Text('Delete Goal', style: AppText.display(16)),
        content: Text(
          'Permanently delete "${goal.title}" and all its steps?',
          style: AppText.body(13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              store.deleteGoal(goal.id);
            },
            child: Text('Delete',
                style: AppText.body(13, color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}
