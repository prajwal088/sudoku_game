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
///
/// Architecture:
/// - Singleton service.
/// - SharedPreferences for local persistence.
/// - UUID v4 for user ID generation.
/// - Cache is updated only after successful persistence.
///
/// IMPORTANT:
/// Call [init] during application startup before accessing user data.
///
/// Example:
///
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   await UserService().init();
///
///   runApp(const SudokuApp());
/// }
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

  static const int maxUserNameLength = 50;

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
  String? _cachedUserName;

  // ==========================================================================
  // INITIALIZATION STATE
  // ==========================================================================

  bool _isInitialized = false;

  /// Shared initialization future prevents duplicate initialization work when
  /// multiple callers invoke [init] simultaneously.
  Future<void>? _initializationFuture;

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
  Future<void> init() {
    if (_isInitialized) {
      return Future<void>.value();
    }

    final existingFuture = _initializationFuture;

    if (existingFuture != null) {
      return existingFuture;
    }

    final future = _initialize();

    _initializationFuture = future;

    return future.whenComplete(() {
      if (identical(_initializationFuture, future)) {
        _initializationFuture = null;
      }
    });
  }

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      String? userId = _readUserId(prefs);
      final userName = _readUserName(prefs);

      // ----------------------------------------------------------------------
      // CREATE USER ID WHEN NECESSARY
      // ----------------------------------------------------------------------

      if (userId == null) {
        final generatedUserId = _uuid.v4();

        final saved = await prefs.setString(_keyId, generatedUserId);

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

    final userId = _cachedUserId;

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
  /// The name is trimmed before validation and persistence.
  ///
  /// Throws:
  /// - [StateError] when the service has not been initialized.
  /// - [ArgumentError] when the name is empty.
  /// - [ArgumentError] when the name exceeds [maxUserNameLength].
  /// - [StateError] when storage is unavailable.
  Future<void> saveUserName(String name) async {
    _ensureInitialized();

    final normalizedName = name.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'User name cannot be empty.');
    }

    if (normalizedName.length > maxUserNameLength) {
      throw ArgumentError.value(
        name,
        'name',
        'User name cannot exceed $maxUserNameLength characters.',
      );
    }

    final prefs = _prefs;

    if (prefs == null) {
      throw StateError(
        'UserService is initialized but storage is unavailable.',
      );
    }

    final saved = await prefs.setString(_keyName, normalizedName);

    if (!saved) {
      throw StateError('SharedPreferences could not save the user name.');
    }

    // Update memory only after persistence succeeds.
    _cachedUserName = normalizedName;
  }

  // ==========================================================================
  // OPTIONAL PROFILE HELPERS
  // ==========================================================================

  /// Returns true when a non-empty user name has been configured.
  bool hasUserName() {
    _ensureInitialized();

    final name = _cachedUserName;

    return name != null && name.trim().isNotEmpty;
  }

  /// Clears the saved user name.
  ///
  /// The persistent user ID is intentionally preserved.
  Future<void> clearUserName() async {
    _ensureInitialized();

    final prefs = _prefs;

    if (prefs == null) {
      throw StateError(
        'UserService is initialized but storage is unavailable.',
      );
    }

    final removed = await prefs.remove(_keyName);

    // A false result simply means the key did not exist.
    if (!removed && _cachedUserName == null) {
      return;
    }

    _cachedUserName = null;
  }

  // ==========================================================================
  // STORAGE READERS
  // ==========================================================================

  String? _readUserId(SharedPreferences prefs) {
    final value = prefs.getString(_keyId)?.trim();

    if (value == null || value.isEmpty) {
      return null;
    }

    return value;
  }

  String? _readUserName(SharedPreferences prefs) {
    final value = prefs.getString(_keyName)?.trim();

    if (value == null || value.isEmpty) {
      return null;
    }

    return value;
  }

  // ==========================================================================
  // STATE MANAGEMENT
  // ==========================================================================

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
