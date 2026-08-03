import 'dart:io';

import 'package:singleton_manager/singleton_manager.dart';

import '../../config/stun_config.dart';
import '../../mixins/single/stun_handler_migratable_mixin.dart';
import '../../interfaces/single/i_stun_handler_migratable.dart';
import 'stun_handler.dart';
import 'stun_socket_manager.dart';

@dependencyInjectable
class StunHandlerMigratable extends StunHandler
    with StunHandlerMigratableMixin
    implements IStunHandlerMigratable {
  StunHandlerMigratable(
    @Subkey.inherited() super.socket, {
    super.address,
    super.port,
    super.timeout,
    super.onLog,
  });

  factory StunHandlerMigratable.dependencyInjectionFactory({String key = 'default', String subkey = 'default'}) { // GENERATED CODE - DO NOT MODIFY BY HAND
    final socket = RegistryManager.instance.getInstance<RawDatagramSocket>(key: key, subkey: subkey); // GENERATED CODE - DO NOT MODIFY BY HAND
    final address = RegistryManager.instance.getInstanceNullable<String>(key: key); // GENERATED CODE - DO NOT MODIFY BY HAND
    final port = RegistryManager.instance.getInstanceNullable<int>(key: key); // GENERATED CODE - DO NOT MODIFY BY HAND
    final timeout = RegistryManager.instance.getInstanceNullable<Duration>(key: key); // GENERATED CODE - DO NOT MODIFY BY HAND

    return StunHandlerMigratable( // GENERATED CODE - DO NOT MODIFY BY HAND
      socket, // GENERATED CODE - DO NOT MODIFY BY HAND
      address: address, // GENERATED CODE - DO NOT MODIFY BY HAND
      port: port, // GENERATED CODE - DO NOT MODIFY BY HAND
      timeout: timeout, // GENERATED CODE - DO NOT MODIFY BY HAND
    ); // GENERATED CODE - DO NOT MODIFY BY HAND
  } // GENERATED CODE - DO NOT MODIFY BY HAND

  /// Creates a handler that binds its own socket.
  ///
  /// Unset arguments fall back to the STUN configuration.
  static Future<StunHandlerMigratable> withoutSocket({
    String? address,
    int? port,
    InternetAddressType? type,
    Duration? timeout,
    void Function(String)? onLog,
  }) async {
    final socket = await StunSocketManager.bindSocket(
      bindType: type ?? defaultStunIpVersion(),
      onLog: onLog,
    );
    return StunHandlerMigratable(
      socket,
      address: address,
      port: port,
      timeout: timeout,
      onLog: onLog,
    );
  }
}
