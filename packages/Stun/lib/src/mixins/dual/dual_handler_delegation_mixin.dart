import 'dart:io';

import 'package:meta/meta.dart';

import '../../interfaces/dual/i_dual_callback_handler.dart';
import '../../interfaces/dual/i_dual_stun_handler.dart';
import '../../interfaces/single/i_stun_handler.dart';
import '../../types/stun_types.dart';
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
  IStunHandler? handler({required InternetAddressType type}) =>
      dualHandler.getHandler(type: type);

  @override
  String missingHandlerMessage({required InternetAddressType type}) =>
      'DualStunHandlerSingleton: ${type == InternetAddressType.IPv6 ? 'IPv6' : 'IPv4'} handler not initialized or not available. Call initialize() first.';

  void replaceHandler(
    IStunHandler handler, {
    InternetAddressType type = InternetAddressType.IPv6,
  }) {
    dualHandler.replaceHandler(handler, type: type);
  }

  Future<StunResponse> performStunRequest() =>
      dualHandler.performStunRequest();

  Future<LocalInfo> performLocalRequest() =>
      dualHandler.performLocalRequest();

  Future<bool> pingStunServer({
    InternetAddressType type = InternetAddressType.IPv6,
  }) => requireHandler(type: type).pingStunServer();

  RawDatagramSocket getSocket({
    InternetAddressType type = InternetAddressType.IPv6,
  }) => requireHandler(type: type).getSocket();

  void setStunServer(String address, int port, {InternetAddressType? type}) {
    dualHandler.setStunServer(address, port, type: type);
  }

  void close({InternetAddressType? type}) => dualHandler.close(type: type);

  DateTime? getLastStunUpdated({
    InternetAddressType type = InternetAddressType.IPv6,
  }) => dualHandler.getLastStunUpdated(type: type);

  DateTime? getLastLocalUpdated({
    InternetAddressType type = InternetAddressType.IPv6,
  }) => dualHandler.getLastLocalUpdated(type: type);

  DateTime? get lastStunUpdated => dualHandler.lastStunUpdated;

  DateTime? get lastLocalUpdated => dualHandler.lastLocalUpdated;

  IStunHandler? getHandler({
    InternetAddressType type = InternetAddressType.IPv6,
  }) => dualHandler.getHandler(type: type);

  void setHandler(
    IStunHandler handler, {
    InternetAddressType type = InternetAddressType.IPv6,
  }) {
    dualHandler.setHandler(handler, type: type);
    handler.addOnSocketRefresh(callbacks.getOn(type: type));
  }

  void clearHandler({InternetAddressType type = InternetAddressType.IPv6}) =>
      dualHandler.clearHandler(type: type);

  static void Function((StunResponse, StunResponse?)) _wrapCallback(
    void Function(StunResponse, StunResponse?) cb,
  ) =>
      (data) => cb(data.$1, data.$2);

  void setOnSocketRefresh(
    OnSocketRefresh callback, {
    InternetAddressType type = InternetAddressType.IPv6,
  }) {
    final handler = dualHandler.getHandler(type: type);
    if (handler == null) {
      throw StateError(
        'DualStunHandlerSingleton: ${type == InternetAddressType.IPv6 ? 'IPv6' : 'IPv4'} handler not '
        'initialized or not available. Call initialize() first and ensure '
        '${type == InternetAddressType.IPv6 ? 'IPv6' : 'IPv4'} is available on this system.',
      );
    }

    final expected = type;
    final socket = handler.getSocket();
    if (socket.address.type != expected) {
      throw ArgumentError(
        'Socket type mismatch: expected ${type == InternetAddressType.IPv6 ? 'IPv6' : 'IPv4'}, got '
        '${socket.address.type}. Ensure the handler has an '
        '${type == InternetAddressType.IPv6 ? 'IPv6' : 'IPv4'} socket.',
      );
    }

    callbacks.register(
      _wrapCallback(callback),
      type: type,
    );
  }

  void clearOnSocketRefresh({
    InternetAddressType type = InternetAddressType.IPv6,
  }) => callbacks.clear(type: type);

  void addOnSocketRefresh(OnSocketRefresh callback) {
    dualHandler
        .getHandler(type: InternetAddressType.IPv4)
        ?.addOnSocketRefresh(callback);
    dualHandler
        .getHandler(type: InternetAddressType.IPv6)
        ?.addOnSocketRefresh(callback);
  }

  void removeOnSocketRefresh(OnSocketRefresh callback) {
    dualHandler
        .getHandler(type: InternetAddressType.IPv4)
        ?.removeOnSocketRefresh(callback);
    dualHandler
        .getHandler(type: InternetAddressType.IPv6)
        ?.removeOnSocketRefresh(callback);
  }

  IStunHandler? get ipv4Handler =>
      getHandler(type: InternetAddressType.IPv4);

  IStunHandler? get ipv6Handler =>
      getHandler(type: InternetAddressType.IPv6);

  DateTime? get ipv4LastStunUpdated =>
      getLastStunUpdated(type: InternetAddressType.IPv4);

  DateTime? get ipv6LastStunUpdated =>
      getLastStunUpdated(type: InternetAddressType.IPv6);

  DateTime? get ipv4LastLocalUpdated =>
      getLastLocalUpdated(type: InternetAddressType.IPv4);

  DateTime? get ipv6LastLocalUpdated =>
      getLastLocalUpdated(type: InternetAddressType.IPv6);

  void setOnSocketRefreshIpv4(OnSocketRefresh callback) =>
      setOnSocketRefresh(callback, type: InternetAddressType.IPv4);

  void setOnSocketRefreshIpv6(OnSocketRefresh callback) =>
      setOnSocketRefresh(callback, type: InternetAddressType.IPv6);

  void removeOnSocketRefreshIpv4([OnSocketRefresh? callback]) {
    if (callback != null) {
      dualHandler
          .getHandler(type: InternetAddressType.IPv4)
          ?.removeOnSocketRefresh(callback);
    } else {
      clearOnSocketRefresh(type: InternetAddressType.IPv4);
    }
  }

  void removeOnSocketRefreshIpv6([OnSocketRefresh? callback]) {
    if (callback != null) {
      dualHandler
          .getHandler(type: InternetAddressType.IPv6)
          ?.removeOnSocketRefresh(callback);
    } else {
      clearOnSocketRefresh(type: InternetAddressType.IPv6);
    }
  }
}
