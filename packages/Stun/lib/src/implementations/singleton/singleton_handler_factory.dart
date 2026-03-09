import '../../types/stun_types.dart';
import '../../interfaces/i_stun_handler.dart';
import '../handlers/stun_handler.dart';

/// Factory for creating singleton handler instances (IPv4 and IPv6)
class SingletonHandlerFactory {
  SingletonHandlerFactory({this.onLog});

  final void Function(String)? onLog;

  void _log(String message) => onLog?.call(message);

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
        onLog: onLog,
        onSocketRefresh: onSocketRefresh,
      );

  /// Creates IPv6 handler without socket (returns null if unavailable)
  Future<IStunHandler?> createIpv6HandlerSafe({
    String? address,
    int? port,
    Duration timeout = const Duration(seconds: 5),
    OnSocketRefresh? onSocketRefresh,
  }) async {
    try {
      return await StunHandler.withoutSocket(
        address: address,
        port: port,
        ipv6: true,
        timeout: timeout,
        onLog: onLog,
        onSocketRefresh: onSocketRefresh,
      );
    } catch (e) {
      _log('IPv6 handler initialization failed: $e');
      return null;
    }
  }
}
