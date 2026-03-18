import 'package:callback_handler/callback_handler.dart';

import '../../types/stun_types.dart';

/// Manages the dual IPv4/IPv6 socket refresh callback dispatchers
class DualCallbackHandler {
  final IpCallbackHandler ipv4 = CallbackHandler();
  final IpCallbackHandler ipv6 = CallbackHandler();

  /// Returns the IPv4 socket-refresh callback to pass to handlers at creation/registration time
  OnSocketRefresh get onIpv4 => (newRes, oldRes) => ipv4((newRes, oldRes));

  /// Returns the IPv6 socket-refresh callback to pass to handlers at creation/registration time
  OnSocketRefresh get onIpv6 => (newRes, oldRes) => ipv6((newRes, oldRes));

  void registerIpv4(void Function((StunResponse, StunResponse?)) wrapper) => ipv4.register(wrapper);
  void registerIpv6(void Function((StunResponse, StunResponse?)) wrapper) => ipv6.register(wrapper);

  void clearIpv4() => ipv4.clear();
  void clearIpv6() => ipv6.clear();
}
