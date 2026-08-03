import 'dart:io';

import 'package:config_manager/config_manager.dart';
import 'package:stun/stun.dart';
import 'package:test/test.dart';

/// Minimal consumer used to exercise [StunConfigExtension] in isolation.
class _ConfigProbe with ConfigExtension, StunConfigExtension {}

void main() {
  // Restore the built-in defaults between tests.
  tearDown(initStunConfig);

  group('StunConfigExtension', () {
    test('falls back to the built-in defaults when nothing is loaded', () {
      ConfigManagerSingleton().clear(sector: stunConfigSector);
      final probe = _ConfigProbe();

      expect(probe.configSector, stunConfigSector);
      expect(probe.defaultStunAddress, 'stun.l.google.com');
      expect(probe.defaultStunPort, 19302);
      expect(probe.defaultLocalPort, 49152);
      expect(probe.defaultIpVersion, InternetAddressType.IPv4);
      expect(probe.defaultTimeout, const Duration(seconds: 5));
      expect(probe.defaultNatPrimaryServer, 'stun.l.google.com');
      expect(probe.defaultNatPrimaryPort, 19302);
      expect(probe.defaultNatTimeout, const Duration(seconds: 5));
    });

    test('initStunConfig() deep-merges the overrides onto the defaults', () {
      initStunConfig({
        'server': {'address': 'stun.example.org'},
        'timeoutSeconds': 2.5,
      });

      final probe = _ConfigProbe();

      expect(probe.defaultStunAddress, 'stun.example.org');
      expect(probe.defaultTimeout, const Duration(milliseconds: 2500));
      // Untouched keys of the overridden sub-map survive the merge.
      expect(probe.defaultStunPort, 19302);
      expect(probe.defaultNatPrimaryServer, 'stun.l.google.com');
    });

    test('initStunConfig() does not mutate the const defaults', () {
      initStunConfig({
        'server': {'address': 'stun.example.org'},
      });
      _ConfigProbe().set('server.port', 1);

      expect(
        (defaultStunConfig['server'] as Map)['address'],
        'stun.l.google.com',
      );
      expect((defaultStunConfig['server'] as Map)['port'], 19302);
    });

    test('reads the ipVersion and Duration coercions from JSON', () {
      ConfigManagerSingleton().loadFromString('''
      {
        "server": { "address": "stun.json.test", "port": 1234 },
        "ipVersion": "IPv6",
        "timeoutSeconds": 1.5
      }
      ''', sector: stunConfigSector);

      final probe = _ConfigProbe();

      expect(probe.defaultStunAddress, 'stun.json.test');
      expect(probe.defaultStunPort, 1234);
      expect(probe.defaultIpVersion, InternetAddressType.IPv6);
      expect(probe.defaultTimeout, const Duration(milliseconds: 1500));
      // Keys absent from the JSON still resolve to the built-in defaults.
      expect(probe.defaultNatPrimaryServer, 'stun.l.google.com');
      expect(probe.defaultNatTimeout, const Duration(seconds: 5));
    });

    test('stunConfigValue() reads by dot notation from static contexts', () {
      initStunConfig({
        'nat': {'secondaryServer': 'nat2.example.org'},
      });

      expect(stunConfigValue('nat.secondaryServer'), 'nat2.example.org');
      expect(stunConfigValue('nat.secondaryPort'), 19302);
      expect(stunConfigValue('nope.missing'), isNull);
    });
  });

  group('named configurations', () {
    tearDown(resetStunConfigPresets);

    test('a package user can register and select their own', () {
      registerStunConfig('acme', {
        'server': {'address': 'stun.acme.internal', 'port': 3478},
        'timeoutSeconds': 2,
      });

      expect(stunConfigNames, contains('acme'));
      // Registering alone changes nothing.
      expect(_ConfigProbe().defaultStunAddress, 'stun.l.google.com');

      useStunConfig('acme');

      final probe = _ConfigProbe();
      expect(probe.defaultStunAddress, 'stun.acme.internal');
      expect(probe.defaultStunPort, 3478);
      expect(probe.defaultTimeout, const Duration(seconds: 2));
      // Keys the custom configuration omits still come from the defaults.
      expect(probe.defaultNatPrimaryServer, 'stun.l.google.com');
    });

    test('built-in presets are selectable by name too', () {
      useStunConfig('china');

      expect(_ConfigProbe().defaultStunAddress, 'stun.miwifi.com');
    });

    test('overrides are merged on top of the selected configuration', () {
      useStunConfig('china', overrides: {'timeoutSeconds': 12});

      final probe = _ConfigProbe();
      expect(probe.defaultStunAddress, 'stun.miwifi.com');
      expect(probe.defaultTimeout, const Duration(seconds: 12));
    });

    test('an unknown name fails loudly, listing the available ones', () {
      expect(
        () => useStunConfig('chnia'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => '${e.message}',
            'message',
            allOf(contains('china'), contains('cloudflare')),
          ),
        ),
      );
    });

    test('stunConfigNamed() is the tolerant lookup for env-driven setups', () {
      registerStunConfig('acme', {
        'server': {'address': 'stun.acme.internal'},
      });

      expect(stunConfigNamed('acme'), isNotNull);
      expect(stunConfigNamed('nope'), isNull);
      expect(stunConfigNamed(null), isNull);

      // An unset variable falls back to the built-in defaults.
      initStunConfig(stunConfigNamed(null));
      expect(_ConfigProbe().defaultStunAddress, 'stun.l.google.com');
    });

    test('registrations can be replaced and removed', () {
      registerStunConfig('acme', {
        'server': {'address': 'stun.acme.internal'},
      });
      registerStunConfig('acme', {
        'server': {'address': 'stun.acme2.internal'},
      });
      useStunConfig('acme');
      expect(_ConfigProbe().defaultStunAddress, 'stun.acme2.internal');

      expect(unregisterStunConfig('acme'), isNotNull);
      expect(unregisterStunConfig('acme'), isNull);
      expect(stunConfigNames, isNot(contains('acme')));
    });

    test('resetStunConfigPresets() restores the built-in set', () {
      registerStunConfig('acme', const {});
      unregisterStunConfig('china');

      resetStunConfigPresets();

      expect(stunConfigNames, isNot(contains('acme')));
      expect(stunConfigNames, containsAll(builtInStunConfigPresets.keys));
    });

    test('the exposed preset map cannot be mutated directly', () {
      expect(
        () => stunConfigPresets['acme'] = const {},
        throwsUnsupportedError,
      );
    });
  });

  group('presets', () {
    test('none of them is applied unless requested', () {
      ConfigManagerSingleton().clear(sector: stunConfigSector);

      expect(_ConfigProbe().defaultStunAddress, 'stun.l.google.com');
    });

    test('chinaStunConfig avoids the servers blocked by the GFW', () {
      initStunConfig(chinaStunConfig);
      final probe = _ConfigProbe();

      for (final host in [
        probe.defaultStunAddress,
        probe.defaultNatPrimaryServer,
        '${stunConfigValue('nat.secondaryServer')}',
      ]) {
        expect(
          host,
          isNot(contains('google')),
          reason: 'Google STUN is unreachable from mainland China',
        );
      }
      expect(probe.defaultTimeout, const Duration(seconds: 8));
    });

    test('every preset merges cleanly onto the defaults', () {
      for (final entry in stunConfigPresets.entries) {
        initStunConfig(entry.value);
        final probe = _ConfigProbe();

        expect(probe.defaultStunAddress, isNotEmpty, reason: entry.key);
        expect(probe.defaultStunPort, inInclusiveRange(1, 65535));
        expect(probe.defaultNatPrimaryPort, inInclusiveRange(1, 65535));
        // Keys no preset overrides still come from the defaults.
        expect(probe.defaultLocalPort, 49152, reason: entry.key);
        expect(probe.defaultIpVersion, InternetAddressType.IPv4);
      }
    });

    test('each preset uses two distinct NAT-detection servers', () {
      for (final entry in stunConfigPresets.entries) {
        initStunConfig(entry.value);

        expect(
          stunConfigValue('nat.secondaryServer'),
          isNot(_ConfigProbe().defaultNatPrimaryServer),
          reason: 'RFC 5780 Test 3 needs a different IP (${entry.key})',
        );
      }
    });
  });

  group('defaults wiring', () {
    test('StunHandlerProfile picks up the configured defaults', () {
      initStunConfig({
        'server': {'address': 'stun.profile.test', 'port': 4321},
        'ipVersion': 'IPv6',
        'timeoutSeconds': 9,
      });

      final profile = StunHandlerProfile();

      expect(profile.stunAddress, 'stun.profile.test');
      expect(profile.stunPort, 4321);
      expect(profile.ipVersion, InternetAddressType.IPv6);
      expect(profile.timeout, const Duration(seconds: 9));
    });

    test('explicit arguments still win over the configured defaults', () {
      initStunConfig({
        'server': {'address': 'stun.profile.test', 'port': 4321},
      });

      final profile = StunHandlerProfile(
        stunAddress: 'stun.explicit.test',
        stunPort: 1111,
      );

      expect(profile.stunAddress, 'stun.explicit.test');
      expect(profile.stunPort, 1111);
    });

    test('StunHandler binds the configured IP family by default', () async {
      initStunConfig({'ipVersion': 'IPv6'});

      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv6, 0);
      final handler = StunHandler(socket);

      expect(handler.getIpVersion(), InternetAddressType.IPv6);
    });

    test('NATDetector.withDefaults() uses the configured servers', () async {
      initStunConfig({
        'nat': {
          'primaryServer': 'nat1.example.org',
          'secondaryServer': 'nat2.example.org',
          'timeoutSeconds': 7,
        },
      });

      final detector = await NATDetector.withDefaults();
      addTearDown(detector.socket.close);

      expect(detector.primaryServer, 'nat1.example.org');
      expect(detector.primaryPort, 19302);
      expect(detector.secondaryServer, 'nat2.example.org');
      expect(detector.secondaryPort, 19302);
      expect(detector.timeout, const Duration(seconds: 7));
    });
  });
}
