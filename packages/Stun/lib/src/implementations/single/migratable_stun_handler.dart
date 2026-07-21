import 'dart:io';

import '../../mixins/single/stun_handler_migratable_mixin.dart';
import '../../interfaces/single/i_stun_handler_migratable.dart';
import '../../types/stun_types.dart';
import 'stun_handler.dart';

class MigratableStunHandler extends StunHandler
    with StunHandlerMigratableMixin
    implements IStunHandlerMigratable {
  MigratableStunHandler(super.input, {super.onSocketRefresh});

  factory MigratableStunHandler.withSocket(
    RawDatagramSocket socket, {
    String? address,
    int? port,
    Duration timeout = const Duration(seconds: 5),
    void Function(String)? onLog,
    OnSocketRefresh? onSocketRefresh,
  }) {
    return MigratableStunHandler(
      (address: address, port: port, socket: socket),
      onSocketRefresh: onSocketRefresh,
    );
  }

  static Future<MigratableStunHandler> withoutSocket({
    String? address,
    int? port,
    InternetAddressType type = InternetAddressType.IPv4,
    Duration timeout = const Duration(seconds: 5),
    void Function(String)? onLog,
    OnSocketRefresh? onSocketRefresh,
  }) async {
    final handler = MigratableStunHandler(
      (address: address, port: port, socket: null),
      onSocketRefresh: onSocketRefresh,
    );
    await handler.socketMgr.getSocket();
    return handler;
  }
}
