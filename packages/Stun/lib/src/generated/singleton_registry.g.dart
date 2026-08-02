// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:singleton_manager/singleton_manager.dart'; // GENERATED CODE - DO NOT MODIFY BY HAND

import '../implementations/dual/dual_stun_handler.dart'; // GENERATED CODE - DO NOT MODIFY BY HAND

// The generator only imports each class's own file, not the interface it
// implements — add the interface import by hand until that's fixed upstream.
import '../interfaces/dual/i_dual_stun_handler.dart';

/// Connects every `@dependencyInjectable` class discovered under the scanned
/// input directory to `RegistryManager.instance`, using each generated
/// `dependencyInjectionFactory()` as the connected factory.
/// Each call is independent — registering under a different [key] never
/// overwrites a previous call, so multiple singleton graphs can be set up
/// side by side by calling this with different keys.
///
/// Every method below is a regular, overridable instance method — mix
/// [MainInjectionStunMixin] into your own class (or override on [MainInjectionStun])
/// to hook into `beforeRegisterAllSingletonsStun` / `afterRegisterAllSingletonsStun`, or replace
/// `registerAllSingletonsStun` entirely.
mixin MainInjectionStunMixin { // GENERATED CODE - DO NOT MODIFY BY HAND
  /// Called by [registerAllSingletonsStun] right before it connects anything.
  /// Override to customize. // GENERATED CODE - DO NOT MODIFY BY HAND
  void beforeRegisterAllSingletonsStun({String key = 'default'}) {} // GENERATED CODE - DO NOT MODIFY BY HAND

  /// Connects every discovered singleton under [key]. // GENERATED CODE - DO NOT MODIFY BY HAND
  void registerAllSingletonsStun({String key = 'default'}) { // GENERATED CODE - DO NOT MODIFY BY HAND
    beforeRegisterAllSingletonsStun(key: key); // GENERATED CODE - DO NOT MODIFY BY HAND
    RegistryManager.instance // GENERATED CODE - DO NOT MODIFY BY HAND
      ..connectInstance<IDualStunHandler, DualStunHandler>(() => DualStunHandler.dependencyInjectionFactory(key: key), key: key); // GENERATED CODE - DO NOT MODIFY BY HAND
    afterRegisterAllSingletonsStun(key: key); // GENERATED CODE - DO NOT MODIFY BY HAND
  } // GENERATED CODE - DO NOT MODIFY BY HAND

  /// Called by [registerAllSingletonsStun] right after it finishes connecting
  /// everything. Override to customize. // GENERATED CODE - DO NOT MODIFY BY HAND
  void afterRegisterAllSingletonsStun({String key = 'default'}) {} // GENERATED CODE - DO NOT MODIFY BY HAND
} // GENERATED CODE - DO NOT MODIFY BY HAND

/// Ready-to-use [MainInjectionStunMixin] host — instantiate this directly, or
/// extend it (or mix [MainInjectionStunMixin] into your own class) to override
/// the before/register/after hooks. // GENERATED CODE - DO NOT MODIFY BY HAND
class MainInjectionStun with MainInjectionStunMixin { // GENERATED CODE - DO NOT MODIFY BY HAND
  const MainInjectionStun(); // GENERATED CODE - DO NOT MODIFY BY HAND
} // GENERATED CODE - DO NOT MODIFY BY HAND
