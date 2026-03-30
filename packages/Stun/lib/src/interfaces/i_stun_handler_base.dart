import 'dart:io';

import 'package:singleton_manager/singleton_manager.dart';

import '../types/stun_types.dart';
import 'i_dual_stun_handler.dart';
import 'i_stun_handler.dart';

/// Contract for the high-level STUN handler that manages dual IPv4/IPv6 stacks.
/// Extends [IValueForRegistry] so instances can be registered via [RegistryAccess].
abstract interface class IStunHandlerBase implements IValueForRegistry {
  IDualStunHandler get dualHandler;

  IStunHandler get ipv4Handler;
  IStunHandler? get ipv6Handler;

  void replaceHandler(IStunHandler handler, {required bool ipv6});

  Future<StunResponse> performStunRequest();
  Future<LocalInfo> performLocalRequest();

  Future<bool> pingStunServer({bool ipv6 = true});
  RawDatagramSocket getSocket({bool ipv6 = true});

  void setStunServer(String address, int port, {bool? ipv6});
  void close({bool? ipv6});

  DateTime? get ipv4LastStunUpdated;
  DateTime? get ipv6LastStunUpdated;
  DateTime? get ipv4LastLocalUpdated;
  DateTime? get ipv6LastLocalUpdated;
  DateTime? get lastStunUpdated;
  DateTime? get lastLocalUpdated;

  Future<void> initialize({
    String? address,
    int? port,
    Duration timeout = const Duration(seconds: 5),
  });

  Future<void> initializeWithHandlers(
    IStunHandler ipv4Handler, {
    IStunHandler? ipv6Handler,
  });

  void setIpv4Handler(IStunHandler handler);
  void setIpv6Handler(IStunHandler? handler);

  void setOnSocketRefreshIpv4(OnSocketRefreshIpv4 callback);
  void setOnSocketRefreshIpv6(OnSocketRefreshIpv6 callback);
  void removeOnSocketRefreshIpv4();
  void removeOnSocketRefreshIpv6();
}
