import 'dart:io';

import 'package:meta/meta.dart';

import '../../interfaces/single/i_stun_handler.dart';

/// Internal-only shared IPv4/IPv6 handler selection behavior.
///
/// The mixing class provides the two handler slots and the error message used
/// when the requested handler is missing. Not part of the package's public
/// API — do not export it from `stun.dart`.
@internal
mixin HandlerSelectorMixin {
  IStunHandler? handler({required InternetAddressType type});

  /// Message used by [requireHandler] when the requested handler is missing.
  String missingHandlerMessage({required InternetAddressType type});

  /// Returns the requested handler, throwing [StateError] when unavailable.
  IStunHandler requireHandler({required InternetAddressType type}) {
    final h = handler(type: type);
    if (h == null) {
      throw StateError(missingHandlerMessage(type: type));
    }
    return h;
  }
}
