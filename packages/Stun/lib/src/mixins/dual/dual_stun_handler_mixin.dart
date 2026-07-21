import 'dart:io';

import 'package:meta/meta.dart';

import '../../interfaces/single/i_stun_handler.dart';
import '../../types/stun_types.dart' show StunResponse, LocalInfo;
import 'handler_selector_mixin.dart';

Future<T?> _safeCall<T>(Future<T>? future) {
  if (future == null) return Future.value(null);
  return future.then<T?>((r) => r).catchError((_) => null);
}

DateTime? _laterOf(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isAfter(b) ? a : b;
}

/// Internal-only behavior of `DualStunHandler`: parallel dual dispatch,
/// slot validation and broadcast operations. The mixing class provides the
/// two handler slots. Not part of the package's public API — do not export
/// it from `stun.dart`.
@internal
mixin DualStunHandlerMixin on HandlerSelectorMixin {
  void setHandlerSlot(IStunHandler? handler, {required InternetAddressType type});

  @override
  String missingHandlerMessage({required InternetAddressType type}) =>
      'DualStunHandler: ${type == InternetAddressType.IPv6 ? 'IPv6' : 'IPv4'} handler not initialized or not available';

  void setHandler(
    IStunHandler handler, {
    InternetAddressType type = InternetAddressType.IPv6,
  }) {
    final expected = type;
    if (handler.getSocket().address.type != expected) {
      throw ArgumentError(
        'DualStunHandler: expected an ${type == InternetAddressType.IPv6 ? 'IPv6' : 'IPv4'} socket, got '
        '${handler.getSocket().address.type}.',
      );
    }
    setHandlerSlot(handler, type: type);
  }

  void clearHandler({InternetAddressType type = InternetAddressType.IPv6}) {
    setHandlerSlot(null, type: type);
  }

  IStunHandler? getHandler({
    InternetAddressType type = InternetAddressType.IPv6,
  }) => handler(type: type);

  void replaceHandler(
    IStunHandler handler, {
    InternetAddressType type = InternetAddressType.IPv6,
  }) => setHandler(handler, type: type);

  Future<StunResponse> performStunRequest() async {
    final v4 = handler(type: InternetAddressType.IPv4);
    final v6 = handler(type: InternetAddressType.IPv6);
    if (v4 == null && v6 == null) {
      throw StateError('DualStunHandler: no handler initialized');
    }

    final ipv4Future = _safeCall(v4?.performStunRequest());
    final ipv6Future = _safeCall(v6?.performStunRequest());

    final ipv4Result = await ipv4Future;
    final ipv6Result = await ipv6Future;

    return StunResponse.merge(ipv4Result, ipv6Result);
  }

  Future<LocalInfo> performLocalRequest() async {
    final v4 = handler(type: InternetAddressType.IPv4);
    final v6 = handler(type: InternetAddressType.IPv6);
    if (v4 == null && v6 == null) {
      throw StateError('DualStunHandler: no handler initialized');
    }

    final ipv4Future = _safeCall(v4?.performLocalRequest());
    final ipv6Future = _safeCall(v6?.performLocalRequest());

    final ipv4Result = await ipv4Future;
    final ipv6Result = await ipv6Future;

    return LocalInfo.merge(ipv4Result, ipv6Result);
  }

  Future<bool> pingStunServer({
    InternetAddressType type = InternetAddressType.IPv6,
  }) => requireHandler(type: type).pingStunServer();

  RawDatagramSocket getSocket({
    InternetAddressType type = InternetAddressType.IPv6,
  }) => requireHandler(type: type).getSocket();

  void setStunServer(String address, int port, {InternetAddressType? type}) {
    if (type == null || type == InternetAddressType.IPv4) {
      handler(type: InternetAddressType.IPv4)?.setStunServer(address, port);
    }
    if (type == null || type == InternetAddressType.IPv6) {
      handler(type: InternetAddressType.IPv6)?.setStunServer(address, port);
    }
  }

  void close({InternetAddressType? type}) {
    if (type == null || type == InternetAddressType.IPv4) {
      handler(type: InternetAddressType.IPv4)?.close();
      setHandlerSlot(null, type: InternetAddressType.IPv4);
    }
    if (type == null || type == InternetAddressType.IPv6) {
      handler(type: InternetAddressType.IPv6)?.close();
      setHandlerSlot(null, type: InternetAddressType.IPv6);
    }
  }

  DateTime? getLastStunUpdated({
    InternetAddressType type = InternetAddressType.IPv6,
  }) => handler(type: type)?.lastStunUpdated;

  DateTime? getLastLocalUpdated({
    InternetAddressType type = InternetAddressType.IPv6,
  }) => handler(type: type)?.lastLocalUpdated;

  DateTime? get lastStunUpdated =>
      _laterOf(handler(type: InternetAddressType.IPv4)?.lastStunUpdated, handler(type: InternetAddressType.IPv6)?.lastStunUpdated);

  DateTime? get lastLocalUpdated =>
      _laterOf(handler(type: InternetAddressType.IPv4)?.lastLocalUpdated, handler(type: InternetAddressType.IPv6)?.lastLocalUpdated);

  void setIpv4Handler(IStunHandler handler) =>
      setHandler(handler, type: InternetAddressType.IPv4);

  void setIpv6Handler(IStunHandler handler) =>
      setHandler(handler, type: InternetAddressType.IPv6);

  void clearIpv4Handler() =>
      clearHandler(type: InternetAddressType.IPv4);

  void clearIpv6Handler() =>
      clearHandler(type: InternetAddressType.IPv6);

  IStunHandler? get ipv4Handler =>
      getHandler(type: InternetAddressType.IPv4);

  IStunHandler? get ipv6Handler =>
      getHandler(type: InternetAddressType.IPv6);
}
