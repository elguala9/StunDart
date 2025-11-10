import 'dart:io';
import 'package:test/test.dart';
import 'package:stundart/stundart.dart';

void main() {
  test('Simple STUN request', () async {
    print('Creating socket...');
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    print('Socket created on port: ${socket.port}');
    print('Socket address: ${socket.address}');
    
    final input = (
      address: 'stun.l.google.com',
      port: 19302,
      socket: socket,
    );

    print('Creating STUN handler...');
    final handler = StunHandler(input);

    try {
      print('Performing STUN request...');
      final response = await handler.performStunRequest();
      
      print('Success!');
      print('Public IP: ${response.publicIp}');
      print('Public Port: ${response.publicPort}');
      
      expect(response.publicIp, isNotEmpty);
    } catch (e, stack) {
      print('Error: $e');
      print('Stack: $stack');
      rethrow;
    } finally {
      handler.close();
    }
  }, timeout: const Timeout(Duration(seconds: 15)));
}
