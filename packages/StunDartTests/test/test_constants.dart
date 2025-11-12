/// Test constants used across multiple test files
library test_constants;

/// STUN servers used for testing
class StunServers {
  static const googleStun = 'stun.l.google.com';
  static const googleStun1 = 'stun1.l.google.com';
  static const googleStun2 = 'stun2.l.google.com';
  static const googleStun3 = 'stun3.l.google.com';
  static const googleStun4 = 'stun4.l.google.com';
  static const stunProtocol = 'stun.stunprotocol.org';
  
  /// Default STUN port
  static const defaultPort = 19302;
  
  /// Alternative STUN port
  static const alternativePort = 3478;
  
  /// Test-NET-1 address (reserved, should not respond)
  static const testNet1 = '192.0.2.1';
  
  /// List of primary Google STUN servers
  static const List<String> googleServers = [
    googleStun,
    googleStun1,
    googleStun2,
  ];
  
  /// List of all available STUN servers
  static const List<String> allServers = [
    googleStun,
    googleStun1,
    googleStun2,
    googleStun3,
    googleStun4,
    stunProtocol,
  ];
}

/// Timeout configurations for tests
class TestTimeouts {
  /// Short timeout for quick operations
  static const Duration short = Duration(seconds: 5);
  
  /// Medium timeout for standard STUN requests
  static const Duration medium = Duration(seconds: 10);
  
  /// Long timeout for IPv6 or multiple server tests
  static const Duration long = Duration(seconds: 15);
  
  /// Extra long timeout for comprehensive tests
  static const Duration extraLong = Duration(seconds: 40);
  
  /// Timeout for full dual-stack tests
  static const Duration dualStack = Duration(seconds: 60);
}

/// Server configurations as records
class ServerConfigs {
  static const ipv6Servers = [
    (name: 'Google STUN', address: StunServers.googleStun, port: StunServers.defaultPort),
    (name: 'Google STUN 1', address: StunServers.googleStun1, port: StunServers.defaultPort),
    (name: 'Google STUN 2', address: StunServers.googleStun2, port: StunServers.defaultPort),
  ];
}
