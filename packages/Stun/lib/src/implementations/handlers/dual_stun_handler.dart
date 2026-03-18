import 'dart:io';
import 'package:singleton_manager/singleton_manager.dart';
import '../../types/stun_types.dart';
import '../../interfaces/i_stun_handler.dart';
import '../../interfaces/i_dual_stun_handler.dart';

/// Manages dual IPv4 and IPv6 STUN handlers with parallel request execution
class DualStunHandler implements IDualStunHandler {
  IStunHandler? _ipv4Handler;
  IStunHandler? _ipv6Handler;

  @override
  IStunHandler? get ipv4Handler => _ipv4Handler;

  @override
  IStunHandler? get ipv6Handler => _ipv6Handler;

  @override
  void setIpv4Handler(IStunHandler handler) {
    _ipv4Handler = handler;
  }

  @override
  void setIpv6Handler(IStunHandler? handler) {
    _ipv6Handler = handler;
  }

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
    if (_ipv4Handler == null) {
      throw StateError('DualStunHandler: IPv4 handler not initialized');
    }

    if (_ipv6Handler != null) {
      // Execute both in parallel, continue even if one fails
      final results = await Future.wait(
        [
          _ipv4Handler!.performStunRequest(),
          _ipv6Handler!.performStunRequest(),
        ],
        eagerError: false,
      );
      // Prefer IPv6 result if available
      return results[1];
    } else {
      return _ipv4Handler!.performStunRequest();
    }
  }

  @override
  Future<LocalInfo> performLocalRequest() async {
    if (_ipv4Handler == null) {
      throw StateError('DualStunHandler: IPv4 handler not initialized');
    }

    if (_ipv6Handler != null) {
      // Execute both in parallel, continue even if one fails
      final results = await Future.wait(
        [
          _ipv4Handler!.performLocalRequest(),
          _ipv6Handler!.performLocalRequest(),
        ],
        eagerError: false,
      );
      // Prefer IPv6 result if available
      return results[1];
    } else {
      return _ipv4Handler!.performLocalRequest();
    }
  }

  @override
  Future<bool> pingStunServer({bool ipv6 = true}) {
    if (ipv6) {
      if (_ipv6Handler == null) {
        throw StateError('DualStunHandler: IPv6 handler not initialized or not available');
      }
      return _ipv6Handler!.pingStunServer();
    } else {
      if (_ipv4Handler == null) {
        throw StateError('DualStunHandler: IPv4 handler not initialized');
      }
      return _ipv4Handler!.pingStunServer();
    }
  }

  @override
  RawDatagramSocket getSocket({bool ipv6 = true}) {
    if (ipv6) {
      if (_ipv6Handler == null) {
        throw StateError('DualStunHandler: IPv6 handler not initialized or not available');
      }
      return _ipv6Handler!.getSocket();
    } else {
      if (_ipv4Handler == null) {
        throw StateError('DualStunHandler: IPv4 handler not initialized');
      }
      return _ipv4Handler!.getSocket();
    }
  }

  @override
  void setStunServer(String address, int port, {bool? ipv6}) {
    if (ipv6 == null || ipv6 == false) {
      _ipv4Handler?.setStunServer(address, port);
    }
    if (ipv6 == null || ipv6 == true) {
      _ipv6Handler?.setStunServer(address, port);
    }
  }

  @override
  void close({bool? ipv6}) {
    if (ipv6 == null || ipv6 == false) {
      _ipv4Handler?.close();
      _ipv4Handler = null;
    }
    if (ipv6 == null || ipv6 == true) {
      _ipv6Handler?.close();
      _ipv6Handler = null;
    }
  }

  /// Destroys the handler by closing all sockets
  void destroy() => close();

  @override
  DateTime? get ipv4LastStunUpdated => _ipv4Handler?.lastStunUpdated;

  @override
  DateTime? get ipv6LastStunUpdated => _ipv6Handler?.lastStunUpdated;

  @override
  DateTime? get ipv4LastLocalUpdated => _ipv4Handler?.lastLocalUpdated;

  @override
  DateTime? get ipv6LastLocalUpdated => _ipv6Handler?.lastLocalUpdated;

  static DateTime? _laterOf(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  @override
  DateTime? get lastStunUpdated => _laterOf(ipv4LastStunUpdated, ipv6LastStunUpdated);

  @override
  DateTime? get lastLocalUpdated => _laterOf(ipv4LastLocalUpdated, ipv6LastLocalUpdated);

  @override
  Future<void> initializeDI() async {
    // Register the dual handler in the DI container
    SingletonDI.registerFactory<DualStunHandler>(() => this);
    SingletonDIAccess.add<DualStunHandler>();
  }
}
