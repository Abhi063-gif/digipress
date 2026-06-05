/// Simple singleton that tracks the currently logged-in user.
/// Admin access is hard-gated to a4abhi078@gmail.com / Abhi@123.
class AuthService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // ── Admin credentials (hard-coded as per requirement) ──────────────────────
  static const String adminEmail = 'a4abhi078@gmail.com';
  static const String adminPassword = 'Abhi@123';

  // ── State ──────────────────────────────────────────────────────────────────
  String? _currentEmail;
  String? _currentName;

  // ── Session ────────────────────────────────────────────────────────────────
  void login({required String email, required String name}) {
    _currentEmail = email.trim().toLowerCase();
    _currentName = name;
  }

  void logout() {
    _currentEmail = null;
    _currentName = null;
  }

  // ── Accessors ──────────────────────────────────────────────────────────────
  String? get currentEmail => _currentEmail;
  String? get currentName => _currentName;

  /// Returns true only when the signed-in account is the admin account.
  bool get isAdmin =>
      _currentEmail != null &&
      _currentEmail == adminEmail.toLowerCase();

  /// Validates admin credentials without creating a session.
  static bool validateCredentials(String email, String password) =>
      email.trim().toLowerCase() == adminEmail.toLowerCase() &&
      password == adminPassword;
}
