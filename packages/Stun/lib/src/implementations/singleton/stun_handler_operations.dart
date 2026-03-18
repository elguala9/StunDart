import 'dart:io';

import '../../types/stun_types.dart';
import '../../interfaces/i_stun_handler.dart';
import '../handlers/dual_stun_handler.dart';

/// Core STUN operations: delegates to IDualStunHandler
class StunHandlerOperations {
  final DualStunHandler _dualHandler = DualStunHandler();

  /// Exposes the dual handler for use by subclasses
  DualStunHandler get dualHandler => _dualHandler;

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

  IStunHandler get ipv4Handler => _getHandler(ipv6: false);
  IStunHandler? get ipv6Handler => _dualHandler.ipv6Handler;

  void replaceHandler(IStunHandler handler, {required bool ipv6}) {
    _dualHandler.replaceHandler(handler, ipv6: ipv6);
  }

  Future<StunResponse> performStunRequest() async {
    if (_dualHandler.ipv4Handler == null) {
      throw StateError('StunHandlerSingleton: IPv4 handler not initialized. Call initialize() first.');
    }
    return _dualHandler.performStunRequest();
  }

  Future<LocalInfo> performLocalRequest() async {
    if (_dualHandler.ipv4Handler == null) {
      throw StateError('StunHandlerSingleton: IPv4 handler not initialized. Call initialize() first.');
    }
    return _dualHandler.performLocalRequest();
  }

  Future<bool> pingStunServer({bool ipv6 = true}) => _getHandler(ipv6: ipv6).pingStunServer();

  RawDatagramSocket getSocket({bool ipv6 = true}) => _getHandler(ipv6: ipv6).getSocket();

  void setStunServer(String address, int port, {bool? ipv6}) {
    _dualHandler.setStunServer(address, port, ipv6: ipv6);
  }

  void close({bool? ipv6}) => _dualHandler.close(ipv6: ipv6);

  DateTime? get ipv4LastStunUpdated => _dualHandler.ipv4LastStunUpdated;
  DateTime? get ipv6LastStunUpdated => _dualHandler.ipv6LastStunUpdated;
  DateTime? get ipv4LastLocalUpdated => _dualHandler.ipv4LastLocalUpdated;
  DateTime? get ipv6LastLocalUpdated => _dualHandler.ipv6LastLocalUpdated;
  DateTime? get lastStunUpdated => _dualHandler.lastStunUpdated;
  DateTime? get lastLocalUpdated => _dualHandler.lastLocalUpdated;

  Future<void> initializeDualHandlerDI() => _dualHandler.initializeDI();
}
