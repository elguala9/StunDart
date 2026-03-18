import 'package:singleton_manager/singleton_manager.dart';

import '../implementations/handlers/dual_stun_handler.dart';
import '../implementations/singleton/stun_handler_singleton.dart';
import '../interfaces/i_dual_stun_handler.dart';
import '../interfaces/i_stun_handler_singleton.dart';

/// Initializes all STUN components and registers them in the DI container.
///
/// Creates an IPv4 handler (always) and an IPv6 handler (if the system
/// supports it), wires them into a [DualStunHandler] and the
/// [StunHandlerSingleton], then registers both instances via
/// [SingletonDIAccess] so they can be retrieved with
/// `SingletonDIAccess.get<IDualStunHandler>()` and
/// `SingletonDIAccess.get<IStunHandlerSingleton>()`.
Future<void> initialPointStun({
  String? address,
  int? port,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final singleton = StunHandlerSingleton.instance;
  await singleton.initialize(address: address, port: port, timeout: timeout);

  SingletonDIAccess.addInstanceAs<IDualStunHandler, DualStunHandler>(
    singleton.dualHandler,
  );
  SingletonDIAccess.addInstanceAs<IStunHandlerSingleton, StunHandlerSingleton>(
    singleton,
  );
}
