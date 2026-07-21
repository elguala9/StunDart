import 'package:singleton_manager/singleton_manager.dart';
import '../../interfaces/i_stun_handler.dart';
import '../../interfaces/i_dual_stun_handler.dart';
import '../../mixins/destroyable_handler_mixin.dart';
import '../../mixins/handler_selector_mixin.dart';
import '../../mixins/dual_stun_handler_mixin.dart';
import '../../types/stun_types.dart';

/// Manages dual IPv4 and IPv6 STUN handlers with parallel request execution
class DualStunHandler
    with DestroyableHandlerMixin, HandlerSelectorMixin, DualStunHandlerMixin
    implements IDualStunHandler {
  IStunHandler? _ipv4Handler;
  IStunHandler? _ipv6Handler;

  @override
  IStunHandler? handler({required bool ipv6}) =>
      ipv6 ? _ipv6Handler : _ipv4Handler;

  @override
  void setHandlerSlot(IStunHandler? h, {required bool ipv6}) {
    if (ipv6) {
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
  Future<void> initialize({
    String? address,
    int? port,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    throw UnsupportedError(
      'DualStunHandler is a low-level container. '
      'Use StunHandlerBase.initialize() instead.',
    );
  }

  @override
  Future<void> initializeWithHandlers(
    IStunHandler ipv4Handler, {
    IStunHandler? ipv6Handler,
  }) async {
    setHandler(ipv4Handler, ipv6: false);
    if (ipv6Handler != null) {
      setHandler(ipv6Handler, ipv6: true);
    } else {
      clearHandler(ipv6: true);
    }
  }

  @override
  void setOnSocketRefresh(
    OnSocketRefresh callback, {
    bool ipv6 = true,
  }) {
    final h = getHandler(ipv6: ipv6);
    if (h == null) {
      throw StateError(
        'DualStunHandler: ${ipv6 ? 'IPv6' : 'IPv4'} '
        'handler not initialized.',
      );
    }
    h.addOnSocketRefresh(callback);
  }

  @override
  void clearOnSocketRefresh({
    bool ipv6 = true,
  }) {
    return;
  }

  @override
  void addOnSocketRefresh(OnSocketRefresh callback) {
    throw UnsupportedError(
      'DualStunHandler does not support untyped addOnSocketRefresh. '
      'Use setOnSocketRefresh with an explicit type, or call '
      'addOnSocketRefresh directly on the individual IStunHandler.',
    );
  }

  @override
  void removeOnSocketRefresh(OnSocketRefresh callback) {
    throw UnsupportedError(
      'DualStunHandler does not support untyped removeOnSocketRefresh. '
      'Use clearOnSocketRefresh with an explicit type, or call '
      'removeOnSocketRefresh directly on the individual IStunHandler.',
    );
  }
}
