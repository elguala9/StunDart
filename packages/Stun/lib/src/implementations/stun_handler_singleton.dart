import 'dart:io';
import 'package:callback_handler/callback_handler.dart';

import '../types/stun_types.dart';
import '../interfaces/i_stun_handler.dart';
import '../interfaces/i_stun_handler_singleton.dart';
import 'stun_handler.dart';

/// Singleton wrapper for managing dual IPv4 and IPv6 STUN handlers
class StunHandlerSingleton implements IStunHandlerSingleton {
  /// Factory constructor - ensures only one instance exists
  factory StunHandlerSingleton() => _instance;

  /// Private constructor for singleton pattern
  StunHandlerSingleton._internal();

  static final StunHandlerSingleton _instance = StunHandlerSingleton._internal();

  IStunHandler? _ipv4Handler; // Non-null after initialize(), null after close()
  IStunHandler? _ipv6Handler; // May be null if IPv6 not supported or after close()
  void Function(String)? _onLog; // Optional logging callback
  late final CallbackHandler<(StunResponse, StunResponse?, bool), void> _socketRefreshHandler = CallbackHandler(); // Socket refresh handler

  /// Helper method to log messages
  void _log(String message) => _onLog?.call(message);

  /// Helper to get the later of two timestamps
  static DateTime? _laterOf(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  /// Get the singleton instance
  static StunHandlerSingleton get instance => _instance;

  /// Creates both IPv4 and IPv6 handlers
  /// IPv4 is always created; IPv6 is optional (fails gracefully if unavailable)
  @override
  Future<void> initialize({
    String? address,
    int? port,
    Duration timeout = const Duration(seconds: 5),
    void Function(String)? onLog,
    OnSingletonSocketRefresh? onSocketRefresh,
  }) async {
    _onLog = onLog;

    // Create closure wrappers to convert OnSingletonSocketRefresh to OnSocketRefresh
    final OnSocketRefresh? ipv4Callback = onSocketRefresh == null
        ? null
        : (newRes, oldRes) => onSocketRefresh(newRes, oldRes, ipv6: false);

    final OnSocketRefresh? ipv6Callback = onSocketRefresh == null
        ? null
        : (newRes, oldRes) => onSocketRefresh(newRes, oldRes, ipv6: true);

    _ipv4Handler =
        await _createIpv4Handler(address, port, timeout, onLog, ipv4Callback);
    _ipv6Handler = await _createIpv6HandlerSafe(
        address, port, timeout, onLog, ipv6Callback);
  }

  /// Initializes the singleton with provided handler instances
  /// Useful for DI and testing
  @override
  Future<void> initializeWithHandlers(
    IStunHandler ipv4Handler, {
    IStunHandler? ipv6Handler,
  }) async {
    _ipv4Handler = ipv4Handler;
    _ipv6Handler = ipv6Handler;
  }

  /// Creates IPv4 handler without socket
  Future<IStunHandler> _createIpv4Handler(
    String? address,
    int? port,
    Duration timeout,
    void Function(String)? onLog,
    OnSocketRefresh? onSocketRefresh,
  ) =>
      StunHandler.withoutSocket(
        address: address,
        port: port,
        ipv6: false,
        timeout: timeout,
        onLog: onLog,
        onSocketRefresh: onSocketRefresh,
      );

  /// Creates IPv6 handler without socket (returns null if unavailable)
  Future<IStunHandler?> _createIpv6HandlerSafe(
    String? address,
    int? port,
    Duration timeout,
    void Function(String)? onLog,
    OnSocketRefresh? onSocketRefresh,
  ) async {
    try {
      return await StunHandler.withoutSocket(
        address: address,
        port: port,
        ipv6: true,
        timeout: timeout,
        onLog: onLog,
        onSocketRefresh: onSocketRefresh,
      );
    } catch (e) {
      _log('IPv6 handler initialization failed: $e');
      return null;
    }
  }

  /// Sets IPv4 handler
  @override
  void setIpv4Handler(IStunHandler handler) => _ipv4Handler = handler;

  /// Sets IPv6 handler
  @override
  void setIpv6Handler(IStunHandler? handler) => _ipv6Handler = handler;

  /// Gets a handler, throwing StateError if handler is not available
  IStunHandler _getHandler({required bool ipv6}) {
    if (ipv6) {
      if (_ipv6Handler == null) {
        throw StateError(
          'StunHandlerSingleton: IPv6 handler not initialized or not available. Call initialize() first.',
        );
      }
      return _ipv6Handler!;
    } else {
      if (_ipv4Handler == null) {
        throw StateError(
          'StunHandlerSingleton: IPv4 handler not initialized. Call initialize() first.',
        );
      }
      return _ipv4Handler!;
    }
  }

  /// Direct access to IPv4 handler (may be null if not initialized or closed)
  @override
  IStunHandler get ipv4Handler => _getHandler(ipv6: false);

  /// Direct access to IPv6 handler (may be null if not initialized or closed)
  @override
  IStunHandler? get ipv6Handler => _ipv6Handler;

  /// Replaces a specific handler (IPv4 or IPv6)
  @override
  void replaceHandler(IStunHandler handler, {required bool ipv6}) {
    if (ipv6) {
      _ipv6Handler = handler;
    } else {
      _ipv4Handler = handler;
    }
  }

  /// Performs STUN request on both handlers (if available) and caches results
  /// Returns best result: IPv6 if available, otherwise IPv4
  @override
  Future<StunResponse> performStunRequest() async {
    final ipv4 = _ipv4Handler;
    if (ipv4 == null) {
      throw StateError(
        'StunHandlerSingleton: IPv4 handler not initialized. Call initialize() first.',
      );
    }

    if (_ipv6Handler != null) {
      try {
        // Execute both in parallel
        final results = await Future.wait([
          ipv4.performStunRequest(),
          _ipv6Handler!.performStunRequest(),
        ]);
        // Prefer IPv6 result if available
        return results[1];
      } catch (e) {
        // If IPv6 fails, fall back to IPv4
        return ipv4.performStunRequest();
      }
    } else {
      return ipv4.performStunRequest();
    }
  }

  /// Performs local request on both handlers (if available) and caches results
  /// Returns best result: IPv6 if available, otherwise IPv4
  @override
  Future<LocalInfo> performLocalRequest() async {
    final ipv4 = _ipv4Handler;
    if (ipv4 == null) {
      throw StateError(
        'StunHandlerSingleton: IPv4 handler not initialized. Call initialize() first.',
      );
    }

    if (_ipv6Handler != null) {
      try {
        // Execute both in parallel
        final results = await Future.wait([
          ipv4.performLocalRequest(),
          _ipv6Handler!.performLocalRequest(),
        ]);
        // Prefer IPv6 result if available
        return results[1];
      } catch (e) {
        // If IPv6 fails, fall back to IPv4
        return ipv4.performLocalRequest();
      }
    } else {
      return ipv4.performLocalRequest();
    }
  }

  /// Ping STUN server on specific handler
  @override
  Future<bool> pingStunServer({bool ipv6 = true}) =>
      _getHandler(ipv6: ipv6).pingStunServer();

  /// Get socket from specific handler
  @override
  RawDatagramSocket getSocket({bool ipv6 = true}) =>
      _getHandler(ipv6: ipv6).getSocket();

  /// Sets STUN server on specified handler(s)
  /// null = apply to both
  @override
  void setStunServer(String address, int port, {bool? ipv6}) {
    if (ipv6 == null || ipv6 == false) {
      _ipv4Handler?.setStunServer(address, port);
    }
    if (ipv6 == null || ipv6 == true) {
      _ipv6Handler?.setStunServer(address, port);
    }
  }

  /// Closes specified handler(s)
  /// null = close both
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

  /// Timestamp of the last successful STUN request on IPv4 handler
  @override
  DateTime? get ipv4LastStunUpdated => _ipv4Handler?.lastStunUpdated;

  /// Timestamp of the last successful STUN request on IPv6 handler
  @override
  DateTime? get ipv6LastStunUpdated => _ipv6Handler?.lastStunUpdated;

  /// Timestamp of the last successful local request on IPv4 handler
  @override
  DateTime? get ipv4LastLocalUpdated => _ipv4Handler?.lastLocalUpdated;

  /// Timestamp of the last successful local request on IPv6 handler
  @override
  DateTime? get ipv6LastLocalUpdated => _ipv6Handler?.lastLocalUpdated;

  /// Timestamp of the most recent STUN request (IPv6 if available, else IPv4)
  @override
  DateTime? get lastStunUpdated => _laterOf(ipv4LastStunUpdated, ipv6LastStunUpdated);

  /// Timestamp of the most recent local request (IPv6 if available, else IPv4)
  @override
  DateTime? get lastLocalUpdated => _laterOf(ipv4LastLocalUpdated, ipv6LastLocalUpdated);
}
