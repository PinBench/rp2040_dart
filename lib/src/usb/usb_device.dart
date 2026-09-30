// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

/// Interface for simulated USB devices that can be connected to the RP2040 USB host controller.
library;

import 'dart:typed_data';

/// TS: `type USBTransferStatus = 'ack' | 'nak' | 'stall'`.
enum USBTransferStatus { ack, nak, stall }

class USBTransferResult {
  USBTransferStatus status;
  Uint8List? data;

  USBTransferResult({required this.status, this.data});
}

class USBEndpointTransfer {
  int endpointAddress;
  Uint8List data;

  USBEndpointTransfer({required this.endpointAddress, required this.data});
}

/// Abstract interface for a USB device that can be connected to the RP2040 USB host.
///
/// A `mixin class`, so a device can `extends`, `with` or `implements` it; the
/// optional TS members ([onAddressAssigned], [onConfigured]) default to no-ops.
abstract mixin class USBDevice {
  /// Current device address (0 = default, 1-127 = assigned)
  abstract int address;

  /// Handle a SETUP packet from the host.
  /// @param setup 8-byte setup packet
  /// @returns Response data for control IN transfers, or status for control OUT
  USBTransferResult handleSetupPacket(Uint8List setup);

  /// Handle data OUT from host to device (non-control endpoint).
  /// @param endpointAddress Endpoint address (0x01-0x0F for OUT endpoints)
  /// @param data Data received from host
  USBTransferResult handleDataOut(int endpointAddress, Uint8List data);

  /// Handle data IN request from host (non-control endpoint).
  /// @param endpointAddress Endpoint address (0x81-0x8F for IN endpoints)
  /// @returns Data to send to host, or NAK if no data available
  USBTransferResult handleDataIn(int endpointAddress);

  /// Called when the host resets the USB bus.
  void onReset();

  /// Called when the host assigns a new address to the device.
  void onAddressAssigned(int address) {}

  /// Called when the host sets the device configuration.
  void onConfigured(int configurationValue) {}
}

// USB Setup packet fields - bmRequestType bit masks
// Direction (bit 7)
const int USB_DIR_OUT = 0x00;
const int USB_DIR_IN = 0x80;
// Type (bits 6:5)
const int USB_TYPE_STANDARD = 0x00;
const int USB_TYPE_CLASS = 0x20;
const int USB_TYPE_VENDOR = 0x40;
// Recipient (bits 4:0)
const int USB_RECIP_DEVICE = 0x00;
const int USB_RECIP_INTERFACE = 0x01;
const int USB_RECIP_ENDPOINT = 0x02;
const int USB_RECIP_OTHER = 0x03;

abstract final class StandardRequest {
  static const int GetStatus = 0;
  static const int ClearFeature = 1;
  static const int SetFeature = 3;
  static const int SetAddress = 5;
  static const int GetDescriptor = 6;
  static const int SetDescriptor = 7;
  static const int GetConfiguration = 8;
  static const int SetConfiguration = 9;
  static const int GetInterface = 10;
  static const int SetInterface = 11;
  static const int SynchFrame = 12;
}

/// Exported from the package as `USBDescriptorType` (it clashes with
/// `DescriptorType` from interfaces.dart).
abstract final class DescriptorType {
  static const int Device = 1;
  static const int Configuration = 2;
  static const int String = 3;
  static const int Interface = 4;
  static const int Endpoint = 5;
  static const int DeviceQualifier = 6;
  static const int OtherSpeedConfiguration = 7;
  static const int InterfacePower = 8;
  static const int HID = 0x21;
  static const int HIDReport = 0x22;
  static const int HIDPhysical = 0x23;
}

/// The TS returns an object literal; in Dart a record.
typedef ParsedSetupPacket = ({
  int bmRequestType,
  int bRequest,
  int wValue,
  int wIndex,
  int wLength,
  // Helpers
  String direction, // 'in' | 'out'
  int type, // 0=Standard, 1=Class, 2=Vendor
  int recipient, // 0=Device, 1=Interface, 2=Endpoint, 3=Other
});

ParsedSetupPacket parseSetupPacket(Uint8List setup) {
  return (
    bmRequestType: setup[0],
    bRequest: setup[1],
    wValue: setup[2] | (setup[3] << 8),
    wIndex: setup[4] | (setup[5] << 8),
    wLength: setup[6] | (setup[7] << 8),
    // Helpers
    direction: (setup[0] & 0x80) != 0 ? 'in' : 'out',
    type: (setup[0] >> 5) & 0x03, // 0=Standard, 1=Class, 2=Vendor
    recipient: setup[0] & 0x1f, // 0=Device, 1=Interface, 2=Endpoint, 3=Other
  );
}
