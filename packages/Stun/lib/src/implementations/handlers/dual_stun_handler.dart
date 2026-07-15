import 'package:singleton_manager/singleton_manager.dart';
import '../../interfaces/i_stun_handler.dart';
import '../../interfaces/i_dual_stun_handler.dart';
import '../../mixins/destroyable_handler_mixin.dart';
import '../../mixins/dual_handler_selector_mixin.dart';
import '../../mixins/dual_stun_handler_mixin.dart';

/// Manages dual IPv4 and IPv6 STUN handlers with parallel request execution
class DualStunHandler
    with DestroyableHandlerMixin, DualHandlerSelectorMixin, DualStunHandlerMixin
    implements IDualStunHandler {
  IStunHandler? _ipv4Handler;
  IStunHandler? _ipv6Handler;

  @override
  IStunHandler? get ipv4Handler => _ipv4Handler;

  @override
  set ipv4Handler(IStunHandler? handler) => _ipv4Handler = handler;

  @override
  IStunHandler? get ipv6Handler => _ipv6Handler;

  @override
  set ipv6Handler(IStunHandler? handler) => _ipv6Handler = handler;

  @override
  Future<void> initializeDI() async {
    SingletonDIAccess.addInstanceAs<IDualStunHandler, DualStunHandler>(this);
    SingletonDI.registerFactory<DualStunHandler>(() => this);
    SingletonDIAccess.add<DualStunHandler>();
  }
}
