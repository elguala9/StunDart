import 'dart:io';

import 'package:callback_handler/callback_handler.dart';
import 'package:singleton_manager/singleton_manager.dart';

import '../../types/stun_types.dart';
import '../../interfaces/i_stun_handler.dart';
import '../../interfaces/i_stun_handler_singleton.dart';
import '../../interfaces/i_dual_stun_handler.dart';
import '../handlers/dual_stun_handler.dart';
import 'singleton_handler_factory.dart';

/// Singleton wrapper for managing dual IPv4 and IPv6 STUN handlers
class StunHandlerSingleton implements IStunHandlerSingleton {
  factory StunHandlerSingleton() => _instance;
  StunHandlerSingleton._internal();

  static final StunHandlerSingleton _instance = StunHandlerSingleton._internal();

  final IDualStunHandler _dualHandler = DualStunHandler();

  /// Manages IPv4-specific socket refresh callbacks (tuple-based via CallbackHandler)
  final IpCallbackHandler _ipv4CallbackHandler =
      CallbackHandler();

  /// Manages IPv6-specific socket refresh callbacks (tuple-based via CallbackHandler)
  final IpCallbackHandler _ipv6CallbackHandler =
      CallbackHandler();

  static StunHandlerSingleton get instance => _instance;

  @override
  Future<void> initialize({
    String? address,
    int? port,
    Duration timeout = const Duration(seconds: 5),
    void Function(String)? onLog,
  }) async {
    final factory = SingletonHandlerFactory(onLog: onLog);

    _dualHandler.setIpv4Handler(await factory.createIpv4Handler(
      address: address,
      port: port,
      timeout: timeout,
      onSocketRefresh: (newRes, oldRes) => _ipv4CallbackHandler((newRes, oldRes)),
    ));
    _dualHandler.setIpv6Handler(await factory.createIpv6HandlerSafe(
      address: address,
      port: port,
      timeout: timeout,
      onSocketRefresh: (newRes, oldRes) => _ipv6CallbackHandler((newRes, oldRes)),
    ));
  }

  @override
  Future<void> initializeWithHandlers(IStunHandler ipv4Handler, {IStunHandler? ipv6Handler}) async {
    _dualHandler.setIpv4Handler(ipv4Handler);
    _dualHandler.setIpv6Handler(ipv6Handler);
  }

  @override
  void setIpv4Handler(IStunHandler handler) {
    _dualHandler.setIpv4Handler(handler);
    handler.addOnSocketRefresh((newRes, oldRes) => _ipv4CallbackHandler((newRes, oldRes)));
  }

  @override
  void setIpv6Handler(IStunHandler? handler) {
    _dualHandler.setIpv6Handler(handler);
    if (handler != null) {
      handler.addOnSocketRefresh((newRes, oldRes) => _ipv6CallbackHandler((newRes, oldRes)));
    }
  }

  IStunHandler _getHandler({required bool ipv6}) {
    if (ipv6) {
      if (_dualHandler.ipv6Handler == null) {
        throw StateError('StunHandlerSingleton: IPv6 handler not initialized or not available. Call initialize() first.');
      }
      return _dualHandler.ipv6Handler!;
    } else {
      if (_dualHandler.ipv4Handler == null) {
        throw StateError('StunHandlerSingleton: IPv4 handler not initialized. Call initialize() first.');
      }
      return _dualHandler.ipv4Handler!;
    }
  }

  @override
  IStunHandler get ipv4Handler => _getHandler(ipv6: false);

  @override
  IStunHandler? get ipv6Handler => _dualHandler.ipv6Handler;

  @override
  void replaceHandler(IStunHandler handler, {required bool ipv6}) {
    _dualHandler.replaceHandler(handler, ipv6: ipv6);
  }

  @override
  Future<StunResponse> performStunRequest() async {
    if (_dualHandler.ipv4Handler == null) {
      throw StateError('StunHandlerSingleton: IPv4 handler not initialized. Call initialize() first.');
    }
    return _dualHandler.performStunRequest();
  }

  @override
  Future<LocalInfo> performLocalRequest() async {
    if (_dualHandler.ipv4Handler == null) {
      throw StateError('StunHandlerSingleton: IPv4 handler not initialized. Call initialize() first.');
    }
    return _dualHandler.performLocalRequest();
  }

  @override
  Future<bool> pingStunServer({bool ipv6 = true}) => _getHandler(ipv6: ipv6).pingStunServer();

  @override
  RawDatagramSocket getSocket({bool ipv6 = true}) => _getHandler(ipv6: ipv6).getSocket();

  @override
  void setStunServer(String address, int port, {bool? ipv6}) {
    _dualHandler.setStunServer(address, port, ipv6: ipv6);
  }

  @override
  void close({bool? ipv6}) {
    _dualHandler.close(ipv6: ipv6);
  }

  @override
  DateTime? get ipv4LastStunUpdated => _dualHandler.ipv4LastStunUpdated;

  @override
  DateTime? get ipv6LastStunUpdated => _dualHandler.ipv6LastStunUpdated;

  @override
  DateTime? get ipv4LastLocalUpdated => _dualHandler.ipv4LastLocalUpdated;

  @override
  DateTime? get ipv6LastLocalUpdated => _dualHandler.ipv6LastLocalUpdated;

  @override
  DateTime? get lastStunUpdated => _dualHandler.lastStunUpdated;

  @override
  DateTime? get lastLocalUpdated => _dualHandler.lastLocalUpdated;

  @override
  void setOnSocketRefreshIpv4(OnSocketRefreshIpv4 callback) {
    final handler = _dualHandler.ipv4Handler;
    if (handler == null) {
      throw StateError('StunHandlerSingleton: IPv4 handler not initialized. Call initialize() first.');
    }

    // Validate socket type matches IPv4
    final socket = handler.getSocket();
    if (socket.address.type != InternetAddressType.IPv4) {
      throw ArgumentError(
        'Socket type mismatch: expected IPv4, got ${socket.address.type}. '
        'Ensure the handler has an IPv4 socket.',
      );
    }

    // Register callback - wrapper unpacks tuple and calls user callback
    void wrapper((StunResponse, StunResponse?) data) => callback(data.$1, data.$2);
    _ipv4CallbackHandler.register(wrapper);
  }

  @override
  void setOnSocketRefreshIpv6(OnSocketRefreshIpv6 callback) {
    final handler = _dualHandler.ipv6Handler;
    if (handler == null) {
      throw StateError(
        'StunHandlerSingleton: IPv6 handler not initialized or not available. '
        'Call initialize() first and ensure IPv6 is available on this system.',
      );
    }

    // Validate socket type matches IPv6
    final socket = handler.getSocket();
    if (socket.address.type != InternetAddressType.IPv6) {
      throw ArgumentError(
        'Socket type mismatch: expected IPv6, got ${socket.address.type}. '
        'Ensure the handler has an IPv6 socket.',
      );
    }

    // Register callback - wrapper unpacks tuple and calls user callback
    void wrapper((StunResponse, StunResponse?) data) => callback(data.$1, data.$2);
    _ipv6CallbackHandler.register(wrapper);
  }

  @override
  void removeOnSocketRefreshIpv4() {
    _ipv4CallbackHandler.clear();
  }

  @override
  void removeOnSocketRefreshIpv6() {
    _ipv6CallbackHandler.clear();
  }

  /// Destroys the singleton by closing all handlers (required by IValueForRegistry)
  @override
  void destroy() => close();

  @override
  Future<void> initializeDI() async {
    // Get or create the SingletonHandlerFactory from DI container
    late final SingletonHandlerFactory factory;
    try {
      factory = SingletonDIAccess.get<SingletonHandlerFactory>();
    } catch (_) {
      // Factory not registered, create a new one
      factory = SingletonHandlerFactory();
      await factory.initializeDI();
    }

    // Register the dual handler in the DI container
    await _dualHandler.initializeDI();

    // Register this singleton instance in the DI container
    SingletonDI.registerFactory<StunHandlerSingleton>(() => this);
    await SingletonDIAccess.add<StunHandlerSingleton>();
  }
}
