import 'dart:io';

import 'package:singleton_manager/singleton_manager.dart';
import 'package:stun/src/interfaces/i_stun_handler.dart';
import 'package:stun/src/interfaces/i_stun_handler_base.dart';
import 'package:stun/src/types/stun_types.dart';

/// Interface for managing dual IPv4 and IPv6 STUN handlers
/// Handles parallel request execution and state management
abstract class IDualStunHandler
    implements IStunHandlerBase, ISingletonStandardDI {
  Future<void> initialize({String? address, int? port, Duration timeout = const Duration(seconds: 5)});
  Future<void> initializeWithHandlers(IStunHandler ipv4Handler, {IStunHandler? ipv6Handler});
  void setOnSocketRefresh(OnSocketRefresh callback, {bool ipv6 = true});
  void clearOnSocketRefresh({bool ipv6 = true});
  IStunHandler? getHandler({bool ipv6 = true});
  void setHandler(IStunHandler handler, {bool ipv6 = true});
  void clearHandler({bool ipv6 = true});
  void replaceHandler(IStunHandler handler, {bool ipv6 = true});
  @override
  RawDatagramSocket getSocket({bool ipv6 = true});
  @override
  void setStunServer(String address, int port, {bool? ipv6});
  @override
  void close({bool? ipv6});
  DateTime? getLastStunUpdated({bool ipv6 = true});
  DateTime? getLastLocalUpdated({bool ipv6 = true});

  IStunHandler? get ipv4Handler => getHandler(ipv6: false);
  IStunHandler? get ipv6Handler => getHandler(ipv6: true);
}
