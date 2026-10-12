import 'dart:async';

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
/// - The screen renders immediately: user data is read synchronously from
///   UserService and only the app version is loaded asynchronously.
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

  final UserService _userService = UserService();
  final ProgressService _progressService = ProgressService();

  // ==========================================================================
  // APP LINKS
  // ==========================================================================
  //
  // !!! RELEASE BLOCKER !!!
  // These are PLACEHOLDER URLs. `privacy.com` and `terms.com` are real,
  // unrelated websites. Replace all three with your real production URLs
  // before release (app stores also require a working privacy policy link).
  //
  // If these URLs are used by multiple files, move them to a shared file such
  // as lib/config/app_links.dart and reference them from there.
  // ==========================================================================

  static const String _websiteUrl = 'https://your-site.com';
  static const String _privacyPolicyUrl = 'https://privacy.com';
  static const String _termsUrl = 'https://terms.com';

  /// The share button is hidden until sharing is implemented, so players are
  /// never shown a button that only says "not available yet".
  ///
  /// Set to true once [_shareApp] is implemented.
  static const bool _isShareAvailable = false;

  // ==========================================================================
  // STATE
  // ==========================================================================

  String _userName = '';
  String _userId = '';

  /// Empty until loaded; 'Unknown' if loading failed.
  String _appVersion = '';

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

    _loadUser();

    unawaited(_loadAppVersion());
  }

  // ==========================================================================
  // LOAD APP VERSION
  // ==========================================================================

  Future<void> _loadAppVersion() async {
    String version;

    try {
      final PackageInfo info = await PackageInfo.fromPlatform();

      version = '${info.version} (${info.buildNumber})';
    } catch (e, stackTrace) {
      debugPrint('App version load error: $e');
      debugPrintStack(stackTrace: stackTrace);

      version = 'Unknown';
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _appVersion = version;
    });
  }

  // ==========================================================================
  // LOAD USER DATA
  // ==========================================================================

  /// Reads user data synchronously (UserService caches it in memory), so the
  /// first frame already shows the real values and no spinner is needed.
  void _loadUser() {
    String? name;

    try {
      name = _userService.getUserName();

      _userName = name?.trim() ?? '';
      _userId = _userService.getUserId();
    } catch (e, stackTrace) {
      debugPrint('User load error: $e');
      debugPrintStack(stackTrace: stackTrace);

      // Keep safe defaults if user loading fails.
      _userName = '';
      _userId = '';
    }

    // Ask for a name once the first frame is up. The flag prevents duplicate
    // dialogs.
    if (_userName.isEmpty && _userId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isNameDialogOpen) {
          return;
        }

        unawaited(_promptName());
      });
    }
  }

  // ==========================================================================
  // NAME INPUT DIALOG
  // ==========================================================================

  Future<void> _promptName() async {
    if (!mounted || _isNameDialogOpen) {
      return;
    }

    _isNameDialogOpen = true;

    try {
      final String? savedName = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return _NameDialog(
            initialName: _userName,
            userService: _userService,
          );
        },
      );

      if (savedName == null || !mounted) {
        return;
      }

      setState(() {
        _userName = savedName;
      });
    } finally {
      _isNameDialogOpen = false;
    }
  }

  // ==========================================================================
  // OPEN EXTERNAL LINK
  // ==========================================================================

  Future<void> _openLink(String url) async {
    try {
      final Uri? uri = Uri.tryParse(url);

      if (uri == null ||
          !uri.hasScheme ||
          !(uri.scheme == 'http' || uri.scheme == 'https')) {
        debugPrint('Invalid URL: $url');

        _showSnackBar('Invalid link');

        return;
      }

      final bool success = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!success) {
        debugPrint('Could not launch URL: $url');

        _showSnackBar('Could not open link');
      }
    } catch (e, stackTrace) {
      debugPrint('URL launch error: $e');
      debugPrintStack(stackTrace: stackTrace);

      _showSnackBar('Could not open link');
    }
  }

  // ==========================================================================
  // RESET DATA DIALOG
  // ==========================================================================

  Future<void> _showResetDialog() async {
    if (!mounted || _isResetting) {
      return;
    }

    final bool? shouldReset = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Reset Data'),
          content: const Text(
            'This will erase all progress permanently. '
            'This action cannot be undone.',
          ),
          actions: <Widget>[
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
              child: Text(
                'Reset',
                style: TextStyle(
                  color: Theme.of(dialogContext).colorScheme.error,
                ),
              ),
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
    if (_isResetting) {
      return;
    }

    setState(() {
      _isResetting = true;
    });

    try {
      await _progressService.resetProgress();

      _showSnackBar('Progress reset successfully');
    } catch (e, stackTrace) {
      debugPrint('Reset progress error: $e');
      debugPrintStack(stackTrace: stackTrace);

      _showSnackBar('Could not reset progress. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isResetting = false;
        });
      }
    }
  }

  // ==========================================================================
  // COPY USER ID
  // ==========================================================================

  Future<void> _copyUserId() async {
    if (_userId.isEmpty) {
      _showSnackBar('User ID is not available');
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: _userId));

      _showSnackBar('User ID copied');
    } catch (e, stackTrace) {
      debugPrint('Clipboard error: $e');
      debugPrintStack(stackTrace: stackTrace);

      _showSnackBar('Could not copy User ID');
    }
  }

  // ==========================================================================
  // SHARE
  // ==========================================================================

  void _shareApp() {
    // TODO:
    // Implement app sharing when the desired share content/store URL is known
    // (for example with the share_plus package), then set _isShareAvailable
    // to true.
    //
    // Do not add a package/dependency here until the desired sharing behavior
    // has been decided.
    _showSnackBar('Share is not available yet');
  }

  // ==========================================================================
  // SNACKBAR HELPER
  // ==========================================================================

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

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
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Column(
        children: <Widget>[
          // ==================================================================
          // SCROLLABLE SETTINGS CONTENT
          // ==================================================================
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                // PROFILE
                SettingsTile(
                  icon: Icons.person,
                  title: _userName.isEmpty ? 'Set your name' : _userName,
                  subtitle: 'Tap to edit',
                  trailing: const Icon(Icons.edit),
                  onTap: _promptName,
                ),

                // USER ID
                SettingsTile(
                  icon: Icons.fingerprint,
                  title: 'User ID',
                  subtitle: _userId.isEmpty ? 'Unavailable' : _userId,
                  trailing: IconButton(
                    tooltip: 'Copy User ID',
                    icon: const Icon(Icons.copy),
                    onPressed: _userId.isEmpty ? null : _copyUserId,
                  ),
                ),

                // RESET
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
                  onTap: _isResetting ? null : _showResetDialog,
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
                children: <Widget>[
                  // WEBSITE / SHARE
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Open website',
                        icon: const Icon(Icons.public),
                        onPressed: () => unawaited(_openLink(_websiteUrl)),
                      ),
                      if (_isShareAvailable)
                        IconButton(
                          tooltip: 'Share app',
                          icon: const Icon(Icons.share),
                          onPressed: _shareApp,
                        ),
                    ],
                  ),

                  // VERSION
                  _buildVersionLabel(),

                  const SizedBox(height: 8),

                  // LEGAL LINKS
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      TextButton(
                        onPressed: () => unawaited(_openLink(_privacyPolicyUrl)),
                        child: const Text('Privacy Policy'),
                      ),
                      const Text('•'),
                      TextButton(
                        onPressed: () => unawaited(_openLink(_termsUrl)),
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

  Widget _buildVersionLabel() {
    // Reserve the line's height while the version loads, so the footer does
    // not jump when it appears.
    const double lineHeight = 16;

    if (_appVersion.isEmpty) {
      return const SizedBox(height: lineHeight);
    }

    return Text(
      _appVersion == 'Unknown'
          ? 'Version unavailable'
          : 'Version $_appVersion',
      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
    );
  }
}

// ============================================================================
// NAME DIALOG
// ----------------------------------------------------------------------------
// A dedicated StatefulWidget so the TextEditingController is created and
// disposed by the dialog's own State. Disposing a controller right after
// `showDialog` returns (while the close animation is still running) makes the
// TextField use a disposed controller and throws.
// ============================================================================

class _NameDialog extends StatefulWidget {
  final String initialName;
  final UserService userService;

  const _NameDialog({required this.initialName, required this.userService});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  static const int _minimumLength = 3;

  /// Mirrors UserService: any run of whitespace becomes a single space.
  static final RegExp _whitespaceRun = RegExp(r'\s+');

  late final TextEditingController _controller;

  String? _errorText;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: widget.initialName);

    // Select the existing name so it can be replaced by simply typing.
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    final String name = _controller.text.trim().replaceAll(_whitespaceRun, ' ');

    // Length in Unicode code points, same rule as UserService.
    final int length = name.runes.length;

    // ------------------------------------------------------------------------
    // VALIDATION
    // ------------------------------------------------------------------------

    if (name.isEmpty) {
      setState(() {
        _errorText = 'Please enter your name';
      });
      return;
    }

    if (length < _minimumLength) {
      setState(() {
        _errorText = 'Minimum $_minimumLength characters required';
      });
      return;
    }

    if (length > UserService.maxUserNameLength) {
      setState(() {
        _errorText =
            'Name must be ${UserService.maxUserNameLength} characters or less';
      });
      return;
    }

    // ------------------------------------------------------------------------
    // SAVE
    // ------------------------------------------------------------------------

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      await widget.userService.saveUserName(name);

      if (!mounted) {
        return;
      }

      // Return the name exactly as stored by the service.
      Navigator.of(context).pop(widget.userService.getUserName() ?? name);
    } catch (e, stackTrace) {
      debugPrint('Save name error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
        _errorText = 'Could not save your name. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Do not let the back button close the dialog mid-save.
      canPop: !_isSaving,
      child: AlertDialog(
        title: const Text('Enter your name'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          maxLength: UserService.maxUserNameLength,
          enabled: !_isSaving,
          onSubmitted: (_) => unawaited(_save()),
          decoration: InputDecoration(
            hintText: 'Your Name',
            errorText: _errorText,
            counterText: '',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _isSaving ? null : () => unawaited(_save()),
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}