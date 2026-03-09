import '../../types/stun_types.dart';
import '../../interfaces/i_stun_handler.dart';

/// Manages handler state for singleton (IPv4 and IPv6 handlers with callbacks)
class SingletonHandlerState {
  IStunHandler? ipv4Handler;
  IStunHandler? ipv6Handler;
  final Map<OnSingletonSocketRefresh, (OnSocketRefresh, OnSocketRefresh)>
      callbackWrapperMap = {};

  DateTime? get ipv4LastStunUpdated => ipv4Handler?.lastStunUpdated;
  DateTime? get ipv6LastStunUpdated => ipv6Handler?.lastStunUpdated;
  DateTime? get ipv4LastLocalUpdated => ipv4Handler?.lastLocalUpdated;
  DateTime? get ipv6LastLocalUpdated => ipv6Handler?.lastLocalUpdated;

  static DateTime? laterOf(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  DateTime? get lastStunUpdated => laterOf(ipv4LastStunUpdated, ipv6LastStunUpdated);
  DateTime? get lastLocalUpdated => laterOf(ipv4LastLocalUpdated, ipv6LastLocalUpdated);

  void close({bool? ipv6}) {
    if (ipv6 == null || ipv6 == false) {
      ipv4Handler?.close();
      ipv4Handler = null;
    }
    if (ipv6 == null || ipv6 == true) {
      ipv6Handler?.close();
      ipv6Handler = null;
    }
  }
}
