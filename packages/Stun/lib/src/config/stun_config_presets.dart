/// Named STUN configurations: the ones shipped with the package, and the ones
/// registered by the application using it.
///
/// Nothing here is applied automatically — the package keeps using
/// `defaultStunConfig` until a configuration is selected:
///
/// ```dart
/// initStunConfig(chinaStunConfig);   // by value
/// useStunConfig('china');            // by name
/// ```
///
/// An application can put its own configuration next to the built-in ones and
/// then choose either at runtime, from a single string:
///
/// ```dart
/// registerStunConfig('acme', {
///   'server': {'address': 'stun.acme.internal', 'port': 3478},
/// });
///
/// useStunConfig(Platform.environment['STUN_PRESET'] ?? 'acme');
/// ```
///
/// They are ordinary partial maps, so they also compose with ad-hoc
/// overrides:
///
/// ```dart
/// useStunConfig('china', overrides: {'timeoutSeconds': 12});
/// initStunConfig({...chinaStunConfig, 'timeoutSeconds': 12});
/// ```
///
/// Every built-in preset pairs its NAT-detector primary and secondary servers
/// across two independent operators: RFC 5780 Test 3 needs the secondary to
/// resolve to a different IP than the primary, otherwise symmetric-NAT
/// detection cannot tell the two apart.
///
/// Each built-in preset nests its fields under [stunConfigKey], so the whole
/// constant can be spread straight into a larger JSON document alongside
/// other domains' config without key collisions, and handed to
/// [initStunConfig] as-is.
library;

import 'dart:collection';

import 'stun_config.dart';

/// STUN servers operated inside mainland China.
///
/// The built-in defaults point at `stun.l.google.com`, which is unreachable
/// behind the Great Firewall — every request just times out. This preset
/// swaps in two servers hosted in mainland China, on different networks so
/// they also satisfy the RFC 5780 Test 3 requirement:
///
/// - primary `stun.miwifi.com:3478` — Xiaomi, Beijing (111.206.174.3)
/// - secondary `stun.chat.bilibili.com:3478` — Bilibili on Baidu Cloud,
///   Beijing (180.76.162.88)
///
/// Both answered a binding request in ~250 ms when this preset was written.
/// Other mainland servers that also responded, should you need to swap one
/// out: `stun.douyucdn.cn:18000` and `stun.hitv.com:3478`. `stun.qq.com`
/// resolves but does not answer, so it is deliberately not used here.
///
/// The timeout is raised to 8 seconds to leave headroom on Chinese mobile
/// networks, where these hosts are much slower than the sub-second replies
/// measured from a wired European connection.
const Map<String, dynamic> chinaStunConfig = {
  stunConfigKey: {
    'server': {'address': 'stun.miwifi.com', 'port': 3478},
    'timeoutSeconds': 8.0,
    'nat': {
      'primaryServer': 'stun.miwifi.com',
      'primaryPort': 3478,
      'secondaryServer': 'stun.chat.bilibili.com',
      'secondaryPort': 3478,
      'timeoutSeconds': 8.0,
    },
  },
};

/// Cloudflare's public STUN server, with Google as the NAT-detector secondary.
///
/// Useful where Google is reachable but you would rather not depend on it for
/// the main request path.
const Map<String, dynamic> cloudflareStunConfig = {
  stunConfigKey: {
    'server': {'address': 'stun.cloudflare.com', 'port': 3478},
    'nat': {
      'primaryServer': 'stun.cloudflare.com',
      'primaryPort': 3478,
      'secondaryServer': 'stun.l.google.com',
      'secondaryPort': 19302,
    },
  },
};

/// European community-run STUN servers: Nextcloud as primary (on port 443,
/// which also survives firewalls that only allow HTTPS ports) and sipgate as
/// secondary.
const Map<String, dynamic> europeStunConfig = {
  stunConfigKey: {
    'server': {'address': 'stun.nextcloud.com', 'port': 443},
    'nat': {
      'primaryServer': 'stun.nextcloud.com',
      'primaryPort': 443,
      'secondaryServer': 'stun.sipgate.net',
      'secondaryPort': 3478,
    },
  },
};

/// The presets shipped with the package, keyed by name.
const Map<String, Map<String, dynamic>> builtInStunConfigPresets = {
  'china': chinaStunConfig,
  'cloudflare': cloudflareStunConfig,
  'europe': europeStunConfig,
};

final Map<String, Map<String, dynamic>> _presets = {
  ...builtInStunConfigPresets,
};

/// Every named configuration currently available: the built-in presets plus
/// whatever has been added with [registerStunConfig].
///
/// Read-only — go through [registerStunConfig] to add an entry.
Map<String, Map<String, dynamic>> get stunConfigPresets =>
    UnmodifiableMapView(_presets);

/// The names of the available configurations, e.g. to show them in a `--help`
/// or to validate user input before calling [useStunConfig].
Iterable<String> get stunConfigNames => _presets.keys;

/// Adds a configuration under [name], so that it can then be selected by
/// string exactly like a built-in preset.
///
/// This is how an application defines its own STUN setup once and picks it
/// later from an environment variable, a CLI flag or its own config file:
///
/// ```dart
/// registerStunConfig('acme', {
///   'server': {'address': 'stun.acme.internal', 'port': 3478},
///   'timeoutSeconds': 2,
/// });
///
/// useStunConfig(Platform.environment['STUN_PRESET'] ?? 'acme');
/// ```
///
/// Registering does not apply anything: nothing changes until the name is
/// passed to [useStunConfig]. Reusing an existing [name] replaces that entry,
/// which also lets an application re-tune a built-in preset under its own
/// name.
void registerStunConfig(String name, Map<String, dynamic> config) {
  if (name.isEmpty) {
    throw ArgumentError.value(name, 'name', 'must not be empty');
  }
  _presets[name] = config;
}

/// Removes a configuration previously added with [registerStunConfig].
///
/// Returns the removed configuration, or `null` when [name] was not
/// registered. Built-in presets can be removed too; [resetStunConfigPresets]
/// brings them back.
Map<String, dynamic>? unregisterStunConfig(String name) =>
    _presets.remove(name);

/// Drops every custom registration, restoring [builtInStunConfigPresets].
///
/// Does not touch the active configuration — call [initStunConfig] for that.
void resetStunConfigPresets() {
  _presets
    ..clear()
    ..addAll(builtInStunConfigPresets);
}

/// The configuration registered under [name], or `null` when there is none.
///
/// Use it for the tolerant path, where an unknown name should fall back to
/// the built-in defaults rather than fail:
///
/// ```dart
/// initStunConfig(stunConfigNamed(Platform.environment['STUN_PRESET']));
/// ```
Map<String, dynamic>? stunConfigNamed(String? name) =>
    name == null ? null : _presets[name];

/// Applies the configuration registered under [name], with [overrides] merged
/// on top of it.
///
/// The strict counterpart of [stunConfigNamed]: an unknown [name] throws an
/// [ArgumentError] listing what is available, so a typo in a deployment
/// variable fails loudly at startup instead of silently falling back to
/// servers that may be unreachable from where the app runs.
void useStunConfig(String name, {Map<String, dynamic>? overrides}) {
  final preset = _presets[name];
  if (preset == null) {
    throw ArgumentError.value(
      name,
      'name',
      'unknown STUN configuration; available: ${stunConfigNames.join(', ')}',
    );
  }
  initStunConfig(mergeStunConfig(unwrapStunConfig(preset)!, overrides));
}
