import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sudoku_game/l10n/app_localizations.dart';

import '../services/user_service.dart';
import '../services/progress_service.dart';
import '../services/analytics_service.dart';
import '../widgets/settings_tile.dart';

/// ============================================================================
/// SettingsScreen
/// ----------------------------------------------------------------------------
/// Handles:
/// - User profile (name, ID)
/// - App info (version)
/// - External links
/// - Reset functionality
///
/// Production Features:
/// - Safe async handling
/// - Proper validation
/// - Memory-safe dialog usage
/// ============================================================================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final UserService userService = UserService();
  final ProgressService progressService = ProgressService();
  late TextEditingController _nameController;

  String userName = "";
  String userId = "";
  String appVersion = "";

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logEvent(name: 'settings_view'); // Track view
    _nameController = TextEditingController();
    _initialize();
  }

  /// ==========================================================================
  /// INITIAL LOAD
  /// ==========================================================================
  Future<void> _initialize() async {
    await Future.wait([
      loadUser(),
      loadAppVersion(),
    ]);

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  /// ==========================================================================
  /// LOAD APP VERSION (SAFE)
  /// ==========================================================================
  Future<void> loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();

      if (!mounted) return;

      setState(() {
        appVersion = "${info.version} (${info.buildNumber})";
      });
    } catch (e) {
      appVersion = "Unknown";
    }
  }

  /// ==========================================================================
  /// LOAD USER DATA
  /// ==========================================================================
  Future<void> loadUser() async {
    try {
      final name = userService.getUserName();
      final id = userService.getUserId();

      if (!mounted) return;

      setState(() {
        userName = name ?? "";
        userId = id;
      });

      /// Prompt name if not set
      if (name == null || name.isEmpty) {
        Future.microtask(() => _promptName());
      }
    } catch (e) {
      debugPrint("User load error: $e");
    }
  }

  /// ==========================================================================
  /// NAME INPUT DIALOG (SAFE + VALIDATED)
  /// ==========================================================================
  void _promptName() {
    // 1. Set the class-level controller text before showing the dialog
    _nameController.text = userName;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (_, setStateDialog) {
            return AlertDialog(
              title: const Text("Enter your name"),
              content: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: "Your Name",
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    final name = _nameController.text.trim();

                    /// Validation
                    if (name.length < 3) {
                      setStateDialog(() {
                        errorText = "Minimum 3 characters required";
                      });
                      return;
                    }

                    /// Allow spaces (better UX)
                    final valid =
                        RegExp(r'^[a-zA-Z0-9 ]+$').hasMatch(name);

                    if (!valid) {
                      setStateDialog(() {
                        errorText =
                            "Only letters, numbers & spaces allowed";
                      });
                      return;
                    }

                    await userService.saveUserName(name);

                    // Track: Name update success
                    AnalyticsService.logEvent(name: 'user_update_name');

                    if (!dialogContext.mounted) return;

                    setState(() {
                      userName = name;
                    });

                    // Navigator.pop handles the cleanup of the dialog tree.
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text("Save"),
                )
              ],
            );
          },
        );
      },
    );
  }

  /// ==========================================================================
  /// OPEN EXTERNAL LINK (SAFE)
  /// ==========================================================================
  Future<void> openLink(String url, String linkName) async {
    try {

      // Track: External link navigation
      AnalyticsService.logEvent(
        name: 'settings_link_click',
        parameters: {'link_target': linkName},
      );

      final uri = Uri.parse(url);

      final success = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not open link"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("URL launch error: $e");
    }
  }

  /// ==========================================================================
  /// RESET DATA
  /// ==========================================================================
  void showResetDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Reset Data"),
        content: const Text(
          "This will erase all progress permanently.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await progressService.resetProgress();

              // Track: Critical user action
              AnalyticsService.logEvent(name: 'user_reset_all_progress');

              if (!mounted) return;

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Progress reset successfully"),
                ),
              );
            },
            child: const Text(
              "Reset",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  /// ==========================================================================
  /// UI
  /// ==========================================================================
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.settingsButton)),
      body: Column(
        children: [
          /// ================= SCROLLABLE CONTENT =================
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                /// PROFILE
                SettingsTile(
                  icon: Icons.person,
                  title:
                      userName.isEmpty ? "Set your name" : userName,
                  subtitle: AppLocalizations.of(context)!.editNameButton,
                  trailing: const Icon(Icons.edit),
                  onTap: _promptName,
                ),

                /// USER ID
                SettingsTile(
                  icon: Icons.fingerprint,
                  title: "User ID",
                  subtitle: userId,
                  trailing: IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: userId));
                      AnalyticsService.logEvent(name: 'user_copy_id');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("User ID copied")),
                      );
                    },
                  ),
                ),

                /// RESET
                SettingsTile(
                  icon: Icons.delete,
                  title: "Reset Data",
                  isDanger: true,
                  onTap: showResetDialog,
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),

          /// ================= FOOTER =================
          SafeArea(
            top: false,
            child: Column(
              children: [
                /// SOCIAL
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.public),
                      onPressed: () =>
                          openLink("https://your-site.com", "public website"),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: () {
                        // Track the event
                        AnalyticsService.logEvent(name: 'settings_share_app');

                        // Define the message (usually includes a link to Play Store/App Store)
                        const String message = 
                            "Check out this awesome app! Download it here: https://prajwal088.github.io/sudoku-app-docs/share-sudoku-app";

                        // Trigger the native share sheet
                        Share.share(message, subject: 'Check out this App!');
                      },
                    ),
                  ],
                ),

                /// VERSION
                Text(
                  appVersion.isEmpty
                      ? "Loading..."
                      : "Version $appVersion",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),

                const SizedBox(height: 6),

                /// LINKS
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: () =>
                          openLink("https://prajwal088.github.io/sudoku-app-docs/privacy-policy", AppLocalizations.of(context)!.privacyPolicy),
                      child: const Text(
                        "Privacy Policy",
                        style: TextStyle(
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const Text(" • "),
                    InkWell(
                      onTap: () =>
                          openLink("https://prajwal088.github.io/sudoku-app-docs/terms-and-conditions", AppLocalizations.of(context)!.termsConditions),
                      child: const Text(
                        "Terms & Conditions",
                        style: TextStyle(
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
  @override
  void dispose() {
    _nameController.dispose(); // ✅ Properly dispose when the screen is destroyed
    super.dispose();
  }
}