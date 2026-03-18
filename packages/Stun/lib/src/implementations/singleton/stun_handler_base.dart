import 'dart:io';

import 'package:singleton_manager/singleton_manager.dart';

import '../../types/stun_types.dart';
import '../../interfaces/i_stun_handler.dart';
import 'dual_callback_handler.dart';
import 'singleton_handler_factory.dart';
import 'stun_handler_operations.dart';
import 'package:meta/meta.dart';

/// Adds initialization and socket-refresh callback management to StunHandlerOperations
@isSingleton
class StunHandlerBase extends StunHandlerOperations {
  @isInjected
  @protected
  late  DualCallbackHandler callbacks = DualCallbackHandler();

  Future<void> initialize({
    String? address,
    int? port,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    const factory = SingletonHandlerFactory();

    dualHandler.setIpv4Handler(await factory.createIpv4Handler(
      address: address,
      port: port,
      timeout: timeout,
      onSocketRefresh: callbacks.onIpv4,
    ));

    IStunHandler? ipv6;
    try {
      ipv6 = await factory.createIpv6Handler(
        address: address,
        port: port,
        timeout: timeout,
        onSocketRefresh: callbacks.onIpv6,
      );
    } catch (_) {}
    dualHandler.setIpv6Handler(ipv6);
  }

  Future<void> initializeWithHandlers(IStunHandler ipv4Handler, {IStunHandler? ipv6Handler}) async {
    dualHandler.setIpv4Handler(ipv4Handler);
    dualHandler.setIpv6Handler(ipv6Handler);
  }

  void setIpv4Handler(IStunHandler handler) {
    dualHandler.setIpv4Handler(handler);
    handler.addOnSocketRefresh(callbacks.onIpv4);
  }

  void setIpv6Handler(IStunHandler? handler) {
    dualHandler.setIpv6Handler(handler);
    if (handler != null) handler.addOnSocketRefresh(callbacks.onIpv6);
  }

  void setOnSocketRefreshIpv4(OnSocketRefreshIpv4 callback) {
    final handler = dualHandler.ipv4Handler;
    if (handler == null) {
      throw StateError('StunHandlerSingleton: IPv4 handler not initialized. Call initialize() first.');
    }

    final socket = handler.getSocket();
    if (socket.address.type != InternetAddressType.IPv4) {
      throw ArgumentError(
        'Socket type mismatch: expected IPv4, got ${socket.address.type}. '
        'Ensure the handler has an IPv4 socket.',
      );
    }

    void wrapper((StunResponse, StunResponse?) data) => callback(data.$1, data.$2);
    callbacks.registerIpv4(wrapper);
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

    void wrapper((StunResponse, StunResponse?) data) => callback(data.$1, data.$2);
    callbacks.registerIpv6(wrapper);
  }

  void removeOnSocketRefreshIpv4() => callbacks.clearIpv4();
  void removeOnSocketRefreshIpv6() => callbacks.clearIpv6();
}
