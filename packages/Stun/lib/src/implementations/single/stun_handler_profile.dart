import 'dart:io';

import '../../interfaces/single/i_stun_handler.dart';
import '../../interfaces/single/i_stun_handler_profile.dart';

class StunHandlerProfile implements IStunHandlerProfile {
  StunHandlerProfile({
    required this.stunAddress,
    required this.stunPort,
    this.ipVersion = InternetAddressType.IPv4,
    this.timeout = const Duration(seconds: 5),
    this.onLog,
  });

  @override
  final String stunAddress;
  @override
  final int stunPort;
  @override
  final InternetAddressType ipVersion;
  @override
  final Duration timeout;
  @override
  final void Function(String)? onLog;

  @override
  void applyTo(IStunHandler target) {
    target.setStunServer(stunAddress, stunPort);
  }

  StunHandlerProfile copyWith({
    String? stunAddress,
    int? stunPort,
    InternetAddressType? ipVersion,
    Duration? timeout,
    void Function(String)? onLog,
  }) {
    return StunHandlerProfile(
      stunAddress: stunAddress ?? this.stunAddress,
      stunPort: stunPort ?? this.stunPort,
      ipVersion: ipVersion ?? this.ipVersion,
      timeout: timeout ?? this.timeout,
      onLog: onLog ?? this.onLog,
    );
  }
}
