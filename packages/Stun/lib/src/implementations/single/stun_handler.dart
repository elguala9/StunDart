import 'dart:io';

import 'package:config_manager/config_manager.dart';
import 'package:singleton_manager/singleton_manager.dart';

import '../../config/stun_config.dart';
import 'stun_request_handler.dart';
import 'stun_socket_manager.dart';
import '../../mixins/destroyable_handler_mixin.dart';
import '../../mixins/single/stun_handler_mixin.dart';
import '../../mixins/single/stun_logger_mixin.dart';
import '../../types/stun_types.dart';
import '../../interfaces/single/i_stun_handler.dart';

/// STUN handler implementation with optional socket and auto-recreation
@dependencyInjectable
class StunHandler
    with
        StunLoggerMixin,
        DestroyableHandlerMixin,
        StunHandlerMixin,
        ConfigExtension,
        StunConfigExtension
    implements IStunHandler {
  /// Creates a STUN handler with the provided configuration (backward compatible)
  StunHandler(@Subkey.inherited() StunHandlerInput input) : _onLog = null {
    _stunAddress = input.address ?? defaultStunAddress;
    _stunPort = input.port ?? defaultStunPort;
    _timeout = defaultTimeout;
    _socketMgr = StunSocketManager(
      bindType: input.socket?.address.type ?? defaultIpVersion,
      bindPort: null,
      onLog: null,
    );
    if (input.socket != null) _socketMgr.socket = input.socket;
  }

  factory StunHandler.dependencyInjectionFactory({String key = 'default', String subkey = 'default'}) { // GENERATED CODE - DO NOT MODIFY BY HAND
    final input = RegistryManager.instance.getInstance<StunHandlerInput>(key: key, subkey: subkey); // GENERATED CODE - DO NOT MODIFY BY HAND

    return StunHandler( // GENERATED CODE - DO NOT MODIFY BY HAND
      input, // GENERATED CODE - DO NOT MODIFY BY HAND
    ); // GENERATED CODE - DO NOT MODIFY BY HAND
  } // GENERATED CODE - DO NOT MODIFY BY HAND

  /// Factory constructor for explicit socket ownership
  ///
  /// Unset arguments fall back to the STUN configuration.
  factory StunHandler.withSocket(
    RawDatagramSocket socket, {
    String? address,
    int? port,
    Duration? timeout,
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
    InternetAddressType? bindType,
    int? bindPort = 0,
    Duration? timeout,
    void Function(String)? onLog,
  }) : _onLog = onLog {
    _stunAddress = stunAddress ?? defaultStunAddress;
    _stunPort = stunPort ?? defaultStunPort;
    _timeout = timeout ?? defaultTimeout;
    _socketMgr = StunSocketManager(
      bindType: bindType ?? defaultIpVersion,
      bindPort: bindPort,
      onLog: onLog,
    );
  }

  late String _stunAddress;
  late int _stunPort;
  late final Duration _timeout;
  final void Function(String)? _onLog;
  late final StunSocketManager _socketMgr;

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
    _stunAddress = address.trim().isNotEmpty ? address : defaultStunAddress;
    _stunPort = (port > 0 && port < 65536) ? port : defaultStunPort;
  }

  /// Creates a handler that binds its own socket.
  ///
  /// Unset arguments fall back to the STUN configuration.
  static Future<StunHandler> withoutSocket({
    String? address,
    int? port,
    InternetAddressType? type,
    Duration? timeout,
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
