import 'dart:io';
import 'dart:typed_data';
import 'package:stun/stun.dart';
import 'package:test/test.dart';

final _ipv4Type = InternetAddressType.IPv4;
final _ipv6Type = InternetAddressType.IPv6;

// ---------------------------------------------------------------------------
// Fake IStunHandler implementations for unit-testing DualStunHandler
// ---------------------------------------------------------------------------

class _FakeSocket {
  static Future<RawDatagramSocket> ipv4() =>
      RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

  static Future<RawDatagramSocket> ipv6() =>
      RawDatagramSocket.bind(InternetAddress.anyIPv6, 0);
}

/// A fake handler that always returns a fixed StunResponse.
class _SuccessHandler implements IStunHandler {
  _SuccessHandler(this._socket, this._response, {required this.ipVersion});

  final RawDatagramSocket _socket;
  final StunResponse _response;
  final IpVersion ipVersion;
  int callCount = 0;

  @override
  Future<StunResponse> performStunRequest() async {
    callCount++;
    return _response;
  }

  @override
  Future<LocalInfo> performLocalRequest() async => LocalInfo((
    localIp: '127.0.0.1',
    localPort: _socket.port,
    ipVersion: ipVersion,
  ), null);

  @override
  Future<bool> pingStunServer() async => true;

  @override
  void setStunServer(String address, int port) {}

  @override
  RawDatagramSocket getSocket() => _socket;

  @override
  void close() => _socket.close();

  @override
  void destroy() => close();

  @override
  DateTime? get lastStunUpdated => null;

  @override
  DateTime? get lastLocalUpdated => null;

  @override
  InternetAddressType getIpVersion() => ipVersion == IpVersion.v6
      ? InternetAddressType.IPv6
      : InternetAddressType.IPv4;
}

/// A fake handler that always throws on performStunRequest / performLocalRequest.
class _FailingHandler implements IStunHandler {
  _FailingHandler(this._socket, this._error);

  final RawDatagramSocket _socket;
  final Object _error;
  int callCount = 0;

  @override
  Future<StunResponse> performStunRequest() {
    callCount++;
    return Future.error(_error);
  }

  @override
  Future<LocalInfo> performLocalRequest() => Future.error(_error);

  @override
  Future<bool> pingStunServer() async => false;

  @override
  void setStunServer(String address, int port) {}

  @override
  RawDatagramSocket getSocket() => _socket;

  @override
  void close() => _socket.close();

  @override
  void destroy() => close();

  @override
  DateTime? get lastStunUpdated => null;

  @override
  DateTime? get lastLocalUpdated => null;

  @override
  InternetAddressType getIpVersion() => _socket.address.type;
}

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

final _emptyId = Uint8List(12);
final _emptyRaw = Uint8List(0);

final _ipv4Response = createStunResponse(
  publicIpv4: '1.2.3.4',
  publicPortIpv4: 5000,
  transactionIdIpv4: _emptyId,
  rawIpv4: _emptyRaw,
);

final _ipv6Response = createStunResponse(
  publicIpv6: '2001:db8::1',
  publicPortIpv6: 6000,
  ipVersionIpv6: IpVersion.v6,
  transactionIdIpv6: _emptyId,
  rawIpv6: _emptyRaw,
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DualStunHandler - dual-stack parallel execution (unit)', () {
    late RawDatagramSocket ipv4Socket;
    late RawDatagramSocket ipv6Socket;

    setUp(() async {
      ipv4Socket = await _FakeSocket.ipv4();
      ipv6Socket = await _FakeSocket.ipv6();
    });

    tearDown(() {
      try {
        ipv4Socket.close();
      } catch (_) {}
      try {
        ipv6Socket.close();
      } catch (_) {}
    });

    // --- performStunRequest ---

    test('returns only the IPv4 slot when no IPv6 handler is set', () async {
      final dual = DualStunHandler();
      dual.setIpv4Handler(
        _SuccessHandler(ipv4Socket, _ipv4Response, ipVersion: IpVersion.v4),
      );

      final result = await dual.performStunRequest();
      expect(result.publicIp(_ipv4Type), equals('1.2.3.4'));
      expect(result.publicIp(_ipv6Type), isNull);
    });

    test('returns both slots when both handlers succeed', () async {
      final dual = DualStunHandler();
      dual.setIpv4Handler(
        _SuccessHandler(ipv4Socket, _ipv4Response, ipVersion: IpVersion.v4),
      );
      dual.setIpv6Handler(
        _SuccessHandler(ipv6Socket, _ipv6Response, ipVersion: IpVersion.v6),
      );

      final result = await dual.performStunRequest();
      expect(result.publicIp(_ipv4Type), equals('1.2.3.4'));
      expect(result.publicIp(_ipv6Type), equals('2001:db8::1'));
    });

    test('IPv6 slot is null when IPv6 handler throws (SocketException), '
        'IPv4 slot still succeeds', () async {
      final dual = DualStunHandler();
      dual.setIpv4Handler(
        _SuccessHandler(ipv4Socket, _ipv4Response, ipVersion: IpVersion.v4),
      );
      dual.setIpv6Handler(
        _FailingHandler(
          ipv6Socket,
          const SocketException('IPv6 not reachable'),
        ),
      );

      final result = await dual.performStunRequest();
      expect(result.publicIp(_ipv4Type), equals('1.2.3.4'));
      expect(result.publicIp(_ipv6Type), isNull);
    });

    test(
      'IPv6 slot is null when IPv6 handler throws (generic error)',
      () async {
        final dual = DualStunHandler();
        dual.setIpv4Handler(
          _SuccessHandler(ipv4Socket, _ipv4Response, ipVersion: IpVersion.v4),
        );
        dual.setIpv6Handler(_FailingHandler(ipv6Socket, Exception('timeout')));

        final result = await dual.performStunRequest();
        expect(result.publicIp(_ipv4Type), equals('1.2.3.4'));
        expect(result.publicIp(_ipv6Type), isNull);
      },
    );

    test(
      'both handlers are called in parallel (IPv6 failure does not skip IPv4)',
      () async {
        final ipv4Handler = _SuccessHandler(
          ipv4Socket,
          _ipv4Response,
          ipVersion: IpVersion.v4,
        );
        final ipv6Handler = _FailingHandler(
          ipv6Socket,
          const SocketException('DNS lookup failed'),
        );

        final dual = DualStunHandler();
        dual.setIpv4Handler(ipv4Handler);
        dual.setIpv6Handler(ipv6Handler);

        await dual.performStunRequest();

        expect(
          ipv4Handler.callCount,
          equals(1),
          reason: 'IPv4 must be called exactly once',
        );
        expect(
          ipv6Handler.callCount,
          equals(1),
          reason: 'IPv6 must be called exactly once (parallel launch)',
        );
      },
    );

    test('returns null IPv4 slot (not a throw) when IPv4 fails and no '
        'IPv6 handler is set', () async {
      final dual = DualStunHandler();
      dual.setIpv4Handler(
        _FailingHandler(ipv4Socket, Exception('IPv4 broken')),
      );

      final result = await dual.performStunRequest();
      expect(result.publicIp(_ipv4Type), isNull);
      expect(result.publicIp(_ipv6Type), isNull);
    });

    test('returns only the IPv6 slot when no IPv4 handler is set', () async {
      final dual = DualStunHandler();
      dual.setIpv6Handler(
        _SuccessHandler(ipv6Socket, _ipv6Response, ipVersion: IpVersion.v6),
      );

      final result = await dual.performStunRequest();
      expect(result.publicIp(_ipv6Type), equals('2001:db8::1'));
      expect(result.publicIp(_ipv4Type), isNull);
    });

    test('returns null IPv6 slot (not a throw) when IPv6 fails and no '
        'IPv4 handler is set', () async {
      final dual = DualStunHandler();
      dual.setIpv6Handler(
        _FailingHandler(ipv6Socket, Exception('IPv6 broken')),
      );

      final result = await dual.performStunRequest();
      expect(result.publicIp(_ipv6Type), isNull);
      expect(result.publicIp(_ipv4Type), isNull);
    });

    test('throws StateError when no handler is initialized', () async {
      final dual = DualStunHandler();

      await expectLater(dual.performStunRequest(), throwsA(isA<StateError>()));
    });

    // --- performLocalRequest ---

    test(
      'returns only the IPv4 local slot when no IPv6 handler is set',
      () async {
        final dual = DualStunHandler();
        dual.setIpv4Handler(
          _SuccessHandler(ipv4Socket, _ipv4Response, ipVersion: IpVersion.v4),
        );

        final info = await dual.performLocalRequest();
        expect(info.localPortIpv4, greaterThan(0));
        expect(info.localIpv6, isNull);
      },
    );

    test('IPv6 local slot is null when IPv6 performLocalRequest throws, '
        'IPv4 slot still succeeds', () async {
      final dual = DualStunHandler();
      dual.setIpv4Handler(
        _SuccessHandler(ipv4Socket, _ipv4Response, ipVersion: IpVersion.v4),
      );
      dual.setIpv6Handler(
        _FailingHandler(ipv6Socket, const SocketException('no IPv6')),
      );

      final info = await dual.performLocalRequest();
      expect(info.localPortIpv4, equals(ipv4Socket.port));
      expect(info.localIpv6, isNull);
    });

    test(
      'returns only the IPv6 local slot when no IPv4 handler is set',
      () async {
        final dual = DualStunHandler();
        dual.setIpv6Handler(
          _SuccessHandler(ipv6Socket, _ipv6Response, ipVersion: IpVersion.v6),
        );

        final info = await dual.performLocalRequest();
        expect(info.localPortIpv6, equals(ipv6Socket.port));
        expect(info.localIpv4, isNull);
      },
    );
  });

  group('DualStunHandler - socket type validation (unit)', () {
    late RawDatagramSocket ipv4Socket;
    late RawDatagramSocket ipv6Socket;

    setUp(() async {
      ipv4Socket = await _FakeSocket.ipv4();
      ipv6Socket = await _FakeSocket.ipv6();
    });

    tearDown(() {
      try {
        ipv4Socket.close();
      } catch (_) {}
      try {
        ipv6Socket.close();
      } catch (_) {}
    });

    test(
      'setIpv4Handler throws ArgumentError when given an IPv6 socket',
      () async {
        final dual = DualStunHandler();

        expect(
          () => dual.setIpv4Handler(
            _SuccessHandler(ipv6Socket, _ipv6Response, ipVersion: IpVersion.v6),
          ),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          dual.ipv4Handler,
          isNull,
          reason: 'Rejected handler must not be stored',
        );
      },
    );

    test(
      'setIpv6Handler throws ArgumentError when given an IPv4 socket',
      () async {
        final dual = DualStunHandler();

        expect(
          () => dual.setIpv6Handler(
            _SuccessHandler(ipv4Socket, _ipv4Response, ipVersion: IpVersion.v4),
          ),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          dual.ipv6Handler,
          isNull,
          reason: 'Rejected handler must not be stored',
        );
      },
    );

    test(
      'setIpv4Handler accepts a handler with a matching IPv4 socket',
      () async {
        final dual = DualStunHandler();
        final handler = _SuccessHandler(
          ipv4Socket,
          _ipv4Response,
          ipVersion: IpVersion.v4,
        );

        dual.setIpv4Handler(handler);
        expect(dual.ipv4Handler, same(handler));
      },
    );

    test(
      'setIpv6Handler accepts a handler with a matching IPv6 socket',
      () async {
        final dual = DualStunHandler();
        final handler = _SuccessHandler(
          ipv6Socket,
          _ipv6Response,
          ipVersion: IpVersion.v6,
        );

        dual.setIpv6Handler(handler);
        expect(dual.ipv6Handler, same(handler));
      },
    );

    test(
      'replaceHandler(type: InternetAddressType.IPv4) throws ArgumentError given an IPv6 '
      'socket handler',
      () async {
        final dual = DualStunHandler();

        expect(
          () => dual.replaceHandler(
            _SuccessHandler(ipv6Socket, _ipv6Response, ipVersion: IpVersion.v6),
            type: InternetAddressType.IPv4,
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test(
      'replaceHandler(type: InternetAddressType.IPv6) throws ArgumentError given an IPv4 '
      'socket handler',
      () async {
        final dual = DualStunHandler();

        expect(
          () => dual.replaceHandler(
            _SuccessHandler(ipv4Socket, _ipv4Response, ipVersion: IpVersion.v4),
            type: InternetAddressType.IPv6,
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );
  });

  group('DualStunHandler - clearIpv4Handler / clearIpv6Handler (unit)', () {
    late RawDatagramSocket ipv4Socket;
    late RawDatagramSocket ipv6Socket;

    setUp(() async {
      ipv4Socket = await _FakeSocket.ipv4();
      ipv6Socket = await _FakeSocket.ipv6();
    });

    tearDown(() {
      try {
        ipv4Socket.close();
      } catch (_) {}
      try {
        ipv6Socket.close();
      } catch (_) {}
    });

    test('clearIpv4Handler sets ipv4Handler back to null', () async {
      final dual = DualStunHandler();
      dual.setIpv4Handler(
        _SuccessHandler(ipv4Socket, _ipv4Response, ipVersion: IpVersion.v4),
      );

      dual.clearIpv4Handler();
      expect(dual.ipv4Handler, isNull);
    });

    test('clearIpv6Handler sets ipv6Handler back to null', () async {
      final dual = DualStunHandler();
      dual.setIpv6Handler(
        _SuccessHandler(ipv6Socket, _ipv6Response, ipVersion: IpVersion.v6),
      );

      dual.clearIpv6Handler();
      expect(dual.ipv6Handler, isNull);
    });

    test('performStunRequest returns only the IPv6 slot after '
        'clearIpv4Handler', () async {
      final dual = DualStunHandler();
      dual.setIpv4Handler(
        _SuccessHandler(ipv4Socket, _ipv4Response, ipVersion: IpVersion.v4),
      );
      dual.setIpv6Handler(
        _SuccessHandler(ipv6Socket, _ipv6Response, ipVersion: IpVersion.v6),
      );

      dual.clearIpv4Handler();

      final result = await dual.performStunRequest();
      expect(result.publicIp(_ipv4Type), isNull);
      expect(result.publicIp(_ipv6Type), equals('2001:db8::1'));
    });

    test('performStunRequest throws StateError once both handlers are '
        'cleared', () async {
      final dual = DualStunHandler();
      dual.setIpv4Handler(
        _SuccessHandler(ipv4Socket, _ipv4Response, ipVersion: IpVersion.v4),
      );
      dual.setIpv6Handler(
        _SuccessHandler(ipv6Socket, _ipv6Response, ipVersion: IpVersion.v6),
      );

      dual.clearIpv4Handler();
      dual.clearIpv6Handler();

      await expectLater(dual.performStunRequest(), throwsA(isA<StateError>()));
    });

    test(
      'getSocket(type: InternetAddressType.IPv4) throws StateError after clearIpv4Handler',
      () async {
        final dual = DualStunHandler();
        dual.setIpv4Handler(
          _SuccessHandler(ipv4Socket, _ipv4Response, ipVersion: IpVersion.v4),
        );

        dual.clearIpv4Handler();

        expect(
          () => dual.getSocket(type: InternetAddressType.IPv4),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'pingStunServer(type: InternetAddressType.IPv4) throws StateError after '
      'clearIpv4Handler',
      () async {
        final dual = DualStunHandler();
        dual.setIpv4Handler(
          _SuccessHandler(ipv4Socket, _ipv4Response, ipVersion: IpVersion.v4),
        );

        dual.clearIpv4Handler();

        expect(
          () => dual.pingStunServer(type: InternetAddressType.IPv4),
          throwsA(isA<StateError>()),
        );
      },
    );
  });
}
