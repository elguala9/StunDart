import 'dart:io';
import '../types/stun_types.dart';
import '../interfaces/i_stun_handler.dart';
import 'stun_handler.dart';

/// Singleton wrapper for StunHandler that implements IStunHandler
/// Provides a global instance and the ability to replace the internal handler
class StunHandlerSingleton implements IStunHandler {
  /// Factory constructor - ensures only one instance exists
  factory StunHandlerSingleton() => _instance;

  /// Private constructor for singleton pattern
  StunHandlerSingleton._internal();

  static final StunHandlerSingleton _instance = StunHandlerSingleton._internal();

  IStunHandler? _handler;

  /// Get the singleton instance
  static StunHandlerSingleton get instance => _instance;

  /// Creates a new StunHandler and replaces the current one
  /// Returns the newly created handler
  Future<IStunHandler> createNewHandler({
    String? address,
    int? port,
    bool ipv6 = false,
  }) async {
    _handler = await StunHandler.withoutSocket(
      address: address,
      port: port,
      ipv6: ipv6,
    );
    return _handler!;
  }

  /// Replaces the current handler with a provided one
  void replaceHandler(IStunHandler handler) => _handler = handler;

  /// Gets the current internal handler
  /// Throws StateError if no handler has been initialized
  IStunHandler _getHandler() {
    if (_handler == null) {
      throw StateError(
        'StunHandlerSingleton: No handler initialized. Call createNewHandler() first.',
      );
    }
    return _handler!;
  }

  @override
  Future<StunResponse> performStunRequest() => _getHandler().performStunRequest();

  @override
  Future<LocalInfo> performLocalRequest() => _getHandler().performLocalRequest();

  @override
  Future<bool> pingStunServer() => _getHandler().pingStunServer();

  @override
  void setStunServer(String address, int port) => _getHandler().setStunServer(address, port);

  @override
  RawDatagramSocket getSocket() => _getHandler().getSocket();

  @override
  void close() {
    _getHandler().close();
    _handler = null;
  }
}
