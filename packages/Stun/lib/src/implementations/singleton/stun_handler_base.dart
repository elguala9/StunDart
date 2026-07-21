import 'dart:io';

import 'package:meta/meta.dart';
import 'package:singleton_manager/singleton_manager.dart';
import '../../interfaces/i_dual_callback_handler.dart';
import '../../interfaces/i_dual_stun_handler.dart';
import '../../interfaces/i_stun_handler.dart';
import '../../interfaces/i_stun_handler_base.dart';
import '../../mixins/destroyable_handler_mixin.dart';
import '../../mixins/handler_selector_mixin.dart';
import '../../mixins/stun_handler_base_mixin.dart';
import '../handlers/dual_stun_handler.dart';
import 'dual_callback_handler.dart';
import 'singleton_handler_factory.dart';

@isSingleton
class StunHandlerBase
    with
        ValueForRegistry,
        DestroyableHandlerMixin,
        HandlerSelectorMixin,
        StunHandlerBaseMixin
    implements IStunHandlerBase {
  @isInjected
  @protected
  late IDualStunHandler dualHandlerProtected = DualStunHandler();

  @override
  IDualStunHandler get dualHandler => dualHandlerProtected;

  @isInjected
  @protected
  @override
  late IDualCallbackHandler callbacks = DualCallbackHandler();

  Future<void> initializeDualHandlerDI() async {
    dualHandlerProtected.initializeDI();
  }

  Future<void> initialize({
    String? address,
    int? port,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    const factory = SingletonHandlerFactory();

    IStunHandler? ipv4;
    try {
      ipv4 = await factory.createHandler(
        ipv6: false,
        address: address,
        port: port,
        timeout: timeout,
        onSocketRefresh: callbacks.getOn(type: InternetAddressType.IPv4),
      );
    } catch (_) {}
    if (ipv4 != null) {
      dualHandlerProtected.setHandler(ipv4, ipv6: false);
    } else {
      dualHandlerProtected.clearHandler(ipv6: false);
    }

    IStunHandler? ipv6;
    try {
      ipv6 = await factory.createHandler(
        ipv6: true,
        address: address,
        port: port,
        timeout: timeout,
        onSocketRefresh: callbacks.getOn(type: InternetAddressType.IPv6),
      );
    } catch (_) {}
    if (ipv6 != null) {
      dualHandlerProtected.setHandler(ipv6, ipv6: true);
    } else {
      dualHandlerProtected.clearHandler(ipv6: true);
    }

    if (ipv4 == null && ipv6 == null) {
      throw StateError(
        'StunHandlerSingleton: failed to initialize any handler '
        '(IPv4 and IPv6 both unavailable).',
      );
    }
  }

  Future<void> initializeWithHandlers(
    IStunHandler ipv4Handler, {
    IStunHandler? ipv6Handler,
  }) async {
    dualHandlerProtected.setHandler(ipv4Handler, ipv6: false);
    ipv4Handler.addOnSocketRefresh(callbacks.getOn(type: InternetAddressType.IPv4));
    if (ipv6Handler != null) {
      dualHandlerProtected.setHandler(
        ipv6Handler,
        ipv6: true,
      );
      ipv6Handler
          .addOnSocketRefresh(callbacks.getOn(type: InternetAddressType.IPv6));
    } else {
      dualHandlerProtected.clearHandler(ipv6: true);
    }
  }
}
