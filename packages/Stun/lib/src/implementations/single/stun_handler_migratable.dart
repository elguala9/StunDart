import 'dart:io';

import 'package:singleton_manager/singleton_manager.dart';

import '../../mixins/single/stun_handler_migratable_mixin.dart';
import '../../interfaces/single/i_stun_handler_migratable.dart';
import '../../types/stun_types.dart';
import 'stun_handler.dart';

@dependencyInjectable
class StunHandlerMigratable extends StunHandler
    with StunHandlerMigratableMixin
    implements IStunHandlerMigratable {
  StunHandlerMigratable(@Subkey.inherited() super.input);

  factory StunHandlerMigratable.dependencyInjectionFactory({String key = 'default', String subkey = 'default'}) { // GENERATED CODE - DO NOT MODIFY BY HAND
    final input = RegistryManager.instance.getInstance<StunHandlerInput>(key: key, subkey: subkey); // GENERATED CODE - DO NOT MODIFY BY HAND

    return StunHandlerMigratable( // GENERATED CODE - DO NOT MODIFY BY HAND
      input, // GENERATED CODE - DO NOT MODIFY BY HAND
    ); // GENERATED CODE - DO NOT MODIFY BY HAND
  } // GENERATED CODE - DO NOT MODIFY BY HAND

  /// Unset arguments fall back to [stunConfig].
  factory StunHandlerMigratable.withSocket(
    RawDatagramSocket socket, {
    String? address,
    int? port,
    Duration? timeout,
    void Function(String)? onLog,
  }) {
    return StunHandlerMigratable(StunHandlerInput(
      address: address,
      port: port,
      socket: socket,
    ));
  }

  /// Unset arguments fall back to [stunConfig].
  static Future<StunHandlerMigratable> withoutSocket({
    String? address,
    int? port,
    InternetAddressType? type,
    Duration? timeout,
    void Function(String)? onLog,
  }) async {
    final handler = StunHandlerMigratable(StunHandlerInput(
      address: address,
      port: port,
      socket: null,
    ));
    await handler.socketMgr.getSocket();
    return handler;
  }
}
