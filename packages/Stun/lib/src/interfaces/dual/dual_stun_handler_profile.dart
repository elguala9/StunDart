import 'dart:io';

import 'i_dual_stun_handler.dart';
import 'i_dual_stun_handler_profile.dart';
import '../../implementations/single/stun_handler_profile.dart';

class DualStunHandlerProfile implements IDualStunHandlerProfile {
  DualStunHandlerProfile({
    this.ipv4,
    this.ipv6,
  });

  @override
  final StunHandlerProfile? ipv4;
  @override
  final StunHandlerProfile? ipv6;

  @override
  StunHandlerProfile? profileFor(InternetAddressType type) =>
      type == InternetAddressType.IPv4 ? ipv4 : ipv6;

  @override
  void applyTo(
    IDualStunHandler target, {
    InternetAddressType? type,
  }) {
    void applyFamily(InternetAddressType family) {
      final profile = profileFor(family);
      if (profile != null) {
        target.setStunServer(
          profile.stunAddress,
          profile.stunPort,
          type: family,
        );
      }
    }

    if (type == null) {
      applyFamily(InternetAddressType.IPv4);
      applyFamily(InternetAddressType.IPv6);
    } else {
      applyFamily(type);
    }
  }
}
