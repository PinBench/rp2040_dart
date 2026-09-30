// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

abstract final class DataDirection {
  static const int HostToDevice = 0;
  static const int DeviceToHost = 1;
}

abstract final class SetupType {
  static const int Standard = 0;
  static const int Class = 1;
  static const int Vendor = 2;
  static const int Reserved = 3;
}

abstract final class SetupRecipient {
  static const int Device = 0;
  static const int Interface = 1;
  static const int Endpoint = 2;
  static const int Other = 3;
}

abstract final class SetupRequest {
  static const int GetStatus = 0;
  static const int ClearFeature = 1;
  static const int Reserved1 = 2;
  static const int SetFeature = 3;
  static const int Reserved2 = 4;
  static const int SetAddress = 5;
  static const int GetDescriptor = 6;
  static const int SetDescriptor = 7;
  static const int GetConfiguration = 8;
  static const int SetDeviceConfiguration = 9;
  static const int GetInterface = 10;
  static const int SetInterface = 11;
  static const int SynchFrame = 12;
}

abstract final class DescriptorType {
  static const int Device = 1;
  static const int Configration = 2;
  static const int String = 3;
  static const int Interface = 4;
  static const int Endpoint = 5;
}

/// A TS object-literal interface; in Dart a plain value class, so callers can
/// build one inline (`ISetupPacketParams(dataDirection: ..., ...)`).
class ISetupPacketParams {
  final int dataDirection; // DataDirection
  final int type; // SetupType
  final int recipient; // SetupRecipient
  final int bRequest; // SetupRequest | number
  final int wValue; /* 16 bits */
  final int wIndex; /* 16 bits */
  final int wLength; /* 16 bits */

  const ISetupPacketParams({
    required this.dataDirection,
    required this.type,
    required this.recipient,
    required this.bRequest,
    required this.wValue,
    required this.wIndex,
    required this.wLength,
  });
}
