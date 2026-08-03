import 'package:stun/main_injection.dart';
import 'package:stun/src/factories/dual_stun_registry_wiring.dart';

const injector = MainInjectionStun();

String uniqueKey(String label) => '$label-${DateTime.now().microsecondsSinceEpoch}';

/// Generates a fresh unique key, wires real ipv4/ipv6 `StunHandlerInput`
/// sockets under it via [connectDualStunHandlerSockets], then runs
/// [MainInjectionStunMixin.registerAllSingletonsStun] for that same key.
///
/// Use this instead of calling `registerAllSingletonsStun` directly whenever
/// a test resolves `IStunHandler`/`IStunHandlerMigratable`/`IDualStunHandler`/
/// `IDualStunHandlerMigratable` — those all depend on `StunHandlerInput`,
/// which is never auto-registered since it isn't `@dependencyInjectable`.
Future<String> registerStunSingletons(String label) async {
  final key = uniqueKey(label);
  await connectDualStunHandlerSockets(key: key);
  injector.registerAllSingletonsStun(key: key);
  return key;
}
