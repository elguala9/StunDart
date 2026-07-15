import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';

import '../implementations/request/stun_request_handler.dart';
import '../implementations/socket/stun_socket_manager.dart';
import '../implementations/socket/stun_socket_refresh_manager.dart';
import '../types/stun_types.dart';
import 'stun_logger_mixin.dart';

/// Internal-only behavior of `StunHandler`: cached STUN/local requests,
/// socket error recovery and refresh-callback plumbing. The mixing class
/// provides the collaborators as state. Not part of the package's public
/// API — do not export it from `stun.dart`.
@internal
mixin StunHandlerMixin on StunLoggerMixin {
  /// Socket manager provided by the mixing class.
  StunSocketManager get socketMgr;

  /// Request handler provided by the mixing class.
  StunRequestHandler get requestHandler;

  /// Refresh callback manager provided by the mixing class.
  StunSocketRefreshManager get refreshManager;

  void addOnSocketRefresh(OnSocketRefresh callback) =>
      refreshManager.register(callback);

  void removeOnSocketRefresh(OnSocketRefresh callback) =>
      refreshManager.unregister(callback);

  DateTime? get lastStunUpdated => socketMgr.lastStunUpdated;

  DateTime? get lastLocalUpdated => socketMgr.lastLocalUpdated;

  Future<LocalInfo> performLocalRequest() async {
    if (socketMgr.cachedLocalInfo != null) {
      return socketMgr.cachedLocalInfo!;
    }

    final socket = await socketMgr.getSocket();
    final localIp = await socketMgr.getLocalIp();
    final ipVersion = socket.address.type == InternetAddressType.IPv6
        ? IpVersion.v6
        : IpVersion.v4;
    socketMgr.cachedLocalInfo = (
      localIp: localIp,
      localPort: socket.port,
      ipVersion: ipVersion,
    );
    socketMgr.lastLocalUpdated = DateTime.now();
    return socketMgr.cachedLocalInfo!;
  }

  RawDatagramSocket getSocket() {
    if (socketMgr.socket == null) {
      throw StateError(
        'Socket not yet initialized. Use StunHandler.create() for automatic socket management.',
      );
    }
    return socketMgr.socket!;
  }

  void close() => socketMgr.closeSocket();

  Future<StunResponse> performStunRequest() async {
    if (socketMgr.cachedStunResponse != null) {
      return socketMgr.cachedStunResponse!;
    }

    try {
      socketMgr.cachedStunResponse = await _doStunRequest();
      socketMgr.lastStunUpdated = DateTime.now();
      return socketMgr.cachedStunResponse!;
    } on SocketException catch (e) {
      return _handleSocketError(
        '[StunHandler] Socket error (${e.message}), attempting recreation...',
      );
    } on OSError catch (e) {
      return _handleSocketError(
        '[StunHandler] OS error (${e.message}), attempting recreation...',
      );
    } on StateError catch (e) {
      if (e.message.contains('already been listened to')) {
        return _handleSocketError(
          '[StunHandler] Stream error (socket already in use), attempting recreation...',
        );
      }
      rethrow;
    }
  }

  Future<bool> pingStunServer() async {
    await performStunRequest();
    return true;
  }

  Future<StunResponse> _handleSocketError(String logMessage) async {
    log(logMessage);
    final oldResponse = socketMgr.cachedStunResponse;
    await socketMgr.recreateSocket();
    socketMgr.cachedStunResponse = await _doStunRequest();
    socketMgr.lastStunUpdated = DateTime.now();
    refreshManager.fire(socketMgr.cachedStunResponse!, oldResponse);
    return socketMgr.cachedStunResponse!;
  }

  Future<StunResponse> _doStunRequest() async {
    final socket = await socketMgr.getSocket();
    return requestHandler.performStunRequest(socket);
  }
}
