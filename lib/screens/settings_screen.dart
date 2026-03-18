import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/user_service.dart';
import '../widgets/settings_tile.dart'; // ✅ NEW IMPORT

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  final UserService userService = UserService();

  String userName = "";
  String userId = "";
  String appVersion = "";

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadUser();
    loadAppVersion();
  }

  /// LOAD VERSION
  Future<void> loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();

    if (!mounted) return;

    setState(() {
      appVersion = "${info.version} (${info.buildNumber})";
    });
  }

  /// LOAD USER
  Future<void> loadUser() async {
    final name =  userService.getUserName();
    final id = userService.getUserId();

    if (!mounted) return;

    setState(() {
      userName = name ?? "";
      userId = id;
      isLoading = false;
    });

    if (!mounted) return;

    if (name == null || name.isEmpty) {
      Future.microtask(() => promptName()); // ✅ SAFE CALL
    }
  }

  /// NAME INPUT
 void promptName() {
  final controller = TextEditingController(text: userName);
  String? errorText;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) { // 👈 renamed (important clarity)
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

                  if (name.length < 3) {
                    setStateDialog(() {
                      errorText = "Minimum 3 characters required";
                    });
                    return;
                  }

                  final valid = RegExp(r'^[a-zA-Z0-9]+$').hasMatch(name);
                  if (!valid) {
                    setStateDialog(() {
                      errorText = "Only letters & numbers allowed";
                    });
                    return;
                  }

                  final navigator = Navigator.of(dialogContext); // ✅ CAPTURE BEFORE AWAIT

                  await userService.saveUserName(name);

                  if (!mounted) return;

                  setState(() {
                    userName = name;
                  });

                  navigator.pop(); // ✅ SAFE (NO WARNING)
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

  /// OPEN LINKS
Future<void> openLink(String url) async {
  final uri = Uri.parse(url);

  final success = await launchUrl(uri);

  if (!success) {
    if (!mounted) return; // ✅ CRITICAL FIX

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Could not open link"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

  /// RESET CONFIRMATION
  void showResetDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Reset Data"),
        content: const Text("This will erase all progress."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement reset logic
              Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {

    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),

        body: Column(
          children: [

            /// 🔼 SCROLLABLE CONTENT
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [

                  /// 👤 PROFILE
                  SettingsTile(
                    icon: Icons.person,
                    title: userName.isEmpty ? "Set your name" : userName,
                    subtitle: "Tap to edit",
                    trailing: const Icon(Icons.edit),
                    onTap: promptName,
                  ),

                  /// 🆔 USER ID
                  SettingsTile(
                    icon: Icons.fingerprint,
                    title: "User ID",
                    subtitle: userId,
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        final messenger = ScaffoldMessenger.of(context);

                        Clipboard.setData(ClipboardData(text: userId));

                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text("User ID copied"),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),

                  /// 🧹 RESET
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

            /// 🔽 FIXED FOOTER (SAFE)
            SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: const Border(
                    top: BorderSide(color: Colors.grey, width: 0.2),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    /// 🌐 SOCIAL ICONS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.public),
                          onPressed: () => openLink("https://your-social-link.com"),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.share),
                          onPressed: () {
                            // TODO: Share feature
                          },
                        ),
                      ],
                    ),

                    /// ℹ️ VERSION
                    Text(
                      appVersion.isEmpty ? "Loading..." : "Version $appVersion",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 6),

                    /// 📄 LINKS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: () => openLink("https://your-privacy-url.com"),
                          child: const Text(
                            "Privacy Policy",
                            style: TextStyle(
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const Text("  •  "),
                        InkWell(
                          onTap: () => openLink("https://your-terms-url.com"),
                          child: const Text(
                            "Terms & Conditions",
                            style: TextStyle(
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ],
        ),
       );
  }
}