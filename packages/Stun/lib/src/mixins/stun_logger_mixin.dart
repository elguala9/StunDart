import 'package:meta/meta.dart';

/// Internal-only shared logging behavior.
///
/// The mixing class provides the optional [onLog] callback; the mixin
/// provides the [log] helper. Not part of the package's public API — do not
/// export it from `stun.dart`.
@internal
mixin StunLoggerMixin {
  /// Optional logging callback provided by the mixing class.
  void Function(String)? get onLog;

  /// Logs a message through [onLog] when available.
  void log(String message) => onLog?.call(message);
}
