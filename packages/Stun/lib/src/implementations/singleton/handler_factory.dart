import 'package:singleton_manager/singleton_manager.dart';

import '../../mixins/handler_factory_mixin.dart';
import '../../types/stun_types.dart';
import '../../interfaces/i_stun_handler.dart';

/// Base factory for creating STUN handler instances (IPv4 and IPv6)
@isSingleton
class HandlerFactory with HandlerFactoryMixin {
  const HandlerFactory();

  /// Creates IPv4 handler without socket
  Future<IStunHandler> createIpv4Handler({
    String? address,
    int? port,
    Duration timeout = const Duration(seconds: 5),
    OnSocketRefresh? onSocketRefresh,
  }) => createHandler(
    ipv6: false,
    address: address,
    port: port,
    timeout: timeout,
    onSocketRefresh: onSocketRefresh,
  );

  /// Creates IPv6 handler without socket
  Future<IStunHandler> createIpv6Handler({
    String? address,
    int? port,
    Duration timeout = const Duration(seconds: 5),
    OnSocketRefresh? onSocketRefresh,
  }) => createHandler(
    ipv6: true,
    address: address,
    port: port,
    timeout: timeout,
    onSocketRefresh: onSocketRefresh,
  );
}
