import 'dart:io';

import '../../mixins/single/stun_handler_migratable_mixin.dart';
import '../../interfaces/single/i_stun_handler_migratable.dart';
import 'stun_handler.dart';

class StunHandlerMigratable extends StunHandler
    with StunHandlerMigratableMixin
    implements IStunHandlerMigratable {
  StunHandlerMigratable(super.input);

  factory StunHandlerMigratable.withSocket(
    RawDatagramSocket socket, {
    String? address,
    int? port,
    Duration timeout = const Duration(seconds: 5),
    void Function(String)? onLog,
  }) {
    return StunHandlerMigratable(
      (address: address, port: port, socket: socket),
    );
  }

  static Future<StunHandlerMigratable> withoutSocket({
    String? address,
    int? port,
    InternetAddressType type = InternetAddressType.IPv4,
    Duration timeout = const Duration(seconds: 5),
    void Function(String)? onLog,
  }) async {
    final handler = StunHandlerMigratable(
      (address: address, port: port, socket: null),
    );
    await handler.socketMgr.getSocket();
    return handler;
  }
}
