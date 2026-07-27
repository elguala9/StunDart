import 'dart:io';

import 'package:singleton_manager/singleton_manager.dart';
import '../../interfaces/single/i_stun_handler.dart';
import '../../interfaces/dual/i_dual_stun_handler.dart';
import '../../mixins/destroyable_handler_mixin.dart';
import '../../mixins/dual/handler_selector_mixin.dart';
import '../../mixins/dual/dual_stun_handler_mixin.dart';

/// Manages dual IPv4 and IPv6 STUN handlers with parallel request execution
class DualStunHandler
    with DestroyableHandlerMixin, HandlerSelectorMixin, DualStunHandlerMixin
    implements IDualStunHandler {
  IStunHandler? _ipv4Handler;
  IStunHandler? _ipv6Handler;

  @override
  IStunHandler? handler({required InternetAddressType type}) =>
      type == InternetAddressType.IPv6 ? _ipv6Handler : _ipv4Handler;

  @override
  void setHandlerSlot(IStunHandler? h, {required InternetAddressType type}) {
    if (type == InternetAddressType.IPv6) {
      _ipv6Handler = h;
    } else {
      _ipv4Handler = h;
    }
  }

  @override
  Future<void> initializeDI() async {
    SingletonDIAccess.addInstanceAs<IDualStunHandler, DualStunHandler>(this);
    SingletonDI.registerFactory<DualStunHandler>(() => this);
    SingletonDIAccess.add<DualStunHandler>();
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
