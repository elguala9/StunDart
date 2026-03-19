import '../types/stun_types.dart';

abstract interface class IDualCallbackHandler {
  OnSocketRefresh get onIpv4;
  OnSocketRefresh get onIpv6;

  void registerIpv4(void Function((StunResponse, StunResponse?)) wrapper);
  void registerIpv6(void Function((StunResponse, StunResponse?)) wrapper);

  void clearIpv4();
  void clearIpv6();
}
