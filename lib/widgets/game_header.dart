import 'package:flutter/material.dart';

/// ============================================================================
/// GameHeader
/// ----------------------------------------------------------------------------
/// A reusable header widget for game screens.
///
/// Features:
/// - Customizable title (announced to screen readers as a heading)
/// - Optional subtitle (e.g., Level / World); an empty string is treated as
///   "no subtitle"
/// - Optional actions (icons/buttons)
/// - Consistent padding & styling
/// - Long titles and subtitles wrap instead of overflowing
///
/// Usage:
/// GameHeader(
///   title: "Sudoku",
///   subtitle: "World 1 • Level 5",
///   actions: [IconButton(...)]
/// )
/// ============================================================================

class GameHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  const GameHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
  });

  static final Color _subtitleColor = Colors.grey.shade600;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final String? subtitleText = subtitle;
    final List<Widget>? actionWidgets = actions;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // ================= TITLE + SUBTITLE =================
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // TITLE
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // SUBTITLE (optional)
                if (subtitleText != null && subtitleText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitleText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _subtitleColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ================= ACTIONS =================
          if (actionWidgets != null) ...actionWidgets,
        ],
      ),
    );
  }
}