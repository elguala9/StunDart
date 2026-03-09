import '../../types/stun_types.dart';
import '../../interfaces/i_stun_handler.dart';

/// Handles dual-stack request execution (IPv4 + IPv6 in parallel)
class SingletonDualRequest {
  /// Performs STUN request on both handlers (if available) and caches results
  /// Returns best result: IPv6 if available, otherwise IPv4
  static Future<StunResponse> performStunRequest({
    required IStunHandler ipv4Handler,
    required IStunHandler? ipv6Handler,
  }) async {
    if (ipv6Handler != null) {
      try {
        // Execute both in parallel
        final results = await Future.wait([
          ipv4Handler.performStunRequest(),
          ipv6Handler.performStunRequest(),
        ]);
        // Prefer IPv6 result if available
        return results[1];
      } catch (e) {
        // If IPv6 fails, fall back to IPv4
        return ipv4Handler.performStunRequest();
      }
    } else {
      return ipv4Handler.performStunRequest();
    }
  }

  /// Performs local request on both handlers (if available) and caches results
  /// Returns best result: IPv6 if available, otherwise IPv4
  static Future<LocalInfo> performLocalRequest({
    required IStunHandler ipv4Handler,
    required IStunHandler? ipv6Handler,
  }) async {
    if (ipv6Handler != null) {
      try {
        // Execute both in parallel
        final results = await Future.wait([
          ipv4Handler.performLocalRequest(),
          ipv6Handler.performLocalRequest(),
        ]);
        // Prefer IPv6 result if available
        return results[1];
      } catch (e) {
        // If IPv6 fails, fall back to IPv4
        return ipv4Handler.performLocalRequest();
      }
    } else {
      return ipv4Handler.performLocalRequest();
    }
  }
}
