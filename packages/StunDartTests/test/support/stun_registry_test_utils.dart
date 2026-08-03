import 'package:stun/src/factories/dual_stun_registry_wiring.dart';

const injector = DualStunInjector();

String uniqueKey(String label) => '$label-${DateTime.now().microsecondsSinceEpoch}';

/// Generates a fresh unique key and runs [DualStunInjector.registerAllSingletonsStunAsync]
/// for that key, which wires real ipv4/ipv6 `RawDatagramSocket`s via
/// [connectDualStunHandlerSockets] before connecting singletons.
///
/// Use this instead of calling `registerAllSingletonsStun` directly whenever
/// a test resolves `IStunHandler`/`IStunHandlerMigratable`/`IDualStunHandler`/
/// `IDualStunHandlerMigratable` — those all depend on a `RawDatagramSocket`,
/// which is never auto-registered since it isn't `@dependencyInjectable`.
Future<String> registerStunSingletons(String label) async {
  final key = uniqueKey(label);
  await injector.registerAllSingletonsStunAsync(key: key);
  return key;
}
