import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final String? time;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: (MediaQuery.of(context).size.width * (isUser ? 0.72 : 0.85)).clamp(220.0, 600.0),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? AppColors.userBubble : AppColors.aiBubble,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.smart_toy_rounded,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text('NutriFy AI',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
              ),
            _buildParsedMessage(
              message,
              isUser ? AppTextStyles.chatUser : AppTextStyles.chatAi,
            ),
            if (time != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  time!,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isUser ? Colors.white60 : AppColors.textLight,
                    fontSize: 9,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Table helper: check if line is a table row
  bool isTableLine(String line) {
    final trimmed = line.trim();
    return trimmed.startsWith('|') && trimmed.endsWith('|');
  }

  // Table helper: check if line is a table divider/separator row
  bool isTableSeparator(String line) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('|') || !trimmed.endsWith('|')) return false;
    final inner = trimmed.substring(1, trimmed.length - 1);
    return inner.split('|').every((cell) {
      final c = cell.trim();
      return c.isEmpty || RegExp(r'^:?-+:?$').hasMatch(c);
    });
  }

  // Table helper: split table row into separate cells
  List<String> parseCells(String line) {
    String content = line.trim();
    if (content.startsWith('|')) {
      content = content.substring(1);
    }
    if (content.endsWith('|')) {
      content = content.substring(0, content.length - 1);
    }
    return content.split('|').map((cell) => cell.trim()).toList();
  }

  // Table renderer: builds a beautiful, minimal and horizontally scrollable table
  Widget _buildTableWidget(List<String> tableLines, TextStyle baseStyle) {
    final cleanRows = tableLines.where((l) => !isTableSeparator(l)).toList();
    if (cleanRows.isEmpty) return const SizedBox();

    final headerCells = parseCells(cleanRows[0]);
    final List<List<String>> dataRows = [];
    for (int i = 1; i < cleanRows.length; i++) {
      dataRows.add(parseCells(cleanRows[i]));
    }

    int numCols = headerCells.length;
    for (var row in dataRows) {
      if (row.length > numCols) {
        numCols = row.length;
      }
    }

    while (headerCells.length < numCols) {
      headerCells.add('');
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: AppColors.divider.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              children: [
                // Header Row
                TableRow(
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceVariant,
                  ),
                  children: headerCells.map((cellText) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          cellText,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                // Data Rows
                ...dataRows.map((rowCells) {
                  final cells = List<String>.from(rowCells);
                  while (cells.length < numCols) {
                    cells.add('');
                  }
                  return TableRow(
                    children: cells.map((cellText) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: RichText(
                            text: TextSpan(
                              style: baseStyle.copyWith(
                                fontSize: 12,
                                color: AppColors.textPrimary,
                              ),
                              children: _parseInlineSpans(
                                cellText,
                                baseStyle.copyWith(fontSize: 12, color: AppColors.textPrimary),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Heading renderer: renders modern titles with colored accent vertical strips
  Widget _buildHeadingWidget(int level, String text, TextStyle baseStyle) {
    TextStyle headingStyle;
    double bottomPadding = 4;
    double topPadding = 12;

    switch (level) {
      case 1:
        headingStyle = AppTextStyles.heading2.copyWith(
          color: AppColors.primaryDark,
          fontSize: 18,
        );
        bottomPadding = 6;
        break;
      case 2:
        headingStyle = AppTextStyles.heading3.copyWith(
          color: AppColors.primary,
          fontSize: 16,
        );
        bottomPadding = 4;
        break;
      case 3:
      default:
        headingStyle = AppTextStyles.labelLarge.copyWith(
          color: AppColors.primary,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        );
        bottomPadding = 2;
        break;
    }

    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (level <= 2)
                Container(
                  width: 3.5,
                  height: level == 1 ? 18 : 14,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: level == 1 ? AppColors.primary : AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              Flexible(
                child: Text(
                  text,
                  style: headingStyle,
                ),
              ),
            ],
          ),
          if (level == 1)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 40,
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildParsedMessage(String message, TextStyle baseStyle) {
    if (message.trim().isEmpty) {
      return const SizedBox();
    }

    final List<String> lines = message.split('\n');
    final List<Widget> children = [];

    int i = 0;
    while (i < lines.length) {
      final line = lines[i];

      // Check if it's a table line
      if (isTableLine(line)) {
        final List<String> tableLines = [];
        while (i < lines.length && isTableLine(lines[i])) {
          tableLines.add(lines[i]);
          i++;
        }
        children.add(_buildTableWidget(tableLines, baseStyle));
        continue;
      }

      // Check if it's a heading
      final headingMatch = RegExp(r'^(\s*)(#{1,3})\s+(.*)$').firstMatch(line);
      if (headingMatch != null) {
        final level = headingMatch.group(2)!.length;
        final title = headingMatch.group(3)!.trim();
        children.add(_buildHeadingWidget(level, title, baseStyle));
        i++;
        continue;
      }

      // Check if it's a bullet item starting with '-', '*', or '•'
      final bulletMatch = RegExp(r'^(\s*)[-\*•]\s*(.*)$').firstMatch(line);
      if (bulletMatch != null && !RegExp(r'^(\s*)-{3,}\s*$').hasMatch(line)) {
        final indent = bulletMatch.group(1) ?? '';
        final content = bulletMatch.group(2) ?? '';
        final indentWidth = indent.length * 8.0;

        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4, top: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (indentWidth > 0) SizedBox(width: indentWidth),
                Text(
                  '• ',
                  style: baseStyle.copyWith(
                    color: isUser ? Colors.white70 : AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: baseStyle,
                      children: _parseInlineSpans(content, baseStyle),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        i++;
        continue;
      }

      // Check if it's a horizontal divider (hr)
      if (RegExp(r'^(\s*)-{3,}\s*$').hasMatch(line)) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(
              color: isUser ? Colors.white30 : AppColors.divider,
              thickness: 1,
            ),
          ),
        );
        i++;
        continue;
      }

      // Check for empty lines
      if (line.trim().isEmpty) {
        if (i < lines.length - 1) {
          children.add(const SizedBox(height: 8));
        }
        i++;
        continue;
      }

      // Normal paragraph/line
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: RichText(
            text: TextSpan(
              style: baseStyle,
              children: _parseInlineSpans(line, baseStyle),
            ),
          ),
        ),
      );
      i++;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  List<InlineSpan> _parseInlineSpans(String text, TextStyle baseStyle) {
    final List<InlineSpan> spans = [];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int start = 0;

    for (final match in regex.allMatches(text)) {
      // Add text before the bold tag
      if (match.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: baseStyle,
        ));
      }

      // Add the bold tag content
      final boldText = match.group(1) ?? '';
      final double baseSize = baseStyle.fontSize ?? 14.0;
      spans.add(TextSpan(
        text: boldText,
        style: baseStyle.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: baseSize * 1.05, // Slightly larger bold text for premium readable emphasis
        ),
      ));

      start = match.end;
    }

    // Add remaining trailing text without injecting the incorrect newline span
    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: baseStyle,
      ));
    }

    return spans;
  }
}
