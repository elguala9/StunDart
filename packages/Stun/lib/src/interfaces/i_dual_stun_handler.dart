import 'dart:io';
import 'package:singleton_manager/singleton_manager.dart';
import 'package:stun/src/interfaces/i_stun_handler_base.dart';

import '../types/stun_types.dart';
import 'i_stun_handler.dart';

/// Interface for managing dual IPv4 and IPv6 STUN handlers
/// Handles parallel request execution and state management
abstract class IDualStunHandler implements ISingletonStandardDI {
  /// IPv4 handler (optional, null if unavailable or after close)
  IStunHandler? get ipv4Handler;

  /// IPv6 handler (optional, null if unavailable or after close)
  IStunHandler? get ipv6Handler;

  /// Sets the IPv4 handler (can be null)
  void setIpv4Handler(IStunHandler? handler);

  /// Sets the IPv6 handler (can be null)
  void setIpv6Handler(IStunHandler? handler);

  /// Replaces a specific handler (IPv4 or IPv6)
  void replaceHandler(IStunHandler handler, {required bool ipv6});

  /// Performs STUN request. Runs on both handlers in parallel when both are
  /// available (IPv6 preferred, falls back to IPv4 on IPv6 failure); runs on
  /// whichever single handler is available otherwise.
  /// Throws [StateError] if neither handler is initialized.
  Future<StunResponse> performStunRequest();

  /// Performs local request. Runs on both handlers in parallel when both are
  /// available (IPv6 preferred, falls back to IPv4 on IPv6 failure); runs on
  /// whichever single handler is available otherwise.
  /// Throws [StateError] if neither handler is initialized.
  Future<LocalInfo> performLocalRequest();

  /// Pings the STUN server on specified handler
  Future<bool> pingStunServer({bool ipv6 = true});

  /// Gets socket from specified handler
  RawDatagramSocket getSocket({bool ipv6 = true});

  /// Sets STUN server on specified handler(s)
  /// If ipv6 is null, sets on both handlers
  void setStunServer(String address, int port, {bool? ipv6});

  /// Closes handler socket(s)
  /// If ipv6 is null, closes both; ipv6=false closes IPv4 only; ipv6=true closes IPv6 only
  void close({bool? ipv6});

  /// Timestamp of last successful IPv4 STUN request
  DateTime? get ipv4LastStunUpdated;

  /// Timestamp of last successful IPv6 STUN request
  DateTime? get ipv6LastStunUpdated;

  /// Timestamp of last successful IPv4 local request
  DateTime? get ipv4LastLocalUpdated;

  /// Timestamp of last successful IPv6 local request
  DateTime? get ipv6LastLocalUpdated;

  /// Most recent STUN update timestamp (IPv6 if available, else IPv4)
  DateTime? get lastStunUpdated;

  /// Most recent local update timestamp (IPv6 if available, else IPv4)
  DateTime? get lastLocalUpdated;

  /// Initialize dependency injection - registers handlers in DI container
  @override
  Future<void> initializeDI();
}
