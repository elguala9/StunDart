import 'dart:io';

import 'package:callback_handler/callback_handler.dart';

import '../../types/stun_types.dart';
import '../../interfaces/i_dual_callback_handler.dart';

/// Manages the dual IPv4/IPv6 socket refresh callback dispatchers
class DualCallbackHandler implements IDualCallbackHandler {
  final IpCallbackHandler _ipv4Callback = CallbackHandler();
  final IpCallbackHandler _ipv6Callback = CallbackHandler();

  IpCallbackHandler _dispatcher(InternetAddressType type) =>
      type == InternetAddressType.IPv4 ? _ipv4Callback : _ipv6Callback;

  @override
  OnSocketRefresh getOn({InternetAddressType type = InternetAddressType.IPv6}) {
    final dispatcher = _dispatcher(type);
    return (newRes, oldRes) => dispatcher((newRes, oldRes));
  }

  @override
  void register(
    void Function((StunResponse, StunResponse?)) wrapper, {
    InternetAddressType type = InternetAddressType.IPv6,
  }) =>
      _dispatcher(type).register(wrapper);

  @override
  void clear({InternetAddressType type = InternetAddressType.IPv6}) =>
      _dispatcher(type).clear();
}
