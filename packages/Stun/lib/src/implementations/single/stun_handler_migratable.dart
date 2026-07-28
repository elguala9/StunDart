import 'dart:io';

import '../../mixins/single/stun_handler_migratable_mixin.dart';
import '../../interfaces/single/i_stun_handler_migratable.dart';
import 'stun_handler.dart';

class StunHandlerMigratable extends StunHandler
    with StunHandlerMigratableMixin
    implements IStunHandlerMigratable {
  StunHandlerMigratable(super.input);

  /// Unset arguments fall back to [stunConfig].
  factory StunHandlerMigratable.withSocket(
    RawDatagramSocket socket, {
    String? address,
    int? port,
    Duration? timeout,
    void Function(String)? onLog,
  }) {
    return StunHandlerMigratable((
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
    final handler = StunHandlerMigratable((
      address: address,
      port: port,
      socket: null,
    ));
    await handler.socketMgr.getSocket();
    return handler;
  }
}
