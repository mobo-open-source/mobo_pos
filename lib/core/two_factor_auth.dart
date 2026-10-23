/// Signals that a [TwoFactorAuthPage] is actively running a 2FA flow for the
/// given server. While this is non-null, the webview host must not touch
/// cookies or attempt a silent re-login for that server, because a
/// concurrent attempt would race with the TOTP session commit and corrupt
/// the authenticated cookie.
///
/// Also guards the "session died mid-use, bounce back to a TOTP challenge"
/// recovery path against looping forever: if that recovery keeps failing
/// (e.g. the account's password itself changed, or the server keeps
/// rejecting the session for some other reason), [registerReloginHandoff]
/// starts returning false so the caller falls back to a full logout instead
/// of silently retrying indefinitely.
class TwoFactorAuth {
  TwoFactorAuth._();

  static String? activeServer;

  static int _handoffCount = 0;
  static DateTime? _firstHandoffAt;

  static const int maxHandoffs = 2;
  static const Duration _handoffWindow = Duration(minutes: 2);

  /// Records a webview -> 2FA handoff and reports whether it is allowed.
  ///
  /// Returns false once [maxHandoffs] handoffs have occurred within
  /// [_handoffWindow], indicating the caller must not hand off again because
  /// the re-login cycle is looping.
  static bool registerReloginHandoff({DateTime? now}) {
    final at = now ?? DateTime.now();
    final first = _firstHandoffAt;
    if (first == null || at.difference(first) > _handoffWindow) {
      _firstHandoffAt = at;
      _handoffCount = 1;
      return true;
    }
    _handoffCount++;
    return _handoffCount <= maxHandoffs;
  }

  /// Clears the handoff counter after a confirmed-good authentication.
  static void resetReloginHandoffs() {
    _handoffCount = 0;
    _firstHandoffAt = null;
  }
}
