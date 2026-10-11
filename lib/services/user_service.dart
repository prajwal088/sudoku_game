import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// ============================================================================
/// UserService
/// ----------------------------------------------------------------------------
/// Central source of truth for local user identity and profile information.
///
/// Responsibilities:
/// - Create and persist a unique local user ID.
/// - Load the user's saved display name.
/// - Persist changes to the user's display name.
/// - Provide fast in-memory access through cached values.
/// - Notify listeners when the display name changes.
///
/// Architecture:
/// - Singleton service.
/// - SharedPreferences for local persistence.
/// - UUID v4 for user ID generation.
/// - Cache is updated only after successful persistence.
/// - Mutations are serialized so concurrent saves/clears cannot leave the
///   cache and storage out of sync.
/// - Persisted values are validated on load, so a corrupt or wrong-typed
///   entry can never prevent the app from starting.
///
/// IMPORTANT:
/// Call [init] during application startup before accessing user data.
///
/// Example:
///
/// ```dart
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   await UserService().init();
///
///   runApp(const SudokuApp());
/// }
/// ```
/// ============================================================================

class UserService {
  // ==========================================================================
  // STORAGE KEYS
  // ==========================================================================

  static const String _keyName = 'user_name';
  static const String _keyId = 'user_id';

  // ==========================================================================
  // CONFIGURATION
  // ==========================================================================

  /// Maximum display-name length, measured in Unicode code points.
  ///
  /// (Code points rather than UTF-16 units, so an emoji counts as one.)
  static const int maxUserNameLength = 50;

  /// Matches any run of whitespace, including tabs and line breaks.
  static final RegExp _whitespaceRun = RegExp(r'\s+');

  // ==========================================================================
  // SINGLETON
  // ==========================================================================

  static final UserService _instance = UserService._internal();

  factory UserService() => _instance;

  UserService._internal();

  // ==========================================================================
  // DEPENDENCIES
  // ==========================================================================

  final Uuid _uuid = const Uuid();

  // ==========================================================================
  // STORAGE
  // ==========================================================================

  SharedPreferences? _prefs;

  // ==========================================================================
  // CACHE
  // ==========================================================================

  String? _cachedUserId;

  /// Always null or a normalized, valid name (see [_normalizeName]).
  String? _cachedUserName;

  // ==========================================================================
  // NOTIFICATIONS
  // ==========================================================================

  final StreamController<String?> _nameController =
      StreamController<String?>.broadcast();

  /// Emits the new display name (or null when cleared) after it has been
  /// successfully persisted.
  Stream<String?> get onUserNameChanged => _nameController.stream;

  void _notifyNameChanged() {
    if (!_nameController.isClosed) {
      _nameController.add(_cachedUserName);
    }
  }

  // ==========================================================================
  // INITIALIZATION STATE
  // ==========================================================================

  bool _isInitialized = false;

  /// Shared initialization future prevents duplicate initialization work when
  /// multiple callers invoke [init] simultaneously.
  Future<void>? _initializationFuture;

  /// Returns true when [init] has completed successfully.
  bool get isInitialized => _isInitialized;

  // ==========================================================================
  // MUTATION QUEUE
  // ==========================================================================

  /// Serializes persistence mutations.
  ///
  /// The queue itself never holds an error (failures go to the caller of the
  /// failed mutation only), so one failure cannot block later mutations.
  Future<void> _mutationQueue = Future<void>.value();

  Future<T> _runMutation<T>(Future<T> Function() mutation) {
    final Future<T> result = _mutationQueue.then<T>((_) => mutation());

    _mutationQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );

    return result;
  }

  // ==========================================================================
  // INITIALIZATION
  // ==========================================================================

  /// Initializes the service.
  ///
  /// Safe to call multiple times.
  ///
  /// Multiple simultaneous callers share the same initialization operation.
  ///
  /// If initialization fails, the service remains uninitialized and a later
  /// call to [init] can retry initialization.
  Future<void> init() async {
    if (_isInitialized) {
      return;
    }

    final Future<void> inFlight = _initializationFuture ??= _initialize()
        .whenComplete(() {
          _initializationFuture = null;
        });

    await inFlight;
  }

  Future<void> _initialize() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      String? userId = _readUserId(prefs);
      final String? userName = _readUserName(prefs);

      // ----------------------------------------------------------------------
      // CREATE USER ID WHEN NECESSARY
      // ----------------------------------------------------------------------

      if (userId == null) {
        final String generatedUserId = _uuid.v4();

        final bool saved = await prefs.setString(_keyId, generatedUserId);

        if (!saved) {
          throw StateError(
            'SharedPreferences could not persist the generated user ID.',
          );
        }

        userId = generatedUserId;
      }

      // ----------------------------------------------------------------------
      // UPDATE CACHE ONLY AFTER SUCCESSFUL INITIALIZATION
      // ----------------------------------------------------------------------

      _prefs = prefs;
      _cachedUserId = userId;
      _cachedUserName = userName;
      _isInitialized = true;
    } catch (_) {
      _resetInitializationState();
      rethrow;
    }
  }

  // ==========================================================================
  // USER ID
  // ==========================================================================

  /// Returns the persistent local user ID.
  ///
  /// The ID is generated once and persisted locally.
  ///
  /// Throws [StateError] when the service has not been initialized.
  String getUserId() {
    _ensureInitialized();

    final String? userId = _cachedUserId;

    if (userId == null || userId.isEmpty) {
      throw StateError(
        'UserService is initialized but the user ID is unavailable.',
      );
    }

    return userId;
  }

  // ==========================================================================
  // USER NAME
  // ==========================================================================

  /// Returns the saved user display name.
  ///
  /// Returns `null` when the user has not entered a name yet.
  ///
  /// Throws [StateError] when the service has not been initialized.
  String? getUserName() {
    _ensureInitialized();

    return _cachedUserName;
  }

  /// Saves the user's display name.
  ///
  /// The name is normalized before validation and persistence: leading and
  /// trailing whitespace is removed and any run of whitespace (including line
  /// breaks) becomes a single space.
  ///
  /// Saving the name that is already stored is a no-op (no disk write).
  ///
  /// Throws (through the returned Future):
  /// - [StateError] when the service has not been initialized.
  /// - [ArgumentError] when the name is empty.
  /// - [ArgumentError] when the name exceeds [maxUserNameLength].
  /// - [StateError] when storage is unavailable or the write fails.
  Future<void> saveUserName(String name) async {
    _ensureInitialized();

    final String normalizedName = _normalizeName(name);

    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'User name cannot be empty.');
    }

    if (normalizedName.runes.length > maxUserNameLength) {
      throw ArgumentError.value(
        name,
        'name',
        'User name cannot exceed $maxUserNameLength characters.',
      );
    }

    await _runMutation<void>(() async {
      final SharedPreferences prefs = _requirePrefs();

      if (normalizedName == _cachedUserName) {
        return;
      }

      final bool saved = await prefs.setString(_keyName, normalizedName);

      if (!saved) {
        throw StateError('SharedPreferences could not save the user name.');
      }

      // Update memory only after persistence succeeds.
      _cachedUserName = normalizedName;

      _notifyNameChanged();
    });
  }

  // ==========================================================================
  // OPTIONAL PROFILE HELPERS
  // ==========================================================================

  /// Returns true when a user name has been configured.
  bool hasUserName() {
    _ensureInitialized();

    // The cached name is always normalized and non-empty, or null.
    return _cachedUserName != null;
  }

  /// Clears the saved user name.
  ///
  /// The persistent user ID is intentionally preserved.
  ///
  /// Throws (through the returned Future) a [StateError] when the stored name
  /// could not be removed. The cache is only cleared after the removal
  /// succeeds, so memory and storage never disagree.
  Future<void> clearUserName() async {
    _ensureInitialized();

    await _runMutation<void>(() async {
      final SharedPreferences prefs = _requirePrefs();

      final bool removed = await prefs.remove(_keyName);

      // A false result is only acceptable when the key is genuinely gone.
      if (!removed && prefs.containsKey(_keyName)) {
        throw StateError('SharedPreferences could not clear the user name.');
      }

      if (_cachedUserName != null) {
        _cachedUserName = null;

        _notifyNameChanged();
      }
    });
  }

  // ==========================================================================
  // NORMALIZATION
  // ==========================================================================

  /// Trims the name and collapses internal whitespace to single spaces.
  String _normalizeName(String name) {
    return name.trim().replaceAll(_whitespaceRun, ' ');
  }

  // ==========================================================================
  // STORAGE READERS
  // ==========================================================================

  /// Reads a String value without throwing when the stored entry has a
  /// different type (for example after a bad migration or key clash).
  String? _readString(SharedPreferences prefs, String key) {
    final Object? value = prefs.get(key);

    return value is String ? value : null;
  }

  String? _readUserId(SharedPreferences prefs) {
    final String? value = _readString(prefs, _keyId)?.trim();

    if (value == null || value.isEmpty) {
      return null;
    }

    return value;
  }

  /// Reads the persisted name and enforces the same invariants as
  /// [saveUserName], so the cache can never hold an unusable value.
  String? _readUserName(SharedPreferences prefs) {
    final String? raw = _readString(prefs, _keyName);

    if (raw == null) {
      return null;
    }

    String name = _normalizeName(raw);

    if (name.isEmpty) {
      return null;
    }

    if (name.runes.length > maxUserNameLength) {
      name = String.fromCharCodes(
        name.runes.take(maxUserNameLength),
      ).trimRight();
    }

    return name.isEmpty ? null : name;
  }

  // ==========================================================================
  // STATE MANAGEMENT
  // ==========================================================================

  SharedPreferences _requirePrefs() {
    final SharedPreferences? prefs = _prefs;

    if (prefs == null) {
      throw StateError(
        'UserService is initialized but storage is unavailable.',
      );
    }

    return prefs;
  }

  void _ensureInitialized() {
    if (!_isInitialized || _prefs == null) {
      throw StateError(
        'UserService not initialized. '
        'Call await UserService().init() before using user data.',
      );
    }
  }

  void _resetInitializationState() {
    _prefs = null;
    _cachedUserId = null;
    _cachedUserName = null;
    _isInitialized = false;
  }
}