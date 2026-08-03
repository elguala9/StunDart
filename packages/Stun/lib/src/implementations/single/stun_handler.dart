import 'dart:io';

import 'package:config_manager/config_manager.dart';
import 'package:singleton_manager/singleton_manager.dart';

import '../../config/stun_config.dart';
import 'stun_request_handler.dart';
import 'stun_socket_manager.dart';
import '../../mixins/destroyable_handler_mixin.dart';
import '../../mixins/single/stun_handler_mixin.dart';
import '../../mixins/single/stun_logger_mixin.dart';
import '../../interfaces/single/i_stun_handler.dart';

/// STUN handler implementation with auto-recreation on socket errors
@dependencyInjectable
class StunHandler
    with
        StunLoggerMixin,
        DestroyableHandlerMixin,
        StunHandlerMixin,
        ConfigExtension,
        StunConfigExtension
    implements IStunHandler {
  /// Creates a STUN handler backed by an already-bound [socket].
  ///
  /// Unset arguments fall back to the STUN configuration.
  StunHandler(
    @Subkey.inherited() RawDatagramSocket socket, {
    String? address,
    int? port,
    Duration? timeout,
    void Function(String)? onLog,
  }) : _onLog = onLog {
    _stunAddress = address ?? defaultStunAddress;
    _stunPort = port ?? defaultStunPort;
    _timeout = timeout ?? defaultTimeout;
    _socketMgr = StunSocketManager(socket: socket, onLog: onLog);
  }

  factory StunHandler.dependencyInjectionFactory({String key = 'default', String subkey = 'default'}) { // GENERATED CODE - DO NOT MODIFY BY HAND
    final socket = RegistryManager.instance.getInstance<RawDatagramSocket>(key: key, subkey: subkey); // GENERATED CODE - DO NOT MODIFY BY HAND

    return StunHandler( // GENERATED CODE - DO NOT MODIFY BY HAND
      socket, // GENERATED CODE - DO NOT MODIFY BY HAND
    ); // GENERATED CODE - DO NOT MODIFY BY HAND
  } // GENERATED CODE - DO NOT MODIFY BY HAND

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
    final socket = await StunSocketManager.bindSocket(
      bindType: type ?? defaultStunIpVersion(),
      onLog: onLog,
    );
    return StunHandler(
      socket,
      address: address,
      port: port,
      timeout: timeout,
      onLog: onLog,
    );
  }

  @override
  InternetAddressType getIpVersion() {
    return socketMgr.bindType;
  }
}
