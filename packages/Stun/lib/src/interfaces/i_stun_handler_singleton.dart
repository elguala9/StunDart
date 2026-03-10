import 'dart:io';

import '../types/stun_types.dart';
import 'i_stun_handler.dart';

abstract interface class IStunHandlerSingleton {
  Future<void> initialize({
    String? address,
    int? port,
    Duration timeout,
    void Function(String)? onLog,
    OnSingletonSocketRefresh? onSocketRefresh,
  });
  Future<void> initializeWithHandlers(
    IStunHandler ipv4Handler, {
    IStunHandler? ipv6Handler,
  });
  IStunHandler get ipv4Handler;
  IStunHandler? get ipv6Handler;
  void setIpv4Handler(IStunHandler handler);
  void setIpv6Handler(IStunHandler? handler);
  void replaceHandler(IStunHandler handler, {required bool ipv6});
  Future<StunResponse> performStunRequest();
  Future<LocalInfo> performLocalRequest();
  Future<bool> pingStunServer({bool ipv6 = true});
  RawDatagramSocket getSocket({bool ipv6 = true});
  void setStunServer(String address, int port, {bool? ipv6});
  void close({bool? ipv6});

  /// Timestamp of the last successful STUN request on IPv4 handler
  DateTime? get ipv4LastStunUpdated;

  /// Timestamp of the last successful STUN request on IPv6 handler
  DateTime? get ipv6LastStunUpdated;

  /// Timestamp of the last successful local request on IPv4 handler
  DateTime? get ipv4LastLocalUpdated;

  /// Timestamp of the last successful local request on IPv6 handler
  DateTime? get ipv6LastLocalUpdated;

  /// Timestamp of the most recent STUN request (IPv6 if available, else IPv4)
  DateTime? get lastStunUpdated;

  /// Timestamp of the most recent local request (IPv6 if available, else IPv4)
  DateTime? get lastLocalUpdated;

  /// Registers a callback to be fired when either handler's socket is recreated after network error
  void addOnSocketRefresh(OnSingletonSocketRefresh callback);

  /// Unregisters a previously added socket refresh callback
  void removeOnSocketRefresh(OnSingletonSocketRefresh callback);

  /// Sets IPv4-specific socket refresh callback with type validation
  /// Throws [ArgumentError] if socket type doesn't match IPv4
  /// Throws [StateError] if IPv4 handler is not initialized
  void setOnSocketRefreshIpv4(OnSocketRefreshIpv4 callback);

  /// Sets IPv6-specific socket refresh callback with type validation
  /// Throws [ArgumentError] if socket type doesn't match IPv6
  /// Throws [StateError] if IPv6 handler is not initialized or not available
  void setOnSocketRefreshIpv6(OnSocketRefreshIpv6 callback);

  /// Removes IPv4-specific socket refresh callback
  void removeOnSocketRefreshIpv4();

  /// Removes IPv6-specific socket refresh callback
  void removeOnSocketRefreshIpv6();
}
