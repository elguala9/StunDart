import 'dart:io';

import '../config/stun_config.dart';
import '../request/stun_request_handler.dart';
import '../socket/stun_socket_refresh_manager.dart';
import '../socket/stun_socket_manager.dart';
import '../../mixins/destroyable_handler_mixin.dart';
import '../../mixins/stun_handler_mixin.dart';
import '../../mixins/stun_logger_mixin.dart';
import '../../types/stun_types.dart';
import '../../interfaces/i_stun_handler.dart';

/// STUN handler implementation with optional socket and auto-recreation
class StunHandler
    with StunLoggerMixin, DestroyableHandlerMixin, StunHandlerMixin
    implements IStunHandler {
  /// Creates a STUN handler with the provided configuration (backward compatible)
  StunHandler(StunHandlerInput input, {OnSocketRefresh? onSocketRefresh})
    : _stunAddress = input.address ?? defaultStunConfig.address,
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

  /// Factory constructor for explicit socket ownership
  factory StunHandler.withSocket(
    RawDatagramSocket socket, {
    String? address,
    int? port,
    Duration timeout = const Duration(seconds: 5),
    void Function(String)? onLog,
    OnSocketRefresh? onSocketRefresh,
  }) {
    final handler = StunHandler._internal(
      stunAddress: address,
      stunPort: port,
      bindType: socket.address.type,
      bindPort: null,
      timeout: timeout,
      onLog: onLog,
      onSocketRefresh: onSocketRefresh,
    );
    handler._socketMgr.socket = socket;
    return handler;
  }

  /// Private constructor for factory use
  StunHandler._internal({
    String? stunAddress,
    int? stunPort,
    required InternetAddressType bindType,
    int? bindPort = 0,
    Duration timeout = const Duration(seconds: 5),
    void Function(String)? onLog,
    OnSocketRefresh? onSocketRefresh,
  }) : _stunAddress = stunAddress ?? defaultStunConfig.address,
       _stunPort = stunPort ?? defaultStunConfig.port,
       _timeout = timeout,
       _onLog = onLog,
       _socketMgr = StunSocketManager(
         bindType: bindType,
         bindPort: bindPort,
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

  @override
  void Function(String)? get onLog => _onLog;

  @override
  StunSocketManager get socketMgr => _socketMgr;

  @override
  StunRequestHandler get requestHandler => _requestHandler;

  @override
  StunSocketRefreshManager get refreshManager => _refreshManager;

  void _registerSocketRefreshCallback(OnSocketRefresh? callback) {
    if (callback == null) return;
    _refreshManager.register(callback);
  }

  @override
  void setStunServer(String address, int port) {
    _stunAddress = address.trim().isNotEmpty
        ? address
        : defaultStunConfig.address;
    _stunPort = (port > 0 && port < 65536) ? port : defaultStunConfig.port;
  }

  static Future<StunHandler> withoutSocket({
    String? address,
    int? port,
    bool ipv6 = false,
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
}
