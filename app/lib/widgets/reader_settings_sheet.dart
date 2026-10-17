import 'package:flutter/material.dart';

import '../data/prefs.dart';

Future<void> showReaderSettings(BuildContext context, ReaderSettings settings) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListenableBuilder(
        listenable: settings,
        builder: (context, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<ReaderTheme>(
                  showSelectedIcon: false,
                  segments: [
                    for (final t in ReaderTheme.values) ButtonSegment(value: t, label: Text(t.label)),
                  ],
                  selected: {settings.theme},
                  onSelectionChanged: (s) => settings.theme = s.first,
                ),
                const SizedBox(height: 8),
                _SliderRow(
                  label: '字号',
                  value: settings.fontSize,
                  min: 14,
                  max: 30,
                  divisions: 16,
                  display: settings.fontSize.toStringAsFixed(0),
                  onChanged: (v) => settings.fontSize = v,
                ),
                _SliderRow(
                  label: '行距',
                  value: settings.lineHeight,
                  min: 1.3,
                  max: 2.5,
                  divisions: 12,
                  display: settings.lineHeight.toStringAsFixed(1),
                  onChanged: (v) => settings.lineHeight = v,
                ),
                _SliderRow(
                  label: '段距',
                  value: settings.paragraphGap,
                  min: 0,
                  max: 32,
                  divisions: 16,
                  display: settings.paragraphGap.toStringAsFixed(0),
                  onChanged: (v) => settings.paragraphGap = v,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('首行缩进'),
                  value: settings.indent,
                  onChanged: (v) => settings.indent = v,
                ),
              ],
            ),
          ),
        ),
      ),
    );

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(width: 40, child: Text(label)),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          SizedBox(width: 36, child: Text(display, textAlign: TextAlign.end)),
        ],
      );
}
