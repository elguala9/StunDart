import 'dart:io';

import 'package:meta/meta.dart';

import '../interfaces/i_dual_callback_handler.dart';
import '../interfaces/i_dual_stun_handler.dart';
import '../interfaces/i_stun_handler.dart';
import '../types/stun_types.dart';
import 'handler_selector_mixin.dart';

/// Internal-only behavior of `DualStunHandlerBase`: pure delegation to the dual
/// handler and socket-refresh callback management. The mixing class provides
/// the DI-wired state ([dualHandler] and [callbacks]). Not part of the
/// package's public API � do not export it from `stun.dart`.
@internal
mixin DualHandlerDelegationMixin on HandlerSelectorMixin {
  /// Dual handler provided by the mixing class.
  IDualStunHandler get dualHandler;

  /// Callback dispatchers provided by the mixing class.
  IDualCallbackHandler get callbacks;

  @override
  IStunHandler? handler({required bool ipv6}) =>
      dualHandler.getHandler(ipv6: ipv6);

  @override
  String missingHandlerMessage({required bool ipv6}) =>
      'DualStunHandlerSingleton: ${ipv6 ? 'IPv6' : 'IPv4'} handler not initialized or not available. Call initialize() first.';

  void replaceHandler(
    IStunHandler handler, {
    bool ipv6 = true,
  }) {
    dualHandler.replaceHandler(handler, ipv6: ipv6);
  }

  Future<StunResponse> performStunRequest() =>
      dualHandler.performStunRequest();

  Future<LocalInfo> performLocalRequest() =>
      dualHandler.performLocalRequest();

  Future<bool> pingStunServer({
    bool ipv6 = true,
  }) => requireHandler(ipv6: ipv6).pingStunServer();

  RawDatagramSocket getSocket({
    bool ipv6 = true,
  }) => requireHandler(ipv6: ipv6).getSocket();

  void setStunServer(String address, int port, {bool? ipv6}) {
    dualHandler.setStunServer(address, port, ipv6: ipv6);
  }

  void close({bool? ipv6}) => dualHandler.close(ipv6: ipv6);

  DateTime? getLastStunUpdated({
    bool ipv6 = true,
  }) => dualHandler.getLastStunUpdated(ipv6: ipv6);

  DateTime? getLastLocalUpdated({
    bool ipv6 = true,
  }) => dualHandler.getLastLocalUpdated(ipv6: ipv6);

  DateTime? get lastStunUpdated => dualHandler.lastStunUpdated;

  DateTime? get lastLocalUpdated => dualHandler.lastLocalUpdated;

  IStunHandler? getHandler({
    bool ipv6 = true,
  }) => dualHandler.getHandler(ipv6: ipv6);

  void setHandler(
    IStunHandler handler, {
    bool ipv6 = true,
  }) {
    dualHandler.setHandler(handler, ipv6: ipv6);
    handler.addOnSocketRefresh(callbacks.getOn(type: ipv6 ? InternetAddressType.IPv6 : InternetAddressType.IPv4));
  }

  void clearHandler({bool ipv6 = true}) =>
      dualHandler.clearHandler(ipv6: ipv6);

  static void Function((StunResponse, StunResponse?)) _wrapCallback(
    void Function(StunResponse, StunResponse?) cb,
  ) =>
      (data) => cb(data.$1, data.$2);

  void setOnSocketRefresh(
    OnSocketRefresh callback, {
    bool ipv6 = true,
  }) {
    final handler = dualHandler.getHandler(ipv6: ipv6);
    if (handler == null) {
      throw StateError(
        'DualStunHandlerSingleton: ${ipv6 ? 'IPv6' : 'IPv4'} handler not '
        'initialized or not available. Call initialize() first and ensure '
        '${ipv6 ? 'IPv6' : 'IPv4'} is available on this system.',
      );
    }

    final expected = ipv6 ? InternetAddressType.IPv6 : InternetAddressType.IPv4;
    final socket = handler.getSocket();
    if (socket.address.type != expected) {
      throw ArgumentError(
        'Socket type mismatch: expected ${ipv6 ? 'IPv6' : 'IPv4'}, got '
        '${socket.address.type}. Ensure the handler has an '
        '${ipv6 ? 'IPv6' : 'IPv4'} socket.',
      );
    }

    callbacks.register(
      _wrapCallback(callback),
      type: ipv6 ? InternetAddressType.IPv6 : InternetAddressType.IPv4,
    );
  }

  void clearOnSocketRefresh({
    bool ipv6 = true,
  }) => callbacks.clear(type: ipv6 ? InternetAddressType.IPv6 : InternetAddressType.IPv4);

  void addOnSocketRefresh(OnSocketRefresh callback) {
    dualHandler
        .getHandler(ipv6: false)
        ?.addOnSocketRefresh(callback);
    dualHandler
        .getHandler(ipv6: true)
        ?.addOnSocketRefresh(callback);
  }

  void removeOnSocketRefresh(OnSocketRefresh callback) {
    dualHandler
        .getHandler(ipv6: false)
        ?.removeOnSocketRefresh(callback);
    dualHandler
        .getHandler(ipv6: true)
        ?.removeOnSocketRefresh(callback);
  }

  IStunHandler? get ipv4Handler =>
      getHandler(ipv6: false);

  IStunHandler? get ipv6Handler =>
      getHandler(ipv6: true);

  DateTime? get ipv4LastStunUpdated =>
      getLastStunUpdated(ipv6: false);

  DateTime? get ipv6LastStunUpdated =>
      getLastStunUpdated(ipv6: true);

  DateTime? get ipv4LastLocalUpdated =>
      getLastLocalUpdated(ipv6: false);

  DateTime? get ipv6LastLocalUpdated =>
      getLastLocalUpdated(ipv6: true);

  void setOnSocketRefreshIpv4(OnSocketRefresh callback) =>
      setOnSocketRefresh(callback, ipv6: false);

  void setOnSocketRefreshIpv6(OnSocketRefresh callback) =>
      setOnSocketRefresh(callback, ipv6: true);

  void removeOnSocketRefreshIpv4([OnSocketRefresh? callback]) {
    if (callback != null) {
      dualHandler
          .getHandler(ipv6: false)
          ?.removeOnSocketRefresh(callback);
    } else {
      clearOnSocketRefresh(ipv6: false);
    }
  }

  void removeOnSocketRefreshIpv6([OnSocketRefresh? callback]) {
    if (callback != null) {
      dualHandler
          .getHandler(ipv6: true)
          ?.removeOnSocketRefresh(callback);
    } else {
      clearOnSocketRefresh(ipv6: true);
    }
  }
}
