// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'dart:typed_data';

import 'interfaces.dart';

Uint8List createSetupPacket(ISetupPacketParams params) {
  final setupPacket = Uint8List(8);
  setupPacket[0] =
      (params.dataDirection << 7) | (params.type << 5) | params.recipient;
  setupPacket[1] = params.bRequest;
  setupPacket[2] = params.wValue & 0xff;
  setupPacket[3] = (params.wValue >> 8) & 0xff;
  setupPacket[4] = params.wIndex & 0xff;
  setupPacket[5] = (params.wIndex >> 8) & 0xff;
  setupPacket[6] = params.wLength & 0xff;
  setupPacket[7] = (params.wLength >> 8) & 0xff;
  return setupPacket;
}

Uint8List setDeviceAddressPacket(int address) {
  return createSetupPacket(
    ISetupPacketParams(
      dataDirection: DataDirection.HostToDevice,
      type: SetupType.Standard,
      recipient: SetupRecipient.Device,
      bRequest: SetupRequest.SetAddress,
      wValue: address,
      wIndex: 0,
      wLength: 0,
    ),
  );
}

/// [type] is a [DescriptorType] value.
Uint8List getDescriptorPacket(int type, int length, [int index = 0]) {
  return createSetupPacket(
    ISetupPacketParams(
      dataDirection: DataDirection.DeviceToHost,
      type: SetupType.Standard,
      recipient: SetupRecipient.Device,
      bRequest: SetupRequest.GetDescriptor,
      wValue: type << 8,
      wIndex: index,
      wLength: length,
    ),
  );
}

Uint8List setDeviceConfigurationPacket(int configurationNumber) {
  return createSetupPacket(
    ISetupPacketParams(
      dataDirection: DataDirection.HostToDevice,
      type: SetupType.Standard,
      recipient: SetupRecipient.Device,
      bRequest: SetupRequest.SetDeviceConfiguration,
      wValue: configurationNumber,
      wIndex: 0,
      wLength: 0,
    ),
  );
}
