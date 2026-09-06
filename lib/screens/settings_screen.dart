import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/progress_service.dart';
import '../services/user_service.dart';
import '../widgets/settings_tile.dart';

/// ============================================================================
/// SettingsScreen
/// ----------------------------------------------------------------------------
/// Handles:
/// - User profile (name, ID)
/// - App information (version)
/// - External links
/// - Copy user ID
/// - Reset progress
///
/// Notes:
/// - Existing UserService API is preserved.
/// - Existing ProgressService API is preserved.
/// - Existing SettingsTile API is preserved.
/// - Async operations are guarded with mounted checks.
/// - Dialog actions prevent duplicate operations.
/// - User input is validated without restricting legitimate Unicode names.
/// ============================================================================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ==========================================================================
  // SERVICES
  // ==========================================================================

  final UserService userService = UserService();
  final ProgressService progressService = ProgressService();

  // ==========================================================================
  // APP LINKS
  // ==========================================================================
  //
  // IMPORTANT:
  // Replace these placeholder URLs with your real production URLs.
  //
  // If these URLs are used by multiple files, move them to a shared file such
  // as:
  //
  // lib/config/app_links.dart
  //
  // and reference them from there.
  // ==========================================================================

  static const String websiteUrl = 'https://your-site.com';
  static const String privacyPolicyUrl = 'https://privacy.com';
  static const String termsUrl = 'https://terms.com';

  // ==========================================================================
  // STATE
  // ==========================================================================

  String userName = '';
  String userId = '';
  String appVersion = '';

  bool isLoading = true;

  /// Prevents opening multiple name dialogs at the same time.
  bool _isNameDialogOpen = false;

  /// Prevents multiple reset operations at the same time.
  bool _isResetting = false;

  // ==========================================================================
  // LIFECYCLE
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // ==========================================================================
  // INITIALIZATION
  // ==========================================================================

  Future<void> _initialize() async {
    try {
      await Future.wait([loadUser(), loadAppVersion()]);
    } catch (e, stackTrace) {
      debugPrint('Settings initialization error: $e');
      debugPrintStack(stackTrace: stackTrace);
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  // ==========================================================================
  // LOAD APP VERSION
  // ==========================================================================

  Future<void> loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();

      if (!mounted) return;

      setState(() {
        appVersion = '${info.version} (${info.buildNumber})';
      });
    } catch (e, stackTrace) {
      debugPrint('App version load error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        appVersion = 'Unknown';
      });
    }
  }

  // ==========================================================================
  // LOAD USER DATA
  // ==========================================================================

  Future<void> loadUser() async {
    try {
      // IMPORTANT:
      // These calls are intentionally not awaited.
      //
      // Your current code indicates that getUserName() and getUserId()
      // return synchronously. Do not change this to await unless the
      // UserService API actually returns Future values.
      final name = userService.getUserName();
      final id = userService.getUserId();

      if (!mounted) return;

      setState(() {
        userName = name?.trim() ?? '';
        userId = id;
      });

      // Ask for a name after the screen has completed its current lifecycle
      // work. The flag prevents duplicate dialogs.
      if (name == null || name.trim().isEmpty) {
        Future.microtask(() {
          if (!mounted || _isNameDialogOpen) return;
          _promptName();
        });
      }
    } catch (e, stackTrace) {
      debugPrint('User load error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      // Keep safe defaults if user loading fails.
      setState(() {
        userName = '';
        userId = '';
      });
    }
  }

  // ==========================================================================
  // NAME INPUT DIALOG
  // ==========================================================================

  Future<void> _promptName() async {
    if (!mounted || _isNameDialogOpen) return;

    _isNameDialogOpen = true;

    final controller = TextEditingController(text: userName);
    String? errorText;
    bool isSaving = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setStateDialog) {
              Future<void> saveName() async {
                if (isSaving) return;

                final name = controller.text.trim();

                // ------------------------------------------------------------
                // VALIDATION
                // ------------------------------------------------------------

                if (name.isEmpty) {
                  setStateDialog(() {
                    errorText = 'Please enter your name';
                  });
                  return;
                }

                if (name.length < 3) {
                  setStateDialog(() {
                    errorText = 'Minimum 3 characters required';
                  });
                  return;
                }

                if (name.length > 50) {
                  setStateDialog(() {
                    errorText = 'Name must be 50 characters or less';
                  });
                  return;
                }

                // ------------------------------------------------------------
                // SAVE
                // ------------------------------------------------------------

                setStateDialog(() {
                  isSaving = true;
                  errorText = null;
                });

                try {
                  await userService.saveUserName(name);

                  if (!mounted) return;

                  setState(() {
                    userName = name;
                  });

                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                } catch (e, stackTrace) {
                  debugPrint('Save name error: $e');
                  debugPrintStack(stackTrace: stackTrace);

                  if (!dialogContext.mounted) return;

                  setStateDialog(() {
                    isSaving = false;
                    errorText = 'Could not save your name. Please try again.';
                  });
                }
              }

              return AlertDialog(
                title: const Text('Enter your name'),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  maxLength: 50,
                  enabled: !isSaving,
                  onSubmitted: (_) {
                    saveName();
                  },
                  decoration: InputDecoration(
                    hintText: 'Your Name',
                    errorText: errorText,
                    counterText: '',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () {
                            Navigator.of(dialogContext).pop();
                          },
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: isSaving ? null : saveName,
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
      _isNameDialogOpen = false;
    }
  }

  // ==========================================================================
  // OPEN EXTERNAL LINK
  // ==========================================================================

  Future<void> openLink(String url) async {
    try {
      final uri = Uri.tryParse(url);

      if (uri == null ||
          !uri.hasScheme ||
          !(uri.scheme == 'http' || uri.scheme == 'https')) {
        debugPrint('Invalid URL: $url');

        if (!mounted) return;

        _showSnackBar('Invalid link');

        return;
      }

      final success = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!success) {
        debugPrint('Could not launch URL: $url');

        if (!mounted) return;

        _showSnackBar('Could not open link');
      }
    } catch (e, stackTrace) {
      debugPrint('URL launch error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      _showSnackBar('Could not open link');
    }
  }

  // ==========================================================================
  // RESET DATA DIALOG
  // ==========================================================================

  Future<void> showResetDialog() async {
    if (!mounted || _isResetting) return;

    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset Data'),
          content: const Text(
            'This will erase all progress permanently. '
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Reset', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldReset != true || !mounted || _isResetting) {
      return;
    }

    await _resetProgress();
  }

  // ==========================================================================
  // RESET PROGRESS
  // ==========================================================================

  Future<void> _resetProgress() async {
    if (_isResetting) return;

    setState(() {
      _isResetting = true;
    });

    try {
      await progressService.resetProgress();

      if (!mounted) return;

      _showSnackBar('Progress reset successfully');
    } catch (e, stackTrace) {
      debugPrint('Reset progress error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      _showSnackBar('Could not reset progress. Please try again.');
    } finally {
      if (!mounted) return;

      setState(() {
        _isResetting = false;
      });
    }
  }

  // ==========================================================================
  // COPY USER ID
  // ==========================================================================

  Future<void> _copyUserId() async {
    if (userId.isEmpty) {
      _showSnackBar('User ID is not available');
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: userId));

      if (!mounted) return;

      _showSnackBar('User ID copied');
    } catch (e, stackTrace) {
      debugPrint('Clipboard error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      _showSnackBar('Could not copy User ID');
    }
  }

  // ==========================================================================
  // SHARE
  // ==========================================================================

  void _shareApp() {
    // TODO:
    // Implement app sharing when the desired share content/store URL is known.
    //
    // Example future implementation could use the share_plus package.
    //
    // Do not add a package/dependency here until the desired sharing behavior
    // has been decided.
    _showSnackBar('Share is not available yet');
  }

  // ==========================================================================
  // SNACKBAR HELPER
  // ==========================================================================

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  // ==========================================================================
  // UI
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Column(
        children: [
          // ==================================================================
          // SCROLLABLE SETTINGS CONTENT
          // ==================================================================
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ==============================================================
                // PROFILE
                // ==============================================================
                SettingsTile(
                  icon: Icons.person,
                  title: userName.isEmpty ? 'Set your name' : userName,
                  subtitle: 'Tap to edit',
                  trailing: const Icon(Icons.edit),
                  onTap: _promptName,
                ),

                // ==============================================================
                // USER ID
                // ==============================================================
                SettingsTile(
                  icon: Icons.fingerprint,
                  title: 'User ID',
                  subtitle: userId.isEmpty ? 'Unavailable' : userId,
                  trailing: IconButton(
                    tooltip: 'Copy User ID',
                    icon: const Icon(Icons.copy),
                    onPressed: userId.isEmpty ? null : _copyUserId,
                  ),
                ),

                // ==============================================================
                // RESET
                // ==============================================================
                SettingsTile(
                  icon: Icons.delete,
                  title: 'Reset Data',
                  subtitle: 'Erase all saved progress',
                  isDanger: true,
                  trailing: _isResetting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: _isResetting ? null : showResetDialog,
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),

          // ==================================================================
          // FOOTER
          // ==================================================================
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // ============================================================
                  // SOCIAL / WEBSITE / SHARE
                  // ============================================================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Open website',
                        icon: const Icon(Icons.public),
                        onPressed: () {
                          openLink(websiteUrl);
                        },
                      ),
                      IconButton(
                        tooltip: 'Share app',
                        icon: const Icon(Icons.share),
                        onPressed: _shareApp,
                      ),
                    ],
                  ),

                  // ============================================================
                  // VERSION
                  // ============================================================
                  Text(
                    appVersion.isEmpty
                        ? 'Version unavailable'
                        : 'Version $appVersion',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 8),

                  // ============================================================
                  // LEGAL LINKS
                  // ============================================================
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () {
                          openLink(privacyPolicyUrl);
                        },
                        child: const Text('Privacy Policy'),
                      ),
                      const Text('•'),
                      TextButton(
                        onPressed: () {
                          openLink(termsUrl);
                        },
                        child: const Text('Terms & Conditions'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
