import 'dart:io';

import 'package:config_manager/config_manager.dart';

/// The `config_manager` sector owned by this package.
const String stunConfigSector = 'stun';

/// Key a larger JSON document can nest the STUN section under, so a whole
/// multi-domain config blob can be handed to [initStunConfig] as-is instead
/// of extracting the STUN part first.
const String stunConfigKey = 'stunConfig';

/// Built-in STUN defaults, also used as the fallback for missing keys and as
/// the source of valid configuration keys.
const Map<String, dynamic> defaultStunConfig = {
  'server': {'address': 'stun.l.google.com', 'port': 19302, 'localPort': 49152},
  'ipVersion': 'IPv6',
  'timeoutSeconds': 5.0,
  'nat': {
    'primaryServer': 'stun.l.google.com',
    'primaryPort': 19302,
    'secondaryServer': 'stun1.l.google.com',
    'secondaryPort': 19302,
    'timeoutSeconds': 5.0,
  },
};

/// Loads [defaultStunConfig] into [stunConfigSector], with [overrides]
/// deep-merged on top. [overrides] can be the STUN fields directly, or a
/// bigger document nesting them under [stunConfigKey] — only that section is
/// used, so foreign JSON can be merged in and handed over as-is. Always
/// replaces whatever was loaded before; use [ensureStunConfig] to seed the
/// sector only if it's still empty.
void initStunConfig([Map<String, dynamic>? overrides]) {
  _access.loadFromMap(
    deepMergeMaps(defaultStunConfig, unwrapStunConfig(overrides)),
  );
}

/// The STUN section of [map]: `map[stunConfigKey]` when present, or [map]
/// itself otherwise.
Map<String, dynamic>? unwrapStunConfig(Map<String, dynamic>? map) =>
    (map?[stunConfigKey] as Map<String, dynamic>?) ?? map;

/// Deep-merges [overrides] onto [base], returning a new mutable map.
Map<String, dynamic> mergeStunConfig(
  Map<String, dynamic> base, [
  Map<String, dynamic>? overrides,
]) => deepMergeMaps(base, overrides);

/// Seeds [defaultStunConfig] into [stunConfigSector], but only if it isn't
/// already loaded.
void ensureStunConfig() {
  _access.loadFromMap(defaultStunConfig, force: false);
}

/// Reads a configured value at [path] (e.g. `['server', 'address']`).
///
/// Escape hatch for static contexts that cannot mix in [StunConfigExtension];
/// prefer its typed getters on an instance.
dynamic stunConfigValue(List<String> path) => _access.configValue(path);

/// [StunConfigExtension.defaultIpVersion] for static contexts, e.g. picking a
/// socket family before any handler instance exists to bind it to.
InternetAddressType defaultStunIpVersion() => _access.defaultIpVersion;

/// Backs the static-context helpers above with a real [ConfigExtension]
/// instance, instead of talking to [ConfigManagerSingleton] directly.
final _access = _StunConfigAccess();

class _StunConfigAccess with ConfigExtension, StunConfigExtension {}

/// Configuration access for the STUN components: pins the sector to
/// [stunConfigSector] and exposes the defaults already coerced to their Dart
/// types. Mix in on top of [ConfigExtension].
mixin StunConfigExtension on ConfigExtension {
  String _sector = stunConfigSector;

  @override
  String get configSector => _sector;

  @override
  set configSector(String value) => _sector = value;

  String get defaultStunAddress =>
      getOrDefault(const ['server', 'address'], defaultStunConfig);

  int get defaultStunPort =>
      getOrDefault(const ['server', 'port'], defaultStunConfig);

  int get defaultLocalPort =>
      getOrDefault(const ['server', 'localPort'], defaultStunConfig);

  InternetAddressType get defaultIpVersion =>
      switch (getOrDefault<String>(const ['ipVersion'], defaultStunConfig)) {
        'IPv6' => InternetAddressType.IPv6,
        'any' => InternetAddressType.any,
        _ => InternetAddressType.IPv4,
      };

  Duration get defaultTimeout =>
      getDurationSeconds(const ['timeoutSeconds'], defaultStunConfig);

  String get defaultNatPrimaryServer =>
      getOrDefault(const ['nat', 'primaryServer'], defaultStunConfig);

  int get defaultNatPrimaryPort =>
      getOrDefault(const ['nat', 'primaryPort'], defaultStunConfig);

  Duration get defaultNatTimeout =>
      getDurationSeconds(const ['nat', 'timeoutSeconds'], defaultStunConfig);

  /// Configured value at [path], falling back to its [defaultStunConfig]
  /// entry when the loaded configuration doesn't define it; see
  /// [ConfigExtension.getOrDefault].
  dynamic configValue(List<String> path) =>
      getOrDefault<dynamic>(path, defaultStunConfig);
}
