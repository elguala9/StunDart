import 'package:singleton_manager/singleton_manager.dart';

import '../../types/stun_types.dart';
import '../../interfaces/i_stun_handler.dart';
import '../handlers/stun_handler.dart';

/// Base factory for creating STUN handler instances (IPv4 and IPv6)
@isSingleton
class HandlerFactory {
  const HandlerFactory();

  /// Creates IPv4 handler without socket
  Future<IStunHandler> createIpv4Handler({
    String? address,
    int? port,
    Duration timeout = const Duration(seconds: 5),
    OnSocketRefresh? onSocketRefresh,
  }) =>
      StunHandler.withoutSocket(
        address: address,
        port: port,
        ipv6: false,
        timeout: timeout,
        onSocketRefresh: onSocketRefresh,
      );

  /// Creates IPv6 handler without socket
  Future<IStunHandler> createIpv6Handler({
    String? address,
    int? port,
    Duration timeout = const Duration(seconds: 5),
    OnSocketRefresh? onSocketRefresh,
  }) =>
      StunHandler.withoutSocket(
        address: address,
        port: port,
        ipv6: true,
        timeout: timeout,
        onSocketRefresh: onSocketRefresh,
      );
}
