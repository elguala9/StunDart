import 'package:singleton_manager/singleton_manager.dart';
import 'package:stun/stun.dart';
import 'package:test/test.dart';

import 'support/stun_registry_test_utils.dart';

void main() {
  test(
    'connectDualStunHandlerSockets makes DualStunHandler resolve both handlers',
    () async {
      final key = await registerStunSingletons('wired');

      final dual = RegistryManager.instance.getInstance<IDualStunHandler>(
        key: key,
      );

      expect(dual.ipv4Handler, isNotNull);
      expect(dual.ipv6Handler, isNotNull);
      expect(
        dual.ipv4Handler!.getIpVersion().toString(),
        contains('IPv4'),
      );
      expect(
        dual.ipv6Handler!.getIpVersion().toString(),
        contains('IPv6'),
      );

      dual.close();
    },
  );

  test(
    'connectDualStunHandlerSockets makes DualStunHandlerMigratable resolve both handlers',
    () async {
      final key = await registerStunSingletons('wired-migratable');

      final dual = RegistryManager.instance
          .getInstance<IDualStunHandlerMigratable>(key: key);

      expect(dual.ipv4Handler, isNotNull);
      expect(dual.ipv6Handler, isNotNull);

      dual.close();
    },
  );
}
