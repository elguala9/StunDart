import 'package:meta/meta.dart';

import '../interfaces/i_stun_handler.dart';

/// Internal-only shared IPv4/IPv6 handler selection behavior.
///
/// The mixing class provides the two handler slots and the error message used
/// when the requested handler is missing. Not part of the package's public
/// API — do not export it from `stun.dart`.
@internal
mixin HandlerSelectorMixin {
  IStunHandler? handler({required bool ipv6});

  /// Message used by [requireHandler] when the requested handler is missing.
  String missingHandlerMessage({required bool ipv6});

  /// Returns the requested handler, throwing [StateError] when unavailable.
  IStunHandler requireHandler({required bool ipv6}) {
    final h = handler(ipv6: ipv6);
    if (h == null) {
      throw StateError(missingHandlerMessage(ipv6: ipv6));
    }
    return h;
  }
}
