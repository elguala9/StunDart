import 'dart:io';

import '../../types/stun_types.dart';
import '../../interfaces/i_stun_handler.dart';
import '../../interfaces/i_stun_handler_singleton.dart';
import 'singleton_handler_factory.dart';
import 'singleton_dual_request.dart';
import 'singleton_handler_state.dart';

/// Singleton wrapper for managing dual IPv4 and IPv6 STUN handlers
class StunHandlerSingleton implements IStunHandlerSingleton {
  factory StunHandlerSingleton() => _instance;
  StunHandlerSingleton._internal();

  static final StunHandlerSingleton _instance = StunHandlerSingleton._internal();

  final _state = SingletonHandlerState();
  OnSocketRefreshIpv4? _onSocketRefreshIpv4;
  OnSocketRefreshIpv6? _onSocketRefreshIpv6;

  (OnSocketRefresh?, OnSocketRefresh?) _createSingletonWrappers(OnSingletonSocketRefresh? callback) {
    if (callback == null) return (null, null);
    return (
      (newRes, oldRes) => callback(newRes, oldRes, ipv6: false),
      (newRes, oldRes) => callback(newRes, oldRes, ipv6: true),
    );
  }

  static StunHandlerSingleton get instance => _instance;

  @override
  Future<void> initialize({
    String? address,
    int? port,
    Duration timeout = const Duration(seconds: 5),
    void Function(String)? onLog,
    OnSingletonSocketRefresh? onSocketRefresh,
  }) async {
    final factory = SingletonHandlerFactory(onLog: onLog);

    final (ipv4Callback, ipv6Callback) = _createSingletonWrappers(onSocketRefresh);

    _state.ipv4Handler = await factory.createIpv4Handler(
      address: address,
      port: port,
      timeout: timeout,
      onSocketRefresh: ipv4Callback,
    );
    _state.ipv6Handler = await factory.createIpv6HandlerSafe(
      address: address,
      port: port,
      timeout: timeout,
      onSocketRefresh: ipv6Callback,
    );
  }

  @override
  Future<void> initializeWithHandlers(IStunHandler ipv4Handler, {IStunHandler? ipv6Handler}) async {
    _state.ipv4Handler = ipv4Handler;
    _state.ipv6Handler = ipv6Handler;
  }

  @override
  void setIpv4Handler(IStunHandler handler) {
    _state.ipv4Handler = handler;
    for (final entry in _state.callbackWrapperMap.entries) {
      handler.addOnSocketRefresh(entry.value.$1);
    }
  }

  @override
  void setIpv6Handler(IStunHandler? handler) {
    _state.ipv6Handler = handler;
    if (handler != null) {
      for (final entry in _state.callbackWrapperMap.entries) {
        handler.addOnSocketRefresh(entry.value.$2);
      }
    }
  }

  IStunHandler _getHandler({required bool ipv6}) {
    if (ipv6) {
      if (_state.ipv6Handler == null) {
        throw StateError('StunHandlerSingleton: IPv6 handler not initialized or not available. Call initialize() first.');
      }
      return _state.ipv6Handler!;
    } else {
      if (_state.ipv4Handler == null) {
        throw StateError('StunHandlerSingleton: IPv4 handler not initialized. Call initialize() first.');
      }
      return _state.ipv4Handler!;
    }
  }

  @override
  IStunHandler get ipv4Handler => _getHandler(ipv6: false);

  @override
  IStunHandler? get ipv6Handler => _state.ipv6Handler;

  @override
  void replaceHandler(IStunHandler handler, {required bool ipv6}) {
    if (ipv6) {
      setIpv6Handler(handler);
    } else {
      setIpv4Handler(handler);
    }
  }

  @override
  Future<StunResponse> performStunRequest() async {
    if (_state.ipv4Handler == null) {
      throw StateError('StunHandlerSingleton: IPv4 handler not initialized. Call initialize() first.');
    }
    return SingletonDualRequest.performStunRequest(
      ipv4Handler: _state.ipv4Handler!,
      ipv6Handler: _state.ipv6Handler,
    );
  }

  @override
  Future<LocalInfo> performLocalRequest() async {
    if (_state.ipv4Handler == null) {
      throw StateError('StunHandlerSingleton: IPv4 handler not initialized. Call initialize() first.');
    }
    return SingletonDualRequest.performLocalRequest(
      ipv4Handler: _state.ipv4Handler!,
      ipv6Handler: _state.ipv6Handler,
    );
  }

  @override
  Future<bool> pingStunServer({bool ipv6 = true}) => _getHandler(ipv6: ipv6).pingStunServer();

  @override
  RawDatagramSocket getSocket({bool ipv6 = true}) => _getHandler(ipv6: ipv6).getSocket();

  @override
  void setStunServer(String address, int port, {bool? ipv6}) {
    if (ipv6 == null || ipv6 == false) {
      _state.ipv4Handler?.setStunServer(address, port);
    }
    if (ipv6 == null || ipv6 == true) {
      _state.ipv6Handler?.setStunServer(address, port);
    }
  }

  @override
  void close({bool? ipv6}) {
    _state.close(ipv6: ipv6);
  }

  @override
  void addOnSocketRefresh(OnSingletonSocketRefresh callback) {
    _state.callbackWrapperMap.putIfAbsent(callback, () {
      void ipv4Wrapper(StunResponse newRes, StunResponse? oldRes) =>
          callback(newRes, oldRes, ipv6: false);
      void ipv6Wrapper(StunResponse newRes, StunResponse? oldRes) =>
          callback(newRes, oldRes, ipv6: true);
      _state.ipv4Handler?.addOnSocketRefresh(ipv4Wrapper);
      _state.ipv6Handler?.addOnSocketRefresh(ipv6Wrapper);
      return (ipv4Wrapper, ipv6Wrapper);
    });
  }

  @override
  void removeOnSocketRefresh(OnSingletonSocketRefresh callback) {
    final wrappers = _state.callbackWrapperMap.remove(callback);
    if (wrappers == null) return;
    final (ipv4Wrapper, ipv6Wrapper) = wrappers;
    _state.ipv4Handler?.removeOnSocketRefresh(ipv4Wrapper);
    _state.ipv6Handler?.removeOnSocketRefresh(ipv6Wrapper);
  }

  @override
  DateTime? get ipv4LastStunUpdated => _state.ipv4LastStunUpdated;

  @override
  DateTime? get ipv6LastStunUpdated => _state.ipv6LastStunUpdated;

  @override
  DateTime? get ipv4LastLocalUpdated => _state.ipv4LastLocalUpdated;

  @override
  DateTime? get ipv6LastLocalUpdated => _state.ipv6LastLocalUpdated;

  @override
  DateTime? get lastStunUpdated => _state.lastStunUpdated;

  @override
  DateTime? get lastLocalUpdated => _state.lastLocalUpdated;

  @override
  void setOnSocketRefreshIpv4(OnSocketRefreshIpv4 callback) {
    final handler = _state.ipv4Handler;
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

    _onSocketRefreshIpv4 = callback;
    handler.addOnSocketRefresh((newRes, oldRes) => callback(newRes, oldRes));
  }

  @override
  void setOnSocketRefreshIpv6(OnSocketRefreshIpv6 callback) {
    final handler = _state.ipv6Handler;
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

    _onSocketRefreshIpv6 = callback;
    handler.addOnSocketRefresh((newRes, oldRes) => callback(newRes, oldRes));
  }

  @override
  void removeOnSocketRefreshIpv4() {
    final handler = _state.ipv4Handler;
    if (handler != null && _onSocketRefreshIpv4 != null) {
      handler.removeOnSocketRefresh((newRes, oldRes) => _onSocketRefreshIpv4!(newRes, oldRes));
    }
    _onSocketRefreshIpv4 = null;
  }

  @override
  void removeOnSocketRefreshIpv6() {
    final handler = _state.ipv6Handler;
    if (handler != null && _onSocketRefreshIpv6 != null) {
      handler.removeOnSocketRefresh((newRes, oldRes) => _onSocketRefreshIpv6!(newRes, oldRes));
    }
    _onSocketRefreshIpv6 = null;
  }
}
