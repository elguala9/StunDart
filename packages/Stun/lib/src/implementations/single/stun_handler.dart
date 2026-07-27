import 'dart:io';

import '../../config/stun_config.dart';
import 'stun_request_handler.dart';
import 'stun_socket_manager.dart';
import '../../mixins/destroyable_handler_mixin.dart';
import '../../mixins/single/stun_handler_mixin.dart';
import '../../mixins/single/stun_logger_mixin.dart';
import '../../types/stun_types.dart';
import '../../interfaces/single/i_stun_handler.dart';

/// STUN handler implementation with optional socket and auto-recreation
class StunHandler
    with StunLoggerMixin, DestroyableHandlerMixin, StunHandlerMixin
    implements IStunHandler {
  /// Creates a STUN handler with the provided configuration (backward compatible)
  StunHandler(StunHandlerInput input)
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
  }

  /// Factory constructor for explicit socket ownership
  factory StunHandler.withSocket(
    RawDatagramSocket socket, {
    String? address,
    int? port,
    Duration timeout = const Duration(seconds: 5),
    void Function(String)? onLog,
  }) {
    final handler = StunHandler._internal(
      stunAddress: address,
      stunPort: port,
      bindType: socket.address.type,
      bindPort: null,
      timeout: timeout,
      onLog: onLog,
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
  }) : _stunAddress = stunAddress ?? defaultStunConfig.address,
       _stunPort = stunPort ?? defaultStunConfig.port,
       _timeout = timeout,
       _onLog = onLog,
       _socketMgr = StunSocketManager(
         bindType: bindType,
         bindPort: bindPort,
         onLog: onLog,
       );

  String _stunAddress;
  int _stunPort;
  final Duration _timeout;
  final void Function(String)? _onLog;
  final StunSocketManager _socketMgr;

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
  void setStunServer(String address, int port) {
    _stunAddress = address.trim().isNotEmpty
        ? address
        : defaultStunConfig.address;
    _stunPort = (port > 0 && port < 65536) ? port : defaultStunConfig.port;
  }

  static Future<StunHandler> withoutSocket({
    String? address,
    int? port,
    InternetAddressType type = InternetAddressType.IPv4,
    Duration timeout = const Duration(seconds: 5),
    void Function(String)? onLog,
  }) async {
    final handler = StunHandler._internal(
      stunAddress: address,
      stunPort: port,
      bindType: type,
      timeout: timeout,
      onLog: onLog,
    );
    await handler._socketMgr.getSocket();
    return handler;
  }

  @override
  InternetAddressType getIpVersion() {
    return socketMgr.bindType;
  }
}
