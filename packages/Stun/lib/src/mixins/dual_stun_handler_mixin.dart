import 'dart:io';

import 'package:meta/meta.dart';

import '../interfaces/i_stun_handler.dart';
import '../types/stun_types.dart';
import 'dual_handler_selector_mixin.dart';

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
mixin DualStunHandlerMixin on DualHandlerSelectorMixin {
  /// IPv4 slot setter provided by the mixing class.
  set ipv4Handler(IStunHandler? handler);

  /// IPv6 slot setter provided by the mixing class.
  set ipv6Handler(IStunHandler? handler);

  @override
  String missingHandlerMessage({required bool ipv6}) =>
      'DualStunHandler: ${ipv6 ? 'IPv6' : 'IPv4'} handler not initialized or not available';

  void setIpv4Handler(IStunHandler handler) {
    if (handler.getSocket().address.type != InternetAddressType.IPv4) {
      throw ArgumentError(
        'DualStunHandler: expected an IPv4 socket, got '
        '${handler.getSocket().address.type}.',
      );
    }
    ipv4Handler = handler;
  }

  void setIpv6Handler(IStunHandler handler) {
    if (handler.getSocket().address.type != InternetAddressType.IPv6) {
      throw ArgumentError(
        'DualStunHandler: expected an IPv6 socket, got '
        '${handler.getSocket().address.type}.',
      );
    }
    ipv6Handler = handler;
  }

  void clearIpv4Handler() => ipv4Handler = null;

  void clearIpv6Handler() => ipv6Handler = null;

  void replaceHandler(IStunHandler handler, {required bool ipv6}) {
    if (ipv6) {
      setIpv6Handler(handler);
    } else {
      setIpv4Handler(handler);
    }
  }

  Future<StunDualResponse> performStunRequest() async {
    if (ipv4Handler == null && ipv6Handler == null) {
      throw StateError('DualStunHandler: no handler initialized');
    }

    // Run on both handlers in parallel when both are available; either
    // handler's failure is non-fatal and surfaces as a null slot.
    final ipv4Future = _safeCall(ipv4Handler?.performStunRequest());
    final ipv6Future = _safeCall(ipv6Handler?.performStunRequest());

    final ipv4Result = await ipv4Future;
    final ipv6Result = await ipv6Future;

    return (stunResponseIpv4: ipv4Result, stunResponseIpv6: ipv6Result);
  }

  Future<LocalDualInfo> performLocalRequest() async {
    if (ipv4Handler == null && ipv6Handler == null) {
      throw StateError('DualStunHandler: no handler initialized');
    }

    // Run on both handlers in parallel when both are available; either
    // handler's failure is non-fatal and surfaces as a null slot.
    final ipv4Future = _safeCall(ipv4Handler?.performLocalRequest());
    final ipv6Future = _safeCall(ipv6Handler?.performLocalRequest());

    final ipv4Result = await ipv4Future;
    final ipv6Result = await ipv6Future;

    return (localDualInfoIpv4: ipv4Result, localDualInfoIpv6: ipv6Result);
  }

  Future<bool> pingStunServer({bool ipv6 = true}) =>
      requireHandler(ipv6: ipv6).pingStunServer();

  RawDatagramSocket getSocket({bool ipv6 = true}) =>
      requireHandler(ipv6: ipv6).getSocket();

  void setStunServer(String address, int port, {bool? ipv6}) {
    if (ipv6 == null || ipv6 == false) {
      ipv4Handler?.setStunServer(address, port);
    }
    if (ipv6 == null || ipv6 == true) {
      ipv6Handler?.setStunServer(address, port);
    }
  }

  void close({bool? ipv6}) {
    if (ipv6 == null || ipv6 == false) {
      ipv4Handler?.close();
      ipv4Handler = null;
    }
    if (ipv6 == null || ipv6 == true) {
      ipv6Handler?.close();
      ipv6Handler = null;
    }
  }

  DateTime? get ipv4LastStunUpdated => ipv4Handler?.lastStunUpdated;

  DateTime? get ipv6LastStunUpdated => ipv6Handler?.lastStunUpdated;

  DateTime? get ipv4LastLocalUpdated => ipv4Handler?.lastLocalUpdated;

  DateTime? get ipv6LastLocalUpdated => ipv6Handler?.lastLocalUpdated;

  DateTime? get lastStunUpdated =>
      _laterOf(ipv4LastStunUpdated, ipv6LastStunUpdated);

  DateTime? get lastLocalUpdated =>
      _laterOf(ipv4LastLocalUpdated, ipv6LastLocalUpdated);
}
