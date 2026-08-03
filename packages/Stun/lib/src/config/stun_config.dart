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
  _access.loadFromMap(_merge(defaultStunConfig, unwrapStunConfig(overrides)));
}

/// The STUN section of [map]: `map[stunConfigKey]` when present, or [map]
/// itself otherwise.
Map<String, dynamic>? unwrapStunConfig(Map<String, dynamic>? map) =>
    (map?[stunConfigKey] as Map<String, dynamic>?) ?? map;

/// Deep-merges [overrides] onto [base], returning a new mutable map.
Map<String, dynamic> mergeStunConfig(
  Map<String, dynamic> base, [
  Map<String, dynamic>? overrides,
]) => _merge(base, overrides);

/// Seeds [defaultStunConfig] into [stunConfigSector], but only if it isn't
/// already loaded.
void ensureStunConfig() {
  _access.loadFromMap(defaultStunConfig, force: false);
}

/// Reads a configured value by dot-notation [key] (e.g. `'server.address'`).
///
/// Escape hatch for static contexts that cannot mix in [StunConfigExtension];
/// prefer its typed getters on an instance.
dynamic stunConfigValue(String key) => _access.configValue(key);

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

  String get defaultStunAddress => _get<String>(const ['server', 'address']);

  int get defaultStunPort => _get<int>(const ['server', 'port']);

  int get defaultLocalPort => _get<int>(const ['server', 'localPort']);

  InternetAddressType get defaultIpVersion =>
      switch (_get<String>(const ['ipVersion'])) {
        'IPv6' => InternetAddressType.IPv6,
        'any' => InternetAddressType.any,
        _ => InternetAddressType.IPv4,
      };

  Duration get defaultTimeout => _durationOf(const ['timeoutSeconds']);

  String get defaultNatPrimaryServer =>
      _get<String>(const ['nat', 'primaryServer']);

  int get defaultNatPrimaryPort => _get<int>(const ['nat', 'primaryPort']);

  Duration get defaultNatTimeout =>
      _durationOf(const ['nat', 'timeoutSeconds']);

  /// Configured value for dot-notation [key].
  dynamic configValue(String key) => _get<dynamic>(key.split('.'));

  /// Reads [path], falling back to its [defaultStunConfig] entry when the
  /// loaded configuration doesn't define it (e.g. a partial config loaded
  /// directly via [ConfigExtension.loadFromString]/[loadFromMap]).
  T _get<T>(List<String> path) {
    ensureStunConfig();
    return containsKeys([path])
        ? get<T>(path)
        : _lookup(defaultStunConfig, path) as T;
  }

  Duration _durationOf(List<String> path) => Duration(
    microseconds: (_get<num>(path) * Duration.microsecondsPerSecond).round(),
  );
}

/// Walks [map] following [path].
dynamic _lookup(Map<String, dynamic> map, List<String> path) {
  dynamic current = map;
  for (final part in path) {
    if (current is! Map<String, dynamic>) return null;
    current = current[part];
  }
  return current;
}

/// Deep-merges [overrides] onto a mutable copy of [base].
///
/// The copy matters: the stored map is mutated in place by
/// `ConfigManagerSingleton.set`, and [defaultStunConfig] is `const`.
Map<String, dynamic> _merge(
  Map<String, dynamic> base,
  Map<String, dynamic>? overrides,
) {
  final merged = <String, dynamic>{};
  for (final entry in base.entries) {
    final value = entry.value;
    merged[entry.key] = value is Map<String, dynamic>
        ? _merge(value, null)
        : value;
  }
  if (overrides == null) return merged;

  for (final entry in overrides.entries) {
    final existing = merged[entry.key];
    final value = entry.value;
    merged[entry.key] =
        existing is Map<String, dynamic> && value is Map<String, dynamic>
        ? _merge(existing, value)
        : value;
  }
  return merged;
}
