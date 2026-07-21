import 'dart:io';

import '../types/stun_types.dart';

abstract interface class IDualCallbackHandler {
  /// Returns the socket-refresh callback for [type] (defaults to IPv6) to pass
  /// to handlers at creation/registration time.
  OnSocketRefresh getOn({InternetAddressType type = InternetAddressType.IPv6});

  /// Registers a wrapper on the callback dispatcher of [type] (defaults to
  /// IPv6).
  void register(
    void Function((StunResponse, StunResponse?)) wrapper, {
    InternetAddressType type = InternetAddressType.IPv6,
  });

  /// Clears the callback dispatcher of [type] (defaults to IPv6).
  void clear({InternetAddressType type = InternetAddressType.IPv6});
}
