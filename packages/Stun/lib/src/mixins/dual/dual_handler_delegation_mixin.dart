import 'dart:io';

import 'package:meta/meta.dart';

import '../../interfaces/dual/i_dual_stun_handler.dart';
import '../../interfaces/single/i_stun_handler.dart';
import 'dual_stun_handler_mixin.dart';
import 'handler_selector_mixin.dart';

/// Internal-only behavior of `DualStunHandlerBase`: adapts an owned
/// [dualHandler] into the slot shape [DualStunHandlerMixin] expects, so all
/// the fan-out/merge logic (dispatch, close, setStunServer, ...) is reused
/// from there instead of being re-forwarded here method by method.
/// Not part of the package's public API -- do not export it from `stun.dart`.
@internal
mixin DualHandlerDelegationMixin on HandlerSelectorMixin, DualStunHandlerMixin {
  /// Dual handler provided by the mixing class.
  IDualStunHandler get dualHandler;

  @override
  IStunHandler? handler({required InternetAddressType type}) =>
      dualHandler.getHandler(type: type);

  @override
  void setHandlerSlot(IStunHandler? handler, {required InternetAddressType type}) {
    if (handler == null) {
      dualHandler.clearHandler(type: type);
    } else {
      dualHandler.setHandler(handler, type: type);
    }
  }

  @override
  String missingHandlerMessage({required InternetAddressType type}) =>
      'DualStunHandlerSingleton: ${type == InternetAddressType.IPv6 ? 'IPv6' : 'IPv4'} handler not initialized or not available. Call initialize() first.';

  DateTime? get ipv4LastStunUpdated =>
      getLastStunUpdated(type: InternetAddressType.IPv4);

  DateTime? get ipv6LastStunUpdated =>
      getLastStunUpdated(type: InternetAddressType.IPv6);

  DateTime? get ipv4LastLocalUpdated =>
      getLastLocalUpdated(type: InternetAddressType.IPv4);

  DateTime? get ipv6LastLocalUpdated =>
      getLastLocalUpdated(type: InternetAddressType.IPv6);
}
