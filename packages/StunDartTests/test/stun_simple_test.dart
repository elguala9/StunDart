import 'dart:io';
import 'package:test/test.dart';
import 'package:stun/stun.dart';
import 'test_constants.dart';

void main() {
  test('Simple STUN request', () async {
    print('Creating socket...');
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    print('Socket created on port: ${socket.port}');
    print('Socket address: ${socket.address}');

    final input = (
      address: StunServers.googleStun,
      port: StunServers.defaultPort,
      socket: socket,
    );

    print('Creating STUN handler...');
    final handler = StunHandler(input);

    try {
      print('Performing STUN request...');
      final response = await handler.performStunRequest();

      print('Success!');
print('Public IP: ${response.publicIp(InternetAddressType.IPv4)}');
      print('Public Port: ${response.publicPort(InternetAddressType.IPv4)}');
      // Test assertions
      expect(response.publicIp(InternetAddressType.IPv4), isNotEmpty);
    } catch (e, stack) {
      print('Error: $e');
      print('Stack: $stack');
      rethrow;
    } finally {
      handler.close();
    }
  }, timeout: const Timeout(TestTimeouts.long));
}
