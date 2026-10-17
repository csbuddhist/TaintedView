import 'package:flutter/material.dart';

import '../data/models.dart';

/// 多级目录。分组节点可折叠，包含当前章的分组默认展开，当前章高亮。
class TocView extends StatelessWidget {
  const TocView({
    super.key,
    required this.book,
    required this.onSelect,
    this.current,
    this.controller,
    this.shrinkWrap = false,
  });

  final Book book;
  final String? current;
  final ValueChanged<String> onSelect;
  final ScrollController? controller;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    // 目录为空时退回章节清单。
    final nodes = book.toc.isNotEmpty
        ? book.toc
        : [for (final c in book.chapters) TocNode(title: c.title, chapter: c.id)];
    return ListView(
      controller: controller,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      children: [for (final n in nodes) _node(context, n, 0)],
    );
  }

  Widget _node(BuildContext context, TocNode n, int depth) {
    final theme = Theme.of(context);
    final selected = n.chapter != null && n.chapter == current;
    final pad = EdgeInsets.only(left: 16.0 + depth * 16, right: 16);
    if (n.children.isEmpty) {
      return ListTile(
        dense: true,
        contentPadding: pad,
        selected: selected,
        selectedTileColor: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
        title: Text(n.title),
        onTap: n.chapter == null ? null : () => onSelect(n.chapter!),
      );
    }
    return ExpansionTile(
      tilePadding: pad,
      dense: true,
      initiallyExpanded: current != null && n.contains(current!),
      title: GestureDetector(
        onTap: n.chapter == null ? null : () => onSelect(n.chapter!),
        child: Text(
          n.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? theme.colorScheme.primary : null,
          ),
        ),
      ),
      children: [for (final c in n.children) _node(context, c, depth + 1)],
    );
  }
}
