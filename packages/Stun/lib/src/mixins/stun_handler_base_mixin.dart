import 'dart:io';

import 'package:meta/meta.dart';

import '../interfaces/i_dual_callback_handler.dart';
import '../interfaces/i_dual_stun_handler.dart';
import '../interfaces/i_stun_handler.dart';
import '../types/stun_types.dart';
import 'dual_handler_selector_mixin.dart';

/// Internal-only behavior of `StunHandlerBase`: pure delegation to the dual
/// handler and socket-refresh callback management. The mixing class provides
/// the DI-wired state ([dualHandler] and [callbacks]). Not part of the
/// package's public API — do not export it from `stun.dart`.
@internal
mixin StunHandlerBaseMixin on DualHandlerSelectorMixin {
  /// Dual handler provided by the mixing class.
  IDualStunHandler get dualHandler;

  /// Callback dispatchers provided by the mixing class.
  IDualCallbackHandler get callbacks;

  @override
  IStunHandler? get ipv4Handler => dualHandler.ipv4Handler;

  @override
  IStunHandler? get ipv6Handler => dualHandler.ipv6Handler;

  @override
  String missingHandlerMessage({required bool ipv6}) =>
      'StunHandlerSingleton: ${ipv6 ? 'IPv6' : 'IPv4'} handler not initialized or not available. Call initialize() first.';

  void replaceHandler(IStunHandler handler, {required bool ipv6}) {
    dualHandler.replaceHandler(handler, ipv6: ipv6);
  }

  Future<StunDualResponse> performStunRequest() =>
      dualHandler.performStunRequest();

  Future<LocalDualInfo> performLocalRequest() =>
      dualHandler.performLocalRequest();

  Future<bool> pingStunServer({bool ipv6 = true}) =>
      requireHandler(ipv6: ipv6).pingStunServer();

  RawDatagramSocket getSocket({bool ipv6 = true}) =>
      requireHandler(ipv6: ipv6).getSocket();

  void setStunServer(String address, int port, {bool? ipv6}) {
    dualHandler.setStunServer(address, port, ipv6: ipv6);
  }

  void close({bool? ipv6}) => dualHandler.close(ipv6: ipv6);

  DateTime? get ipv4LastStunUpdated => dualHandler.ipv4LastStunUpdated;

  DateTime? get ipv6LastStunUpdated => dualHandler.ipv6LastStunUpdated;

  DateTime? get ipv4LastLocalUpdated => dualHandler.ipv4LastLocalUpdated;

  DateTime? get ipv6LastLocalUpdated => dualHandler.ipv6LastLocalUpdated;

  DateTime? get lastStunUpdated => dualHandler.lastStunUpdated;

  DateTime? get lastLocalUpdated => dualHandler.lastLocalUpdated;

  void setIpv4Handler(IStunHandler handler) {
    dualHandler.setIpv4Handler(handler);
    handler.addOnSocketRefresh(callbacks.onIpv4);
  }

  void setIpv6Handler(IStunHandler handler) {
    dualHandler.setIpv6Handler(handler);
    handler.addOnSocketRefresh(callbacks.onIpv6);
  }

  void clearIpv4Handler() => dualHandler.clearIpv4Handler();

  void clearIpv6Handler() => dualHandler.clearIpv6Handler();

  static void Function((StunResponse, StunResponse?)) _wrapCallback(
    void Function(StunResponse, StunResponse?) cb,
  ) =>
      (data) => cb(data.$1, data.$2);

  void setOnSocketRefreshIpv4(OnSocketRefreshIpv4 callback) {
    final handler = dualHandler.ipv4Handler;
    if (handler == null) {
      throw StateError(
        'StunHandlerSingleton: IPv4 handler not initialized or not available. '
        'Call initialize() first and ensure IPv4 is available on this system.',
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
    final handler = dualHandler.ipv6Handler;
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
