// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'dart:math' as math;
import 'dart:typed_data';

import '../peripherals/usb.dart';
import '../utils/fifo.dart';
import 'interfaces.dart';
import 'setup.dart';

// CDC stuff
const int _CDC_REQUEST_SET_CONTROL_LINE_STATE = 0x22;

const int _CDC_DTR = 1 << 0;
const int _CDC_RTS = 1 << 1;

const int _CDC_DATA_CLASS = 10;
const int _ENDPOINT_BULK = 2;

const int _TX_FIFO_SIZE = 512;

const int _ENDPOINT_ZERO = 0;
const int _CONFIGURATION_DESCRIPTOR_SIZE = 9;

/// Returns the bulk IN/OUT endpoint numbers of the CDC data interface, or -1.
///
/// The TS returns `{ in, out }`; `in` is a reserved word in Dart, so the
/// record field is `in_`.
({int in_, int out}) extractEndpointNumbers(List<int> descriptors) {
  var index = 0;
  var foundInterface = false;
  var resultIn = -1;
  var resultOut = -1;
  while (index < descriptors.length) {
    final len = descriptors[index];
    if (len < 2 || descriptors.length < index + len) {
      break;
    }
    final type = descriptors[index + 1];
    if (type == DescriptorType.Interface && len == 9) {
      final numEndpoints = descriptors[index + 4];
      final interfaceClass = descriptors[index + 5];
      foundInterface = numEndpoints == 2 && interfaceClass == _CDC_DATA_CLASS;
    }
    if (foundInterface && type == DescriptorType.Endpoint && len == 7) {
      final address = descriptors[index + 2];
      final attributes = descriptors[index + 3];
      if ((attributes & 0x3) == _ENDPOINT_BULK) {
        if ((address & 0x80) != 0) {
          resultIn = address & 0xf;
        } else {
          resultOut = address & 0xf;
        }
      }
    }
    index += descriptors[index];
  }
  return (in_: resultIn, out: resultOut);
}

class USBCDC {
  final FIFO txFIFO = FIFO(_TX_FIFO_SIZE);

  void Function(Uint8List buffer)? onSerialData;
  void Function()? onDeviceConnected;

  bool _initialized = false;
  int? _descriptorsSize;
  final List<int> _descriptors = [];
  int _outEndpoint = -1;
  int _inEndpoint = -1;

  final RPUSBController usb;

  USBCDC(this.usb) {
    usb.onUSBEnabled = () {
      usb.resetDevice();
    };
    usb.onResetReceived = () {
      usb.sendSetupPacket(setDeviceAddressPacket(1));
    };
    usb.onEndpointWrite = (int endpoint, Uint8List buffer) {
      if (endpoint == _ENDPOINT_ZERO && buffer.isEmpty) {
        if (_descriptorsSize == null) {
          usb.sendSetupPacket(
            getDescriptorPacket(
              DescriptorType.Configration,
              _CONFIGURATION_DESCRIPTOR_SIZE,
            ),
          );
        }
        // Acknowledgement
        else if (!_initialized) {
          _cdcSetControlLineState();
          onDeviceConnected?.call();
        }
      }
      if (endpoint == _ENDPOINT_ZERO && buffer.length > 1) {
        if (buffer.length == _CONFIGURATION_DESCRIPTOR_SIZE &&
            buffer[1] == DescriptorType.Configration &&
            _descriptorsSize == null) {
          final descriptorsSize = (buffer[3] << 8) | buffer[2];
          _descriptorsSize = descriptorsSize;
          usb.sendSetupPacket(
            getDescriptorPacket(DescriptorType.Configration, descriptorsSize),
          );
        } else if (_descriptorsSize != null &&
            _descriptors.length < _descriptorsSize!) {
          _descriptors.addAll(buffer);
        }
        if (_descriptorsSize == _descriptors.length) {
          final endpoints = extractEndpointNumbers(_descriptors);
          _inEndpoint = endpoints.in_;
          _outEndpoint = endpoints.out;

          // Now configure the device
          usb.sendSetupPacket(setDeviceConfigurationPacket(1));
        }
      }
      if (endpoint == _inEndpoint) {
        onSerialData?.call(buffer);
      }
    };
    usb.onEndpointRead = (int endpoint, int size) {
      if (endpoint == _outEndpoint) {
        final buffer = Uint8List(math.min(size, txFIFO.itemCount));
        for (var i = 0; i < buffer.length; i++) {
          buffer[i] = txFIFO.pull();
        }
        usb.endpointReadDone(_outEndpoint, buffer);
      }
    };
  }

  void _cdcSetControlLineState([
    int value = _CDC_DTR | _CDC_RTS,
    int interfaceNumber = 0,
  ]) {
    usb.sendSetupPacket(
      createSetupPacket(
        ISetupPacketParams(
          dataDirection: DataDirection.HostToDevice,
          type: SetupType.Class,
          recipient: SetupRecipient.Device,
          bRequest: _CDC_REQUEST_SET_CONTROL_LINE_STATE,
          wValue: value,
          wIndex: interfaceNumber,
          wLength: 0,
        ),
      ),
    );
    _initialized = true;
  }

  void sendSerialByte(int data) {
    txFIFO.push(data);
  }
}
