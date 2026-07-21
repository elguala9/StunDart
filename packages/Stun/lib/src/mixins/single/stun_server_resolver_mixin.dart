import 'dart:io';

import 'package:meta/meta.dart';

/// Internal-only shared STUN server DNS resolution behavior.
/// Not part of the package's public API — do not export it from `stun.dart`.
@internal
mixin StunServerResolverMixin {
  /// Resolves [hostname] to an address of the requested IP family.
  ///
  /// Throws [StateError] when the lookup returns no result.
  Future<InternetAddress> resolveStunServer(
    String hostname, {
    required InternetAddressType type,
  }) async {
    final addresses = await InternetAddress.lookup(
      hostname,
      type: type,
    );

    if (addresses.isEmpty) {
      throw StateError('Could not resolve STUN server address: $hostname');
    }

    return addresses.first;
  }
}
