import 'dart:io';

import 'package:meta/meta.dart';
import '../../interfaces/dual/i_dual_stun_handler.dart';
import '../../interfaces/single/i_stun_handler.dart';
import '../../interfaces/i_stun_handler_base.dart';
import '../../mixins/destroyable_handler_mixin.dart';
import '../../mixins/dual/handler_selector_mixin.dart';
import '../../mixins/dual/dual_handler_delegation_mixin.dart';
import 'dual_stun_handler.dart';
import 'singleton_handler_factory.dart';

class DualStunHandlerBase
    with
        DestroyableHandlerMixin,
        HandlerSelectorMixin,
        DualHandlerDelegationMixin
    implements IStunHandlerBase {
  DualStunHandlerBase();

  @protected
  late IDualStunHandler dualHandlerProtected = DualStunHandler();

  @override
  IDualStunHandler get dualHandler => dualHandlerProtected;

  Future<void> initialize({
    String? address,
    int? port,
    Duration? timeout,
  }) async {
    const factory = SingletonHandlerFactory();

    IStunHandler? ipv4;
    try {
      ipv4 = await factory.createHandler(
        type: InternetAddressType.IPv4,
        address: address,
        port: port,
        timeout: timeout,
      );
    } catch (_) {}
    if (ipv4 != null) {
      dualHandlerProtected.setHandler(ipv4, type: InternetAddressType.IPv4);
    } else {
      dualHandlerProtected.clearHandler(type: InternetAddressType.IPv4);
    }

    IStunHandler? ipv6;
    try {
      ipv6 = await factory.createHandler(
        type: InternetAddressType.IPv6,
        address: address,
        port: port,
        timeout: timeout,
      );
    } catch (_) {}
    if (ipv6 != null) {
      dualHandlerProtected.setHandler(ipv6, type: InternetAddressType.IPv6);
    } else {
      dualHandlerProtected.clearHandler(type: InternetAddressType.IPv6);
    }

    if (ipv4 == null && ipv6 == null) {
      throw StateError(
        'DualStunHandlerSingleton: failed to initialize any handler '
        '(IPv4 and IPv6 both unavailable).',
      );
    }
  }

  Future<void> initializeWithHandlers(
    IStunHandler first, {
    IStunHandler? second,
  }) async {
    final firstVersion = first.getIpVersion();
    dualHandlerProtected.setHandler(first, type: firstVersion);

    if (second != null) {
      final secondVersion = second.getIpVersion();
      dualHandlerProtected.setHandler(second, type: secondVersion);
    }
  }
}
