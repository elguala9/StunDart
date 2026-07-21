import 'dart:io';

import 'package:meta/meta.dart';

import '../interfaces/i_stun_handler.dart';
import '../types/stun_types.dart' show StunResponse, LocalInfo;
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
  void setHandlerSlot(IStunHandler? handler, {required bool ipv6});

  @override
  String missingHandlerMessage({required bool ipv6}) =>
      'DualStunHandler: ${ipv6 ? 'IPv6' : 'IPv4'} handler not initialized or not available';

  void setHandler(
    IStunHandler handler, {
    bool ipv6 = true,
  }) {
    final expected = ipv6 ? InternetAddressType.IPv6 : InternetAddressType.IPv4;
    if (handler.getSocket().address.type != expected) {
      throw ArgumentError(
        'DualStunHandler: expected an ${ipv6 ? 'IPv6' : 'IPv4'} socket, got '
        '${handler.getSocket().address.type}.',
      );
    }
    setHandlerSlot(handler, ipv6: ipv6);
  }

  void clearHandler({bool ipv6 = true}) {
    setHandlerSlot(null, ipv6: ipv6);
  }

  IStunHandler? getHandler({
    bool ipv6 = true,
  }) => handler(ipv6: ipv6);

  void replaceHandler(
    IStunHandler handler, {
    bool ipv6 = true,
  }) => setHandler(handler, ipv6: ipv6);

  Future<StunResponse> performStunRequest() async {
    final v4 = handler(ipv6: false);
    final v6 = handler(ipv6: true);
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
    final v4 = handler(ipv6: false);
    final v6 = handler(ipv6: true);
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
    bool ipv6 = true,
  }) => requireHandler(ipv6: ipv6).pingStunServer();

  RawDatagramSocket getSocket({
    bool ipv6 = true,
  }) => requireHandler(ipv6: ipv6).getSocket();

  void setStunServer(String address, int port, {bool? ipv6}) {
    if (ipv6 == null || !ipv6) {
      handler(ipv6: false)?.setStunServer(address, port);
    }
    if (ipv6 == null || ipv6) {
      handler(ipv6: true)?.setStunServer(address, port);
    }
  }

  void close({bool? ipv6}) {
    if (ipv6 == null || !ipv6) {
      handler(ipv6: false)?.close();
      setHandlerSlot(null, ipv6: false);
    }
    if (ipv6 == null || ipv6) {
      handler(ipv6: true)?.close();
      setHandlerSlot(null, ipv6: true);
    }
  }

  DateTime? getLastStunUpdated({
    bool ipv6 = true,
  }) => handler(ipv6: ipv6)?.lastStunUpdated;

  DateTime? getLastLocalUpdated({
    bool ipv6 = true,
  }) => handler(ipv6: ipv6)?.lastLocalUpdated;

  DateTime? get lastStunUpdated =>
      _laterOf(handler(ipv6: false)?.lastStunUpdated, handler(ipv6: true)?.lastStunUpdated);

  DateTime? get lastLocalUpdated =>
      _laterOf(handler(ipv6: false)?.lastLocalUpdated, handler(ipv6: true)?.lastLocalUpdated);

  void setIpv4Handler(IStunHandler handler) =>
      setHandler(handler, ipv6: false);

  void setIpv6Handler(IStunHandler handler) =>
      setHandler(handler, ipv6: true);

  void clearIpv4Handler() =>
      clearHandler(ipv6: false);

  void clearIpv6Handler() =>
      clearHandler(ipv6: true);

  IStunHandler? get ipv4Handler =>
      getHandler(ipv6: false);

  IStunHandler? get ipv6Handler =>
      getHandler(ipv6: true);
}
