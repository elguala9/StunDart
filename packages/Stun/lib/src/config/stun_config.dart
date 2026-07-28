import 'dart:io';

import 'package:config_manager/config_manager.dart';

/// The `config_manager` sector owned by this package.
const String stunConfigSector = 'stun';

/// Built-in STUN defaults.
///
/// This map is the single source of both the default values and the
/// configuration keys: it is loaded into the [stunConfigSector] sector by
/// [initStunConfig], and any key missing from a user-supplied configuration
/// falls back to the value declared here.
const Map<String, dynamic> defaultStunConfig = {
  'server': {'address': 'stun.l.google.com', 'port': 19302, 'localPort': 49152},
  'ipVersion': 'IPv4',
  'timeoutSeconds': 5,
  'nat': {
    'primaryServer': 'stun.l.google.com',
    'primaryPort': 19302,
    'secondaryServer': 'stun1.l.google.com',
    'secondaryPort': 19302,
    'timeoutSeconds': 5,
  },
};

/// Loads [defaultStunConfig] into the [stunConfigSector] sector, with
/// [overrides] merged on top (deep merge, so partial sub-maps are allowed).
///
/// Call once at startup to change the package-wide defaults:
///
/// ```dart
/// initStunConfig({
///   'server': {'address': 'stun.cloudflare.com', 'port': 3478},
///   'timeoutSeconds': 3,
/// });
/// ```
///
/// Calling it is optional: the defaults are seeded lazily on first read.
void initStunConfig([Map<String, dynamic>? overrides]) {
  ConfigManagerSingleton().loadFromMap(
    _merge(defaultStunConfig, overrides),
    sector: stunConfigSector,
  );
}

/// Deep-merges [overrides] onto [base], returning a new mutable map.
///
/// Useful to combine two configurations before handing the result to
/// [initStunConfig], which only takes a single map.
Map<String, dynamic> mergeStunConfig(
  Map<String, dynamic> base, [
  Map<String, dynamic>? overrides,
]) => _merge(base, overrides);

/// Seeds the defaults unless the [stunConfigSector] sector is already loaded.
void ensureStunConfig() {
  if (ConfigManagerSingleton().config(sector: stunConfigSector) == null) {
    initStunConfig();
  }
}

/// Reads a configured value by dot-notation [key], falling back to the
/// corresponding entry of [defaultStunConfig].
///
/// Prefer the typed getters of [StunConfigExtension]; this is the escape
/// hatch for static contexts, which cannot mix the extension in.
dynamic stunConfigValue(String key) {
  ensureStunConfig();
  return ConfigManagerSingleton().get(key, sector: stunConfigSector) ??
      _lookup(defaultStunConfig, key);
}

/// Configuration access for the STUN components.
///
/// Mixed into every class that needs a default value, on top of
/// [ConfigExtension]: it pins the sector to [stunConfigSector], seeds the
/// built-in defaults on first read and exposes the values already coerced to
/// their Dart types.
///
/// ```dart
/// class Foo with ConfigExtension, StunConfigExtension {
///   Foo({String? address}) {
///     _address = address ?? defaultStunAddress;
///   }
/// }
/// ```
mixin StunConfigExtension on ConfigExtension {
  String _sector = stunConfigSector;

  /// Pinned to [stunConfigSector]; still settable for tests or for hosts that
  /// keep several STUN configurations side by side.
  @override
  String get configSector => _sector;

  @override
  set configSector(String value) => _sector = value;

  /// Default STUN server hostname.
  String get defaultStunAddress => _string('server.address');

  /// Default STUN server port.
  int get defaultStunPort => _int('server.port');

  /// Default local port used when binding a socket.
  int get defaultLocalPort => _int('server.localPort');

  /// Default IP family used when a handler does not specify one.
  InternetAddressType get defaultIpVersion => _ipVersion('ipVersion');

  /// Default per-request timeout.
  Duration get defaultTimeout => _duration('timeoutSeconds');

  /// Default primary server for the NAT detector.
  String get defaultNatPrimaryServer => _string('nat.primaryServer');

  /// Default primary port for the NAT detector.
  int get defaultNatPrimaryPort => _int('nat.primaryPort');

  /// Default per-test timeout for the NAT detector.
  Duration get defaultNatTimeout => _duration('nat.timeoutSeconds');

  /// Configured value for [key], or its [defaultStunConfig] entry when the
  /// loaded configuration does not define it.
  dynamic configValue(String key) {
    ensureStunConfig();
    return get(key) ?? _lookup(defaultStunConfig, key);
  }

  String _string(String key) => _asString(configValue(key), key);

  int _int(String key) => _asInt(configValue(key), key);

  Duration _duration(String key) => _asDuration(configValue(key), key);

  InternetAddressType _ipVersion(String key) =>
      _asIpVersion(configValue(key), key);
}

String _asString(dynamic value, String key) {
  if (value is String && value.isNotEmpty) return value;
  return _lookup(defaultStunConfig, key) as String;
}

int _asInt(dynamic value, String key) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  final parsed = value is String ? int.tryParse(value) : null;
  return parsed ?? _lookup(defaultStunConfig, key) as int;
}

Duration _asDuration(dynamic value, String key) {
  final seconds = value is num
      ? value
      : num.tryParse('$value') ?? _lookup(defaultStunConfig, key) as num;
  return Duration(
    microseconds: (seconds * Duration.microsecondsPerSecond).round(),
  );
}

InternetAddressType _asIpVersion(dynamic value, String key) {
  return switch ('$value'.toLowerCase()) {
    'ipv4' || 'v4' || '4' => InternetAddressType.IPv4,
    'ipv6' || 'v6' || '6' => InternetAddressType.IPv6,
    'any' => InternetAddressType.any,
    _ => _asIpVersion(_lookup(defaultStunConfig, key), 'ipVersion'),
  };
}

/// Walks [map] following the dot-notation [key].
dynamic _lookup(Map<String, dynamic> map, String key) {
  dynamic current = map;
  for (final part in key.split('.')) {
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
