import 'dart:io';

import 'package:stun/stun.dart';

/// Interface for managing dual IPv4 and IPv6 STUN handlers
/// Handles parallel request execution and state management
abstract class IDualStunHandlerMigratable implements IDualStunHandler {
  void migrateTo(
    IDualStunHandler stunHandler, {
    InternetAddressType type = InternetAddressType.IPv6,
  });
}
