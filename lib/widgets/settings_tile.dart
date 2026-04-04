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

  @override
  Widget build(BuildContext context) {
    /// Resolve colors based on state
    final Color textColor =
        isDanger ? Colors.red : Theme.of(context).textTheme.bodyLarge!.color!;

    final Color iconColor =
        isDanger ? Colors.red : Theme.of(context).iconTheme.color!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2, // lighter shadow for modern UI
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Row(
            children: [
              /// ================= ICON =================
              Icon(
                icon,
                color: iconColor,
              ),

              const SizedBox(width: 16),

              /// ================= TEXT CONTENT =================
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// TITLE
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),

                    /// SUBTITLE (optional)
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              /// ================= TRAILING =================
              if (trailing != null) ...[
                trailing!,
              ],            
            ],
          ),
        ),
      ),
    );
  }
}