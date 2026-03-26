import 'dart:io';

import 'package:meta/meta.dart';
import 'package:singleton_manager/singleton_manager.dart';
import '../../interfaces/i_dual_callback_handler.dart';
import '../../interfaces/i_dual_stun_handler.dart';
import '../../interfaces/i_stun_handler.dart';
import '../../types/stun_types.dart';
import '../handlers/dual_stun_handler.dart';
import 'dual_callback_handler.dart';
import 'singleton_handler_factory.dart';

@isSingleton
class StunHandlerBase {
  @isInjected
  @protected
  late IDualStunHandler dualHandlerProtected = DualStunHandler();

  IDualStunHandler get dualHandler => dualHandlerProtected;

  @isInjected
  @protected
  late IDualCallbackHandler callbacks = DualCallbackHandler();

  

  IStunHandler _getHandler({required bool ipv6}) {
    if (ipv6) {
      if (dualHandlerProtected.ipv6Handler == null) {
        throw StateError(
          'StunHandlerSingleton: IPv6 handler not initialized or not available. Call initialize() first.',
        );
      }
      return dualHandlerProtected.ipv6Handler!;
    } else {
      if (dualHandlerProtected.ipv4Handler == null) {
        throw StateError(
          'StunHandlerSingleton: IPv4 handler not initialized. Call initialize() first.',
        );
      }
      return dualHandlerProtected.ipv4Handler!;
    }
  }

  IStunHandler get ipv4Handler => _getHandler(ipv6: false);
  IStunHandler? get ipv6Handler => dualHandlerProtected.ipv6Handler;

  void replaceHandler(IStunHandler handler, {required bool ipv6}) {
    dualHandlerProtected.replaceHandler(handler, ipv6: ipv6);
  }

  Future<StunResponse> performStunRequest() async {
    if (dualHandlerProtected.ipv4Handler == null) {
      throw StateError(
        'StunHandlerSingleton: IPv4 handler not initialized. Call initialize() first.',
      );
    }
    return dualHandlerProtected.performStunRequest();
  }

  Future<LocalInfo> performLocalRequest() async {
    if (dualHandlerProtected.ipv4Handler == null) {
      throw StateError(
        'StunHandlerSingleton: IPv4 handler not initialized. Call initialize() first.',
      );
    }
    return dualHandlerProtected.performLocalRequest();
  }

  Future<bool> pingStunServer({bool ipv6 = true}) =>
      _getHandler(ipv6: ipv6).pingStunServer();

  RawDatagramSocket getSocket({bool ipv6 = true}) =>
      _getHandler(ipv6: ipv6).getSocket();

  void setStunServer(String address, int port, {bool? ipv6}) {
    dualHandlerProtected.setStunServer(address, port, ipv6: ipv6);
  }

  void close({bool? ipv6}) => dualHandlerProtected.close(ipv6: ipv6);

  DateTime? get ipv4LastStunUpdated => dualHandlerProtected.ipv4LastStunUpdated;
  DateTime? get ipv6LastStunUpdated => dualHandlerProtected.ipv6LastStunUpdated;
  DateTime? get ipv4LastLocalUpdated =>
      dualHandlerProtected.ipv4LastLocalUpdated;
  DateTime? get ipv6LastLocalUpdated =>
      dualHandlerProtected.ipv6LastLocalUpdated;
  DateTime? get lastStunUpdated => dualHandlerProtected.lastStunUpdated;
  DateTime? get lastLocalUpdated => dualHandlerProtected.lastLocalUpdated;

  Future<void> initializeDualHandlerDI() => dualHandlerProtected.initializeDI();

  Future<void> initialize({
    String? address,
    int? port,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    const factory = SingletonHandlerFactory();

    dualHandlerProtected.setIpv4Handler(
      await factory.createIpv4Handler(
        address: address,
        port: port,
        timeout: timeout,
        onSocketRefresh: callbacks.onIpv4,
      ),
    );

    IStunHandler? ipv6;
    try {
      ipv6 = await factory.createIpv6Handler(
        address: address,
        port: port,
        timeout: timeout,
        onSocketRefresh: callbacks.onIpv6,
      );
    } catch (_) {}
    dualHandlerProtected.setIpv6Handler(ipv6);
  }

  Future<void> initializeWithHandlers(
    IStunHandler ipv4Handler, {
    IStunHandler? ipv6Handler,
  }) async {
    dualHandlerProtected.setIpv4Handler(ipv4Handler);
    ipv4Handler.addOnSocketRefresh(callbacks.onIpv4);
    dualHandlerProtected.setIpv6Handler(ipv6Handler);
    if (ipv6Handler != null) ipv6Handler.addOnSocketRefresh(callbacks.onIpv6);
  }

  void setIpv4Handler(IStunHandler handler) {
    dualHandlerProtected.setIpv4Handler(handler);
    handler.addOnSocketRefresh(callbacks.onIpv4);
  }

  void setIpv6Handler(IStunHandler? handler) {
    dualHandlerProtected.setIpv6Handler(handler);
    if (handler != null) handler.addOnSocketRefresh(callbacks.onIpv6);
  }

  static void Function((StunResponse, StunResponse?)) _wrapCallback(
    void Function(StunResponse, StunResponse?) cb,
  ) =>
      (data) => cb(data.$1, data.$2);

  void setOnSocketRefreshIpv4(OnSocketRefreshIpv4 callback) {
    final handler = dualHandlerProtected.ipv4Handler;
    if (handler == null) {
      throw StateError(
        'StunHandlerSingleton: IPv4 handler not initialized. Call initialize() first.',
      );
    }

    final socket = handler.getSocket();
    if (socket.address.type != InternetAddressType.IPv4) {
      throw ArgumentError(
        'Socket type mismatch: expected IPv4, got ${socket.address.type}. '
        'Ensure the handler has an IPv4 socket.',
      );
    }

    callbacks.registerIpv4(_wrapCallback(callback));
  }

  void setOnSocketRefreshIpv6(OnSocketRefreshIpv6 callback) {
    final handler = dualHandlerProtected.ipv6Handler;
    if (handler == null) {
      throw StateError(
        'StunHandlerSingleton: IPv6 handler not initialized or not available. '
        'Call initialize() first and ensure IPv6 is available on this system.',
      );
    }

    final socket = handler.getSocket();
    if (socket.address.type != InternetAddressType.IPv6) {
      throw ArgumentError(
        'Socket type mismatch: expected IPv6, got ${socket.address.type}. '
        'Ensure the handler has an IPv6 socket.',
      );
    }

    callbacks.registerIpv6(_wrapCallback(callback));
  }

  void removeOnSocketRefreshIpv4() => callbacks.clearIpv4();
  void removeOnSocketRefreshIpv6() => callbacks.clearIpv6();
}
