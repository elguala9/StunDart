/// STUN Message Types
class StunMessageType {
  static const int bindingRequest = 0x0001;
  static const int bindingResponse = 0x0101;
  static const int bindingErrorResponse = 0x0111;
}

/// STUN Attribute Types
class StunAttributeType {
  static const int mappedAddress = 0x0001;
  static const int changeRequest = 0x0003;
  static const int changedAddress = 0x0005;
  static const int xorMappedAddress = 0x0020;
  static const int software = 0x8022;
  static const int fingerprint = 0x8028;
  static const int responseOrigin = 0x802b;
  static const int otherAddress = 0x802c;
}

/// STUN Magic Cookie (fixed value in all STUN messages)
const int stunMagicCookie = 0x2112A442;
