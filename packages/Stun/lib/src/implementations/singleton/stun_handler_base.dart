import 'package:meta/meta.dart';
import 'package:singleton_manager/singleton_manager.dart';
import '../../interfaces/i_dual_callback_handler.dart';
import '../../interfaces/i_dual_stun_handler.dart';
import '../../interfaces/i_stun_handler.dart';
import '../../interfaces/i_stun_handler_base.dart';
import '../../mixins/destroyable_handler_mixin.dart';
import '../../mixins/dual_handler_selector_mixin.dart';
import '../../mixins/stun_handler_base_mixin.dart';
import '../handlers/dual_stun_handler.dart';
import 'dual_callback_handler.dart';
import 'singleton_handler_factory.dart';

@isSingleton
class StunHandlerBase
    with
        ValueForRegistry,
        DestroyableHandlerMixin,
        DualHandlerSelectorMixin,
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

  Future<void> initializeDualHandlerDI() => dualHandlerProtected.initializeDI();

  @override
  Future<void> initialize({
    String? address,
    int? port,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    const factory = SingletonHandlerFactory();

    IStunHandler? ipv4;
    try {
      ipv4 = await factory.createIpv4Handler(
        address: address,
        port: port,
        timeout: timeout,
        onSocketRefresh: callbacks.onIpv4,
      );
    } catch (_) {}
    if (ipv4 != null) {
      dualHandlerProtected.setIpv4Handler(ipv4);
    } else {
      dualHandlerProtected.clearIpv4Handler();
    }

    IStunHandler? ipv6;
    try {
      ipv6 = await factory.createIpv6Handler(
        address: address,
        port: port,
        timeout: timeout,
        onSocketRefresh: callbacks.onIpv6,
      );
    } catch (_) {}
    if (ipv6 != null) {
      dualHandlerProtected.setIpv6Handler(ipv6);
    } else {
      dualHandlerProtected.clearIpv6Handler();
    }

    if (ipv4 == null && ipv6 == null) {
      throw StateError(
        'StunHandlerSingleton: failed to initialize any handler '
        '(IPv4 and IPv6 both unavailable).',
      );
    }
  }

  @override
  Future<void> initializeWithHandlers(
    IStunHandler ipv4Handler, {
    IStunHandler? ipv6Handler,
  }) async {
    dualHandlerProtected.setIpv4Handler(ipv4Handler);
    ipv4Handler.addOnSocketRefresh(callbacks.onIpv4);
    if (ipv6Handler != null) {
      dualHandlerProtected.setIpv6Handler(ipv6Handler);
      ipv6Handler.addOnSocketRefresh(callbacks.onIpv6);
    } else {
      dualHandlerProtected.clearIpv6Handler();
    }
  }
}
