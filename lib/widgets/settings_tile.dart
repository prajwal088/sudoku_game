import 'package:flutter/material.dart';

/// ============================================================================
/// SettingsTile
/// ----------------------------------------------------------------------------
/// Reusable settings item widget
///
/// Features:
/// - Icon + Title + Optional Subtitle
/// - Optional trailing widget (e.g., arrow, switch, copy button)
/// - Tap interaction
/// - Danger mode (for destructive actions like Reset)
///
/// Design Goals:
/// - Clean Material UI
/// - Consistent spacing
/// - Good accessibility
/// - Lightweight & reusable
/// - Safe with any theme (no null-assertions on theme colors)
/// ============================================================================

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDanger;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isDanger = false,
  });

  // ==========================================================================
  // SHARED VALUES
  // ==========================================================================

  static const BorderRadius _radius = BorderRadius.all(Radius.circular(16));

  static final TextStyle _subtitleStyle = TextStyle(
    fontSize: 13,
    color: Colors.grey.shade600,
  );

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    // Theme colors can legitimately be null (for example in a custom
    // TextTheme or IconTheme), so the old `!` assertions could crash.
    // Fall back to the color scheme instead.
    final Color textColor = isDanger
        ? Colors.red
        : (theme.textTheme.bodyLarge?.color ?? theme.colorScheme.onSurface);

    final Color iconColor = isDanger
        ? Colors.red
        : (theme.iconTheme.color ?? theme.colorScheme.onSurface);

    final String? subtitleText = subtitle;
    final Widget? trailingWidget = trailing;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2, // lighter shadow for modern UI
      shape: const RoundedRectangleBorder(borderRadius: _radius),
      child: InkWell(
        borderRadius: _radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: <Widget>[
              // ================= ICON =================
              Icon(icon, color: iconColor),

              const SizedBox(width: 16),

              // ================= TEXT CONTENT =================
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // TITLE
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),

                    // SUBTITLE (optional)
                    if (subtitleText != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        subtitleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _subtitleStyle,
                      ),
                    ],
                  ],
                ),
              ),

              // ================= TRAILING =================
              if (trailingWidget != null) ...<Widget>[
                // Keeps long text from touching the trailing widget.
                const SizedBox(width: 8),
                trailingWidget,
              ],
            ],
          ),
        ),
      ),
    );
  }
}