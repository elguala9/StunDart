import 'dart:io';
import '../types/stun_types.dart';
import 'i_stun_handler.dart';

abstract interface class IStunHandlerSingleton {
  Future<void> initialize({
    String? address,
    int? port,
    Duration timeout,
    void Function(String)? onLog,
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
}
