import 'dart:io';

import '../../interfaces/single/i_stun_handler.dart';
import '../../interfaces/dual/i_dual_stun_handler.dart';
import '../../mixins/destroyable_handler_mixin.dart';
import '../../mixins/dual/handler_selector_mixin.dart';
import '../../mixins/dual/dual_stun_handler_mixin.dart';
import 'package:singleton_manager/singleton_manager.dart';

@dependencyInjectable
/// Manages dual IPv4 and IPv6 STUN handlers with parallel request execution
class DualStunHandler
    with DestroyableHandlerMixin, HandlerSelectorMixin, DualStunHandlerMixin
    implements IDualStunHandler {
  DualStunHandler({IStunHandler? ipv4Handler, IStunHandler? ipv6Handler}) {
    _ipv4Handler = ipv4Handler;
    _ipv6Handler = ipv6Handler;
  }

  IStunHandler? _ipv4Handler;
  IStunHandler? _ipv6Handler;

  @override
  IStunHandler? handler({required InternetAddressType type}) =>
      type == InternetAddressType.IPv4 ? _ipv4Handler : _ipv6Handler;

  @override
  void setHandlerSlot(IStunHandler? h, {required InternetAddressType type}) {
    if (type == InternetAddressType.IPv4) {
      _ipv4Handler = h;
    } else {
      _ipv6Handler = h;
    }
  }

  @override
  Future<void> initializeWithHandlers(
    IStunHandler first, {
    IStunHandler? second,
  }) async {
    setHandler(first, type: first.getIpVersion());
    if (second != null) {
      setHandler(second, type: second.getIpVersion());
    }
  }
}
