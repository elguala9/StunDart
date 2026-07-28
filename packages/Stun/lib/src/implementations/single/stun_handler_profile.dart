import 'dart:io';

import 'package:config_manager/config_manager.dart';

import '../../config/stun_config.dart';
import '../../interfaces/single/i_stun_handler.dart';
import '../../interfaces/single/i_stun_handler_profile.dart';

class StunHandlerProfile
    with ConfigExtension, StunConfigExtension
    implements IStunHandlerProfile {
  /// Unset arguments fall back to the STUN configuration.
  StunHandlerProfile({
    String? stunAddress,
    int? stunPort,
    InternetAddressType? ipVersion,
    Duration? timeout,
    this.onLog,
  }) {
    this.stunAddress = stunAddress ?? defaultStunAddress;
    this.stunPort = stunPort ?? defaultStunPort;
    this.ipVersion = ipVersion ?? defaultIpVersion;
    this.timeout = timeout ?? defaultTimeout;
  }

  @override
  late final String stunAddress;
  @override
  late final int stunPort;
  @override
  late final InternetAddressType ipVersion;
  @override
  late final Duration timeout;
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
