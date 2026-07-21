/// Default STUN configuration
const defaultStunConfig = (
  address: 'stun.l.google.com',
  port: 19302,
  localPort: 49152,
);

/// Default NAT detector configuration
const defaultNatDetectorConfig = (
  primaryServer: 'stun.l.google.com',
  primaryPort: 19302,
  secondaryServer: 'stun1.l.google.com',
  secondaryPort: 19302,
  timeout: Duration(seconds: 5),
);
