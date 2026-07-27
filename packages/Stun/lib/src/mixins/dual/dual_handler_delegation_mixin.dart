import 'dart:io';

import 'package:meta/meta.dart';

import '../../interfaces/dual/i_dual_stun_handler.dart';
import '../../interfaces/single/i_stun_handler.dart';
import '../../types/stun_types.dart';
import 'handler_selector_mixin.dart';

/// Internal-only behavior of `DualStunHandlerBase`: pure delegation to the dual
/// handler. The mixing class provides the DI-wired state ([dualHandler]).
/// Not part of the package's public API -- do not export it from `stun.dart`.
@internal
mixin DualHandlerDelegationMixin on HandlerSelectorMixin {
  /// Dual handler provided by the mixing class.
  IDualStunHandler get dualHandler;

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
  }

  void clearHandler({InternetAddressType type = InternetAddressType.IPv6}) =>
      dualHandler.clearHandler(type: type);

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
}
