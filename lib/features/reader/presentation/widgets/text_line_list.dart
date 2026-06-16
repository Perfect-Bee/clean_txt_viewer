import 'package:flutter/material.dart';

class TextLineList extends StatelessWidget {
  const TextLineList({
    super.key,
    required this.lines,
    required this.fontSize,
    required this.selectable,
    required this.scrollController,
  });

  final List<String> lines;
  final double fontSize;
  final bool selectable;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'monospace',
      fontSize: fontSize,
      height: 1.35,
    );

    return Scrollbar(
      controller: scrollController,
      thumbVisibility: true,
      interactive: true,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final line = lines[index].isEmpty ? ' ' : lines[index];

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: selectable
                ? SelectableText(
                    line,
                    style: style,
                  )
                : Text(
                    line,
                    style: style,
                    softWrap: true,
                  ),
          );
        },
      ),
    );
  }
}