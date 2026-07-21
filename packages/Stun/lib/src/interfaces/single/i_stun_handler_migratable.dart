import 'package:stun/stun.dart';

/// Interface for STUN handler
abstract class IStunHandlerMigratable implements IStunHandler {
  void migrateTo(IStunHandler stunHandler);
}
