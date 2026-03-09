import 'dart:io';
import 'dart:async';

import '../config/stun_config.dart';
import '../request/stun_request_handler.dart';
import '../socket/stun_socket_refresh_manager.dart';
import '../socket/stun_socket_manager.dart';
import '../../types/stun_types.dart';
import '../../interfaces/i_stun_handler.dart';

/// STUN handler implementation with optional socket and auto-recreation
class StunHandler implements IStunHandler {
  /// Creates a STUN handler with the provided configuration (backward compatible)
  StunHandler(
    StunHandlerInput input, {
    OnSocketRefresh? onSocketRefresh,
  })  : _stunAddress = input.address ?? defaultStunConfig.address,
        _stunPort = input.port ?? defaultStunConfig.port,
        _timeout = const Duration(seconds: 5),
        _onLog = null,
        _socketMgr = StunSocketManager(
          bindType: input.socket?.address.type ?? InternetAddressType.IPv4,
          bindPort: null,
          onLog: null,
        ) {
    if (input.socket != null) _socketMgr.socket = input.socket;
    _registerSocketRefreshCallback(onSocketRefresh);
  }

  /// Named constructor for explicit socket ownership
  StunHandler.withSocket(
    RawDatagramSocket socket, {
    String? address,
    int? port,
    Duration timeout = const Duration(seconds: 5),
    void Function(String)? onLog,
    OnSocketRefresh? onSocketRefresh,
  })  : _stunAddress = address ?? defaultStunConfig.address,
        _stunPort = port ?? defaultStunConfig.port,
        _timeout = timeout,
        _onLog = onLog,
        _socketMgr = StunSocketManager(
          bindType: socket.address.type,
          bindPort: null,
          onLog: onLog,
        ) {
    _socketMgr.socket = socket;
    _registerSocketRefreshCallback(onSocketRefresh);
  }

  /// Private constructor for factory use
  StunHandler._internal({
    String? stunAddress,
    int? stunPort,
    required InternetAddressType bindType,
    Duration timeout = const Duration(seconds: 5),
    void Function(String)? onLog,
    OnSocketRefresh? onSocketRefresh,
  })  : _stunAddress = stunAddress ?? defaultStunConfig.address,
        _stunPort = stunPort ?? defaultStunConfig.port,
        _timeout = timeout,
        _onLog = onLog,
        _socketMgr = StunSocketManager(
          bindType: bindType,
          bindPort: 0,
          onLog: onLog,
        ) {
    _registerSocketRefreshCallback(onSocketRefresh);
  }

  String _stunAddress;
  int _stunPort;
  final Duration _timeout;
  final void Function(String)? _onLog;
  final StunSocketManager _socketMgr;
  final StunSocketRefreshManager _refreshManager = StunSocketRefreshManager();

  late final StunRequestHandler _requestHandler = StunRequestHandler(
    stunAddress: _stunAddress,
    stunPort: _stunPort,
    timeout: _timeout,
    onLog: _onLog,
  );

  void _log(String message) => _onLog?.call(message);

  void _registerSocketRefreshCallback(OnSocketRefresh? callback) {
    if (callback == null) return;
    _refreshManager.register(callback);
  }

  @override
  void addOnSocketRefresh(OnSocketRefresh callback) => _refreshManager.register(callback);

  @override
  void removeOnSocketRefresh(OnSocketRefresh callback) => _refreshManager.unregister(callback);

  @override
  DateTime? get lastStunUpdated => _socketMgr.lastStunUpdated;

  @override
  DateTime? get lastLocalUpdated => _socketMgr.lastLocalUpdated;

  @override
  Future<LocalInfo> performLocalRequest() async {
    if (_socketMgr.cachedLocalInfo != null) {
      return _socketMgr.cachedLocalInfo!;
    }

    final socket = await _socketMgr.getSocket();
    final localIp = await _socketMgr.getLocalIp();
    _socketMgr.cachedLocalInfo = (localIp: localIp, localPort: socket.port);
    _socketMgr.lastLocalUpdated = DateTime.now();
    return _socketMgr.cachedLocalInfo!;
  }

  @override
  RawDatagramSocket getSocket() {
    if (_socketMgr.socket == null) {
      throw StateError('Socket not yet initialized. Use StunHandler.create() for automatic socket management.');
    }
    return _socketMgr.socket!;
  }

  @override
  void close() => _socketMgr.closeSocket();

  @override
  void setStunServer(String address, int port) {
    _stunAddress = address.trim().isNotEmpty ? address : defaultStunConfig.address;
    _stunPort = (port > 0 && port < 65536) ? port : defaultStunConfig.port;
  }

  @override
  Future<StunResponse> performStunRequest() async {
    if (_socketMgr.cachedStunResponse != null) {
      return _socketMgr.cachedStunResponse!;
    }

    try {
      _socketMgr.cachedStunResponse = await _doStunRequest();
      _socketMgr.lastStunUpdated = DateTime.now();
      return _socketMgr.cachedStunResponse!;
    } on SocketException catch (e) {
      return _handleSocketError('[StunHandler] Socket error (${e.message}), attempting recreation...');
    } on OSError catch (e) {
      return _handleSocketError('[StunHandler] OS error (${e.message}), attempting recreation...');
    } on StateError catch (e) {
      if (e.message.contains('already been listened to')) {
        return _handleSocketError('[StunHandler] Stream error (socket already in use), attempting recreation...');
      }
      rethrow;
    }
  }

  @override
  Future<bool> pingStunServer() async {
    await performStunRequest();
    return true;
  }

  static Future<StunHandler> withoutSocket({
    String? address,
    int? port,
    bool ipv6 = true,
    Duration timeout = const Duration(seconds: 5),
    void Function(String)? onLog,
    OnSocketRefresh? onSocketRefresh,
  }) async {
    final handler = StunHandler._internal(
      stunAddress: address,
      stunPort: port,
      bindType: ipv6 ? InternetAddressType.IPv6 : InternetAddressType.IPv4,
      timeout: timeout,
      onLog: onLog,
      onSocketRefresh: onSocketRefresh,
    );
    await handler._socketMgr.getSocket();
    return handler;
  }

  Future<StunResponse> _handleSocketError(String logMessage) async {
    _log(logMessage);
    final oldResponse = _socketMgr.cachedStunResponse;
    await _socketMgr.recreateSocket();
    _socketMgr.cachedStunResponse = await _doStunRequest();
    _socketMgr.lastStunUpdated = DateTime.now();
    _refreshManager.fire(_socketMgr.cachedStunResponse!, oldResponse);
    return _socketMgr.cachedStunResponse!;
  }

  Future<StunResponse> _doStunRequest() async {
    final socket = await _socketMgr.getSocket();
    return _requestHandler.performStunRequest(socket);
  }
}
