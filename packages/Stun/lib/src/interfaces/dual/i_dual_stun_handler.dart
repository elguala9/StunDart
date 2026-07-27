import 'dart:io';

import 'package:singleton_manager/singleton_manager.dart';
import '../single/i_stun_handler.dart';
import '../i_stun_handler_base.dart';

/// Interface for managing dual IPv4 and IPv6 STUN handlers
/// Handles parallel request execution and state management
abstract class IDualStunHandler
    implements IStunHandlerBase, ISingletonStandardDI {
  Future<void> initializeWithHandlers(IStunHandler first, {IStunHandler? second});
  IStunHandler? getHandler({InternetAddressType type = InternetAddressType.IPv6});
  void setHandler(IStunHandler handler, {InternetAddressType type = InternetAddressType.IPv6});
  void clearHandler({InternetAddressType type = InternetAddressType.IPv6});
  void replaceHandler(IStunHandler handler, {InternetAddressType type = InternetAddressType.IPv6});
  @override
  RawDatagramSocket getSocket({InternetAddressType type = InternetAddressType.IPv6});
  @override
  void setStunServer(String address, int port, {InternetAddressType? type});
  @override
  void close({InternetAddressType? type});
  DateTime? getLastStunUpdated({InternetAddressType type = InternetAddressType.IPv6});
  DateTime? getLastLocalUpdated({InternetAddressType type = InternetAddressType.IPv6});

  IStunHandler? get ipv4Handler => getHandler(type: InternetAddressType.IPv4);
  IStunHandler? get ipv6Handler => getHandler(type: InternetAddressType.IPv6);
}
