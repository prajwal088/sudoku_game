import 'package:flutter/material.dart';

/// ============================================================================
/// GameHeader
/// ----------------------------------------------------------------------------
/// A reusable header widget for game screens.
///
/// Features:
/// - Customizable title
/// - Optional subtitle (e.g., Level / World)
/// - Optional actions (icons/buttons)
/// - Consistent padding & styling
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          /// ================= TITLE + SUBTITLE =================
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// TITLE
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                /// SUBTITLE (optional)
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          /// ================= ACTIONS =================
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}