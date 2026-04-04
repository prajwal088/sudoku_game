import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/user_service.dart';
import '../services/progress_service.dart';
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

  String userName = "";
  String userId = "";
  String appVersion = "";

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
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
    final controller = TextEditingController(text: userName);
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
                controller: controller,
                decoration: InputDecoration(
                  hintText: "Your Name",
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    final name = controller.text.trim();

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

                    final navigator = Navigator.of(dialogContext);

                    await userService.saveUserName(name);

                    if (!mounted) return;

                    setState(() {
                      userName = name;
                    });

                    controller.dispose(); // ✅ prevent leak
                    navigator.pop();
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
  Future<void> openLink(String url) async {
    try {
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
      appBar: AppBar(title: const Text("Settings")),
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
                  subtitle: "Tap to edit",
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
                      Clipboard.setData(
                          ClipboardData(text: userId));

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("User ID copied"),
                        ),
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
                          openLink("https://your-site.com"),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: () {
                        // TODO: Implement share
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
                          openLink("https://privacy.com"),
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
                          openLink("https://terms.com"),
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
}