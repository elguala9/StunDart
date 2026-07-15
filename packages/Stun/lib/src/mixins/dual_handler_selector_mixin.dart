import 'package:meta/meta.dart';

import '../interfaces/i_stun_handler.dart';

/// Internal-only shared IPv4/IPv6 handler selection behavior.
///
/// The mixing class provides the two handler slots and the error message used
/// when the requested handler is missing. Not part of the package's public
/// API — do not export it from `stun.dart`.
@internal
mixin DualHandlerSelectorMixin {
  /// IPv4 handler (optional, null if unavailable or after close)
  IStunHandler? get ipv4Handler;

  /// IPv6 handler (optional, null if unavailable or after close)
  IStunHandler? get ipv6Handler;

  /// Message used by [requireHandler] when the requested handler is missing.
  String missingHandlerMessage({required bool ipv6});

  /// Returns the requested handler, throwing [StateError] when unavailable.
  IStunHandler requireHandler({required bool ipv6}) {
    final handler = ipv6 ? ipv6Handler : ipv4Handler;
    if (handler == null) {
      throw StateError(missingHandlerMessage(ipv6: ipv6));
    }
    return handler;
  }
}
