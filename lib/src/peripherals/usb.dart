// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

// The register map below is kept whole, as in rp2040js, even where a constant is unused.
// ignore_for_file: unused_element, unused_field

import 'dart:math' as math;
import 'dart:typed_data';

import '../clock/clock.dart';
import '../irq.dart';
import '../rp2040.dart';
import '../usb/usb_device.dart';
import 'peripheral.dart';

const int _ENDPOINT_COUNT = 16;
const int _USB_HOST_INTERRUPT_ENDPOINTS = 15;

// USB DPSRAM Registers - Device mode
const int _EP1_IN_CONTROL = 0x8;
const int _EP0_IN_BUFFER_CONTROL = 0x80;
const int _EP0_OUT_BUFFER_CONTROL = 0x84;
const int _EP15_OUT_BUFFER_CONTROL = 0xfc;

// USB DPRAM Registers - Host mode
// Host DPRAM layout (from pico-sdk hardware/structs/usb.h):
// 0x00-0x07: setup_packet (8 bytes)
// 0x08-0x7f: int_ep_ctrl[15] (15 × 8 bytes, ctrl + spare per entry)
// 0x80: epx_buf_ctrl (4 bytes)
// 0x84: _spare0 (4 bytes)
// 0x88-0xff: int_ep_buffer_ctrl[15] (15 × 8 bytes, ctrl + spare per entry)
// 0x100: epx_ctrl (4 bytes)
// 0x104-0x17f: _spare1 (124 bytes)
// 0x180+: epx_data buffer (up to end of DPRAM)
const int _HOST_SETUP_PACKET = 0x00;
const int _HOST_INT_EP_CTRL_BASE = 0x08; // int_ep_ctrl[0] at 0x08, stride 8
const int _HOST_INT_EP_BUF_CTRL_BASE =
    0x88; // int_ep_buffer_ctrl[0] at 0x88, stride 8
const int _HOST_EPX_BUF_CTRL = 0x80;
const int _HOST_EPX_DATA = 0x180;

// Endpoint Control bits
const int _USB_CTRL_DOUBLE_BUF = 1 << 30;
const int _USB_CTRL_INTERRUPT_PER_TRANSFER = 1 << 29;
const int _EP_CTRL_ENABLE_BITS = 0x80000000; // 1 << 31
const int _EP_CTRL_BUFFER_TYPE_LSB = 26;
const int _EP_CTRL_HOST_INTERRUPT_INTERVAL_LSB = 16;

// Buffer Control bits
const int _USB_BUF_CTRL_AVAILABLE = 1 << 10;
const int _USB_BUF_CTRL_FULL = 1 << 15;
const int _USB_BUF_CTRL_LEN_MASK = 0x3ff;
const int _USB_BUF_CTRL_DATA1_PID = 1 << 13;
const int _USB_BUF_CTRL_LAST = 1 << 14;
// Buffer1
const int _USB_BUF1_SHIFT = 16;
const int _USB_BUF1_OFFSET = 64;

// USB Peripheral Registers
const int _ADDR_ENDP = 0x0;
const int _ADDR_ENDP1 = 0x04;
const int _ADDR_ENDP15 = 0x3c;
const int _MAIN_CTRL = 0x40;
const int _SOF_WR = 0x44;
const int _SOF_RD = 0x48;
const int _SIE_CTRL = 0x4c;
const int _SIE_STATUS = 0x50;
const int _INT_EP_CTRL = 0x54;
const int _BUFF_STATUS = 0x58;
const int _BUFF_CPU_SHOULD_HANDLE = 0x5c;
const int _EP_ABORT = 0x60;
const int _EP_ABORT_DONE = 0x64;
const int _EP_STALL_ARM = 0x68;
const int _NAK_POLL = 0x6c;
const int _EP_STATUS_STALL_NAK = 0x70;
const int _USB_MUXING = 0x74;
const int _USB_PWR = 0x78;
const int _USBPHY_DIRECT = 0x7c;
const int _USBPHY_DIRECT_OVERRIDE = 0x80;
const int _USBPHY_TRIM = 0x84;
const int _INTR = 0x8c;
const int _INTE = 0x90;
const int _INTF = 0x94;
const int _INTS = 0x98;

// MAIN_CTRL bits
const int _SIM_TIMING = 0x80000000; // 1 << 31
const int _HOST_NDEVICE = 1 << 1;
const int _CONTROLLER_EN = 1 << 0;

// SIE_CTRL bits (host mode)
const int _SIE_CTRL_EP0_INT_STALL = 0x80000000; // 1 << 31
const int _SIE_CTRL_EP0_DOUBLE_BUF = 1 << 30;
const int _SIE_CTRL_EP0_INT_1BUF = 1 << 29;
const int _SIE_CTRL_EP0_INT_2BUF = 1 << 28;
const int _SIE_CTRL_EP0_INT_NAK = 1 << 27;
const int _SIE_CTRL_DIRECT_EN = 1 << 26;
const int _SIE_CTRL_DIRECT_DP = 1 << 25;
const int _SIE_CTRL_DIRECT_DM = 1 << 24;
const int _SIE_CTRL_TRANSCEIVER_PD = 1 << 18;
const int _SIE_CTRL_RPU_OPT = 1 << 17;
const int _SIE_CTRL_PULLUP_EN = 1 << 16;
const int _SIE_CTRL_PULLDOWN_EN = 1 << 15;
const int _SIE_CTRL_RESET_BUS = 1 << 13;
const int _SIE_CTRL_RESUME = 1 << 12;
const int _SIE_CTRL_VBUS_EN = 1 << 11;
const int _SIE_CTRL_KEEP_ALIVE_EN = 1 << 10;
const int _SIE_CTRL_SOF_EN = 1 << 9;
const int _SIE_CTRL_SOF_SYNC = 1 << 8;
const int _SIE_CTRL_PREAMBLE_EN = 1 << 6;
const int _SIE_CTRL_STOP_TRANS = 1 << 4;
const int _SIE_CTRL_RECEIVE_DATA = 1 << 3;
const int _SIE_CTRL_SEND_DATA = 1 << 2;
const int _SIE_CTRL_SEND_SETUP = 1 << 1;
const int _SIE_CTRL_START_TRANS = 1 << 0;

// SIE_STATUS bits
const int _SIE_DATA_SEQ_ERROR = 0x80000000; // 1 << 31
const int _SIE_ACK_REC = 1 << 30;
const int _SIE_STALL_REC = 1 << 29;
const int _SIE_NAK_REC = 1 << 28;
const int _SIE_RX_TIMEOUT = 1 << 27;
const int _SIE_RX_OVERFLOW = 1 << 26;
const int _SIE_BIT_STUFF_ERROR = 1 << 25;
const int _SIE_CRC_ERROR = 1 << 24;
const int _SIE_BUS_RESET = 1 << 19;
const int _SIE_TRANS_COMPLETE = 1 << 18;
const int _SIE_SETUP_REC = 1 << 17;
const int _SIE_CONNECTED = 1 << 16;
const int _SIE_RESUME = 1 << 11;
const int _SIE_VBUS_OVER_CURR = 1 << 10;
const int _SIE_SPEED = 1 << 9;
const int _SIE_SPEED_LS_VALUE = 1; // Low speed
const int _SIE_SPEED_FS_VALUE = 2; // Full speed
const int _SIE_SUSPENDED = 1 << 4;
const int _SIE_LINE_STATE_MASK = 0x3;
const int _SIE_LINE_STATE_SHIFT = 2;
const int _SIE_VBUS_DETECTED = 1 << 0;

// USB_MUXING bits
const int _SOFTCON = 1 << 3;
const int _TO_DIGITAL_PAD = 1 << 2;
const int _TO_EXTPHY = 1 << 1;
const int _TO_PHY = 1 << 0;

// USB_PWR bits
const int _PWR_VBUS_DETECT = 1 << 3;
const int _PWR_VBUS_DETECT_OVERRIDE_EN = 1 << 2;
const int _PWR_OVERCURR_DETECT = 1 << 1;
const int _PWR_OVERCURR_DETECT_EN = 1 << 0;

// INTR bits (directly from RP2040 datasheet)
const int _INTR_EP_STALL_NAK = 1 << 19;
const int _INTR_ABORT_DONE = 1 << 18;
const int _INTR_DEV_SOF = 1 << 17;
const int _INTR_SETUP_REQ = 1 << 16;
const int _INTR_DEV_RESUME_FROM_HOST = 1 << 15;
const int _INTR_DEV_SUSPEND = 1 << 14;
const int _INTR_DEV_CONN_DIS = 1 << 13;
const int _INTR_BUS_RESET = 1 << 12;
const int _INTR_VBUS_DETECT = 1 << 11;
const int _INTR_STALL = 1 << 10;
const int _INTR_ERROR_CRC = 1 << 9;
const int _INTR_ERROR_BIT_STUFF = 1 << 8;
const int _INTR_ERROR_RX_OVERFLOW = 1 << 7;
const int _INTR_ERROR_RX_TIMEOUT = 1 << 6;
const int _INTR_ERROR_DATA_SEQ = 1 << 5;
const int _INTR_BUFF_STATUS = 1 << 4;
const int _INTR_TRANS_COMPLETE = 1 << 3;
const int _INTR_HOST_SOF = 1 << 2;
const int _INTR_HOST_RESUME = 1 << 1;
const int _INTR_HOST_CONN_DIS = 1 << 0;

// SIE Line states
abstract final class _SIELineState {
  static const int SE0 = 0x0; // 0b00
  static const int J = 0x1; // 0b01
  static const int K = 0x2; // 0b10
  static const int SE1 = 0x3; // 0b11
}

const int _SIE_WRITECLEAR_MASK =
    _SIE_DATA_SEQ_ERROR |
    _SIE_ACK_REC |
    _SIE_STALL_REC |
    _SIE_NAK_REC |
    _SIE_RX_TIMEOUT |
    _SIE_RX_OVERFLOW |
    _SIE_BIT_STUFF_ERROR |
    _SIE_CONNECTED |
    _SIE_CRC_ERROR |
    _SIE_BUS_RESET |
    _SIE_TRANS_COMPLETE |
    _SIE_SETUP_REC |
    _SIE_RESUME;

/// TS `Uint8Array.prototype.slice(start, end)`: a copy, with the bounds
/// clamped to the array (Dart's `sublist` throws instead).
Uint8List _slice(Uint8List array, int start, int end) {
  final length = array.length;
  return array.sublist(math.min(start, length), math.min(end, length));
}

class _USBEndpointAlarm {
  List<Uint8List> buffers = [];

  final IAlarm alarm;

  _USBEndpointAlarm(this.alarm);

  void schedule(Uint8List buffer, double delayNanos) {
    buffers.add(buffer);
    alarm.schedule(delayNanos);
  }
}

class RPUSBController extends BasePeripheral {
  // Common registers
  int _addrEndp = 0;
  int _mainCtrl = 0;
  int _intRaw = 0;
  int _intEnable = 0;
  int _intForce = 0;
  int _sieStatus = 0;
  int _buffStatus = 0;

  // Host mode registers
  int _sieCtrl = 0;
  int _sofFrameNumber = 0;
  int _devAddrCtrl =
      0; // Device address and endpoint for non-interrupt transfers
  final List<int> _intEpAddrCtrl = List<int>.filled(
    _USB_HOST_INTERRUPT_ENDPOINTS,
    0,
  );
  int _intEpCtrl = 0; // Interrupt endpoint control (enable bits)
  int _usbPwr = 0;
  int _nakPoll = 0;
  int _epAbort = 0;
  int _epAbortDone = 0;
  int _epStallArm = 0;
  int _epStatusStallNak = 0;

  // Host mode state
  bool _hostMode = false;
  bool _sofEnabled = false;
  USBDevice? _connectedDevice;
  Uint8List? _pendingSetupResponse;
  int _controlDataPid = 1; // DATA0/DATA1 toggle for control transfers
  bool _expectingStatusPhase =
      false; // True when expecting IN status for control OUT

  // Alarms
  final List<_USBEndpointAlarm> _endpointReadAlarms = [];
  final List<_USBEndpointAlarm> _endpointWriteAlarms = [];
  // Assigned in the constructor body: their callbacks capture `this`.
  late final IAlarm _resetAlarm;
  late final IAlarm _sofAlarm;
  late final IAlarm _hostTransactionAlarm;

  // Device mode callbacks
  void Function()? onUSBEnabled;
  void Function()? onResetReceived;
  void Function(int endpoint, Uint8List buffer)? onEndpointWrite;
  void Function(int endpoint, int byteCount)? onEndpointRead;

  double readDelayMicroseconds = 10;
  double writeDelayMicroseconds = 10; // Determined empirically
  double hostTransactionDelayMicroseconds = 5; // Host transaction delay

  int get intStatus {
    return (_intRaw & _intEnable) | _intForce;
  }

  RPUSBController(RP2040 rp2040, String name) : super(rp2040, name) {
    final clock = rp2040.clock;
    for (var i = 0; i < _ENDPOINT_COUNT; ++i) {
      _endpointReadAlarms.add(
        _USBEndpointAlarm(
          clock.createAlarm(() {
            final buffers = _endpointReadAlarms[i].buffers;
            final buffer = buffers.isNotEmpty ? buffers.removeAt(0) : null;
            if (buffer != null) {
              _finishRead(i, buffer);
            }
          }),
        ),
      );
      _endpointWriteAlarms.add(
        _USBEndpointAlarm(
          clock.createAlarm(() {
            // An index loop, like JS `for...of`: it also visits buffers
            // appended while iterating (a Dart iterator would throw).
            final buffers = _endpointWriteAlarms[i].buffers;
            for (var j = 0; j < buffers.length; j++) {
              onEndpointWrite?.call(i, buffers[j]);
            }
            _endpointWriteAlarms[i].buffers = [];
          }),
        ),
      );
    }
    _resetAlarm = clock.createAlarm(() {
      _sieStatus |= _SIE_BUS_RESET;
      _sieStatusUpdated();
    });

    // Host mode alarms
    _sofAlarm = clock.createAlarm(() {
      _generateSOF();
    });
    _hostTransactionAlarm = clock.createAlarm(() {
      _completeHostTransaction();
    });
  }

  @override
  int readUint32(int offset) {
    // Handle interrupt endpoint address registers (ADDR_ENDP1 through ADDR_ENDP15)
    if (offset >= _ADDR_ENDP1 &&
        offset <= _ADDR_ENDP15 &&
        (offset & 0x3) == 0) {
      final epIndex = (offset - _ADDR_ENDP1) >> 2;
      return _intEpAddrCtrl[epIndex];
    }

    switch (offset) {
      case _ADDR_ENDP:
        return _hostMode
            ? _devAddrCtrl
            : _addrEndp & 0x7807f; // 0b1111000000001111111
      case _MAIN_CTRL:
        return _mainCtrl;
      case _SOF_WR:
        return 0; // Write-only
      case _SOF_RD:
        return _sofFrameNumber & 0x7ff;
      case _SIE_CTRL:
        return _sieCtrl;
      case _SIE_STATUS:
        // In host mode, reading SIE_STATUS acknowledges the connection event
        // Clear HOST_CONN_DIS interrupt once firmware reads the status
        if (_hostMode && (_intRaw & _INTR_HOST_CONN_DIS) != 0) {
          _intRaw &= ~_INTR_HOST_CONN_DIS;
          _checkInterrupts();
        }
        return _sieStatus;
      case _INT_EP_CTRL:
        return _intEpCtrl;
      case _BUFF_STATUS:
        return _buffStatus;
      case _BUFF_CPU_SHOULD_HANDLE:
        return 0;
      case _EP_ABORT:
        return _epAbort;
      case _EP_ABORT_DONE:
        return _epAbortDone;
      case _EP_STALL_ARM:
        return _epStallArm;
      case _NAK_POLL:
        return _nakPoll;
      case _EP_STATUS_STALL_NAK:
        return _epStatusStallNak;
      case _USB_PWR:
        return _usbPwr;
      case _INTR:
        return _intRaw;
      case _INTE:
        return _intEnable;
      case _INTF:
        return _intForce;
      case _INTS:
        return intStatus;
    }
    return super.readUint32(offset);
  }

  @override
  void writeUint32(int offset, int value) {
    // Handle interrupt endpoint address registers (ADDR_ENDP1 through ADDR_ENDP15)
    if (offset >= _ADDR_ENDP1 &&
        offset <= _ADDR_ENDP15 &&
        (offset & 0x3) == 0) {
      final epIndex = (offset - _ADDR_ENDP1) >> 2;
      _intEpAddrCtrl[epIndex] = value;
      return;
    }

    switch (offset) {
      case _ADDR_ENDP:
        if (_hostMode) {
          _devAddrCtrl = value;
        } else {
          _addrEndp = value;
        }
        break;
      case _MAIN_CTRL:
        _mainCtrl = value & (_SIM_TIMING | _CONTROLLER_EN | _HOST_NDEVICE);
        _hostMode = (value & _HOST_NDEVICE) != 0;
        if ((value & _CONTROLLER_EN) != 0) {
          if (_hostMode) {
            debug('USB Host mode enabled');
            // In host mode, check if a device is already connected
            if (_connectedDevice != null) {
              _onDeviceConnected();
            }
          } else {
            onUSBEnabled?.call();
          }
        }
        break;
      case _SOF_WR:
        _sofFrameNumber = value & 0x7ff;
        break;
      case _SIE_CTRL:
        _handleSieCtrlWrite(value);
        break;
      case _INT_EP_CTRL:
        _intEpCtrl = value;
        break;
      case _BUFF_STATUS:
        _buffStatus &= ~rawWriteValue;
        _buffStatusUpdated();
        break;
      case _EP_ABORT:
        _epAbort = value;
        // Immediately mark as done
        _epAbortDone |= value;
        break;
      case _EP_ABORT_DONE:
        _epAbortDone &= ~rawWriteValue;
        break;
      case _EP_STALL_ARM:
        _epStallArm = value;
        break;
      case _NAK_POLL:
        _nakPoll = value;
        break;
      case _EP_STATUS_STALL_NAK:
        _epStatusStallNak &= ~rawWriteValue;
        break;
      case _USB_MUXING:
        // Workaround for busy wait in hw_enumeration_fix_force_ls_j() / hw_enumeration_fix_finish():
        if ((value & _TO_DIGITAL_PAD) != 0 && (value & _TO_PHY) == 0) {
          _sieStatus |= _SIE_CONNECTED;
        }
        break;
      case _USB_PWR:
        _usbPwr = value;
        // VBUS detect override - set VBUS detected in SIE_STATUS
        if ((value & _PWR_VBUS_DETECT_OVERRIDE_EN) != 0) {
          if ((value & _PWR_VBUS_DETECT) != 0) {
            _sieStatus |= _SIE_VBUS_DETECTED;
          } else {
            _sieStatus &= ~_SIE_VBUS_DETECTED;
          }
        }
        break;
      case _SIE_STATUS:
        _sieStatus &= ~(rawWriteValue & _SIE_WRITECLEAR_MASK);
        if ((rawWriteValue & _SIE_BUS_RESET) != 0) {
          if (!_hostMode) {
            onResetReceived?.call();
          }
          _sieStatus &= ~(_SIE_LINE_STATE_MASK << _SIE_LINE_STATE_SHIFT);
          _sieStatus |=
              (_SIELineState.J << _SIE_LINE_STATE_SHIFT) | _SIE_CONNECTED;
        }
        _sieStatusUpdated();
        break;
      case _INTE:
        _intEnable = value & 0xfffff;
        _checkInterrupts();
        break;
      case _INTF:
        _intForce = value & 0xfffff;
        _checkInterrupts();
        break;

      default:
        super.writeUint32(offset, value);
    }
  }

  int _readEndpointControlReg(int endpoint, bool out) {
    final controlRegOffset =
        _EP1_IN_CONTROL + 8 * (endpoint - 1) + (out ? 4 : 0);
    return rp2040.usbDPRAMView.getUint32(controlRegOffset, Endian.little);
  }

  int _getEndpointBufferOffset(int endpoint, bool out) {
    if (endpoint == 0) {
      return 0x100;
    }
    return _readEndpointControlReg(endpoint, out) & 0xffc0;
  }

  void DPRAMUpdated(int offset, int value) {
    // Skip device-mode buffer control handling in host mode
    if (_hostMode) {
      return;
    }
    if ((value & _USB_BUF_CTRL_AVAILABLE) != 0 &&
        offset >= _EP0_IN_BUFFER_CONTROL &&
        offset <= _EP15_OUT_BUFFER_CONTROL) {
      final endpoint = (offset - _EP0_IN_BUFFER_CONTROL) >> 3;
      final bufferOut = (offset & 4) != 0 ? true : false;
      var doubleBuffer = false;
      var interrupt = true;
      if (endpoint != 0) {
        final control = _readEndpointControlReg(endpoint, bufferOut);
        doubleBuffer = (control & _USB_CTRL_DOUBLE_BUF) != 0;
        interrupt = (control & _USB_CTRL_INTERRUPT_PER_TRANSFER) != 0;
      }

      if (doubleBuffer &&
          ((value >> _USB_BUF1_SHIFT) & _USB_BUF_CTRL_AVAILABLE) != 0) {
        final bufferLength =
            (value >> _USB_BUF1_SHIFT) & _USB_BUF_CTRL_LEN_MASK;
        final bufferOffset =
            _getEndpointBufferOffset(endpoint, bufferOut) + _USB_BUF1_OFFSET;
        debug(
          'Start USB transfer, endPoint=$endpoint, direction=${bufferOut ? 'out' : 'in'} buffer=${bufferOffset.toRadixString(16)} length=$bufferLength',
        );
        value &= ~(_USB_BUF_CTRL_AVAILABLE << _USB_BUF1_SHIFT);
        rp2040.usbDPRAMView.setUint32(offset, value, Endian.little);
        if (bufferOut) {
          onEndpointRead?.call(endpoint, bufferLength);
        } else {
          value &= ~(_USB_BUF_CTRL_FULL << _USB_BUF1_SHIFT);
          rp2040.usbDPRAMView.setUint32(offset, value, Endian.little);
          final buffer = _slice(
            rp2040.usbDPRAM,
            bufferOffset,
            bufferOffset + bufferLength,
          );
          _indicateBufferReady(endpoint, false);
          _endpointWriteAlarms[endpoint].schedule(
            buffer,
            writeDelayMicroseconds * 1000,
          );
        }
      }

      final bufferLength = value & _USB_BUF_CTRL_LEN_MASK;
      final bufferOffset = _getEndpointBufferOffset(endpoint, bufferOut);
      debug(
        'Start USB transfer, endPoint=$endpoint, direction=${bufferOut ? 'out' : 'in'} buffer=${bufferOffset.toRadixString(16)} length=$bufferLength',
      );
      value &= ~_USB_BUF_CTRL_AVAILABLE;
      rp2040.usbDPRAMView.setUint32(offset, value, Endian.little);
      if (bufferOut) {
        onEndpointRead?.call(endpoint, bufferLength);
      } else {
        value &= ~_USB_BUF_CTRL_FULL;
        rp2040.usbDPRAMView.setUint32(offset, value, Endian.little);
        final buffer = _slice(
          rp2040.usbDPRAM,
          bufferOffset,
          bufferOffset + bufferLength,
        );
        if (interrupt || !doubleBuffer) {
          _indicateBufferReady(endpoint, false);
        }
        _endpointWriteAlarms[endpoint].schedule(
          buffer,
          writeDelayMicroseconds * 1000,
        );
      }
    }
  }

  void endpointReadDone(int endpoint, Uint8List buffer, [double? delay]) {
    delay ??= readDelayMicroseconds;
    _endpointReadAlarms[endpoint].schedule(buffer, delay * 1000);
  }

  void _finishRead(int endpoint, Uint8List buffer) {
    final bufferOffset = _getEndpointBufferOffset(endpoint, true);
    final bufControlReg = _EP0_OUT_BUFFER_CONTROL + endpoint * 8;
    var bufControl = rp2040.usbDPRAMView.getUint32(
      bufControlReg,
      Endian.little,
    );
    final requestedLength = bufControl & _USB_BUF_CTRL_LEN_MASK;
    final newLength = math.min(buffer.length, requestedLength);
    bufControl |= _USB_BUF_CTRL_FULL;
    bufControl =
        (bufControl & ~_USB_BUF_CTRL_LEN_MASK) |
        (newLength & _USB_BUF_CTRL_LEN_MASK);
    rp2040.usbDPRAMView.setUint32(bufControlReg, bufControl, Endian.little);
    rp2040.usbDPRAM.setAll(
      bufferOffset,
      Uint8List.sublistView(buffer, 0, newLength),
    );
    _indicateBufferReady(endpoint, true);
  }

  void _checkInterrupts() {
    rp2040.setInterrupt(IRQ.USBCTRL, intStatus != 0);
  }

  void resetDevice() {
    _resetAlarm.schedule(10000000); // USB reset takes ~10ms
  }

  void sendSetupPacket(Uint8List setupPacket) {
    rp2040.usbDPRAM.setAll(0, setupPacket);
    _sieStatus |= _SIE_SETUP_REC;
    _sieStatusUpdated();
  }

  void _indicateBufferReady(int endpoint, bool out) {
    // endpoint <= 15, so the shift is at most 31 and the result stays in range.
    _buffStatus |= 1 << (endpoint * 2 + (out ? 1 : 0));
    _buffStatusUpdated();
  }

  void _buffStatusUpdated() {
    if (_buffStatus != 0) {
      _intRaw |= _INTR_BUFF_STATUS;
    } else {
      _intRaw &= ~_INTR_BUFF_STATUS;
    }
    _checkInterrupts();
  }

  void _sieStatusUpdated() {
    if (_hostMode) {
      // Host mode interrupt mapping
      const intRegisterMap = [
        (_SIE_TRANS_COMPLETE, _INTR_TRANS_COMPLETE),
        (_SIE_STALL_REC, _INTR_STALL),
        (_SIE_CRC_ERROR, _INTR_ERROR_CRC),
        (_SIE_BIT_STUFF_ERROR, _INTR_ERROR_BIT_STUFF),
        (_SIE_RX_OVERFLOW, _INTR_ERROR_RX_OVERFLOW),
        (_SIE_RX_TIMEOUT, _INTR_ERROR_RX_TIMEOUT),
        (_SIE_DATA_SEQ_ERROR, _INTR_ERROR_DATA_SEQ),
      ];
      for (final (sieBit, intRawBit) in intRegisterMap) {
        if ((_sieStatus & sieBit) != 0) {
          _intRaw |= intRawBit;
        } else {
          _intRaw &= ~intRawBit;
        }
      }
    } else {
      // Device mode interrupt mapping
      const intRegisterMap = [
        (_SIE_SETUP_REC, _INTR_SETUP_REQ),
        (_SIE_RESUME, _INTR_DEV_RESUME_FROM_HOST),
        (_SIE_SUSPENDED, _INTR_DEV_SUSPEND),
        (_SIE_CONNECTED, _INTR_DEV_CONN_DIS),
        (_SIE_BUS_RESET, _INTR_BUS_RESET),
        (_SIE_VBUS_DETECTED, _INTR_VBUS_DETECT),
        (_SIE_STALL_REC, _INTR_STALL),
        (_SIE_CRC_ERROR, _INTR_ERROR_CRC),
        (_SIE_BIT_STUFF_ERROR, _INTR_ERROR_BIT_STUFF),
        (_SIE_RX_OVERFLOW, _INTR_ERROR_RX_OVERFLOW),
        (_SIE_RX_TIMEOUT, _INTR_ERROR_RX_TIMEOUT),
        (_SIE_DATA_SEQ_ERROR, _INTR_ERROR_DATA_SEQ),
      ];
      for (final (sieBit, intRawBit) in intRegisterMap) {
        if ((_sieStatus & sieBit) != 0) {
          _intRaw |= intRawBit;
        } else {
          _intRaw &= ~intRawBit;
        }
      }
    }
    _checkInterrupts();
  }

  // ============ Host Mode Methods ============

  /// Connect a simulated USB device to the host controller.
  void connectDevice(USBDevice device) {
    _connectedDevice = device;
    if (_hostMode && (_mainCtrl & _CONTROLLER_EN) != 0) {
      _onDeviceConnected();
    }
  }

  /// Disconnect the simulated USB device from the host controller.
  void disconnectDevice() {
    if (_connectedDevice != null && _hostMode) {
      _connectedDevice = null;
      // Clear speed bits to indicate disconnection
      _sieStatus &= ~(0x3 << 8); // Clear speed bits
      _intRaw |= _INTR_HOST_CONN_DIS;
      _checkInterrupts();
    }
    _connectedDevice = null;
  }

  void _onDeviceConnected() {
    // Set full-speed device connected (value 2 in speed field, bits 9:8)
    _sieStatus &= ~(0x3 << 8);
    _sieStatus |= _SIE_SPEED_FS_VALUE << 8;
    _intRaw |= _INTR_HOST_CONN_DIS;
    _checkInterrupts();
    debug('USB device connected (full-speed)');
  }

  void _handleSieCtrlWrite(int value) {
    _sieCtrl = value;

    // Handle SOF enable/disable
    if ((value & _SIE_CTRL_SOF_EN) != 0 && !_sofEnabled) {
      _sofEnabled = true;
      _scheduleSofPacket();
      debug('SOF generation enabled');
    } else if ((value & _SIE_CTRL_SOF_EN) == 0 && _sofEnabled) {
      _sofEnabled = false;
      debug('SOF generation disabled');
    }

    // Handle bus reset
    if ((value & _SIE_CTRL_RESET_BUS) != 0) {
      debug('USB bus reset initiated');
      if (_connectedDevice != null) {
        _connectedDevice!.onReset();
      }
      _controlDataPid = 1; // Reset data toggle
    }

    // Handle start transaction
    if ((value & _SIE_CTRL_START_TRANS) != 0) {
      _startHostTransaction();
    }
  }

  void _scheduleSofPacket() {
    if (_sofEnabled) {
      // SOF every 1ms = 1,000,000 ns
      _sofAlarm.schedule(1000000);
    }
  }

  void _generateSOF() {
    _sofFrameNumber = (_sofFrameNumber + 1) & 0x7ff;
    _intRaw |= _INTR_HOST_SOF;
    _checkInterrupts();

    // Poll interrupt endpoints
    _pollInterruptEndpoints();

    // Schedule next SOF
    _scheduleSofPacket();
  }

  void _pollInterruptEndpoints() {
    // Debug: log if any interrupt endpoints are enabled
    if (_intEpCtrl != 0 && _sofFrameNumber % 100 == 0) {
      debug(
        'INT_EP poll: intEpCtrl=0x${_intEpCtrl.toRadixString(16)} sofFrame=$_sofFrameNumber',
      );
    }
    // Check each enabled interrupt endpoint
    for (var i = 0; i < _USB_HOST_INTERRUPT_ENDPOINTS; i++) {
      final epCtrlBit = 1 << (i + 1);
      if ((_intEpCtrl & epCtrlBit) == 0) continue;

      final addrEndp = _intEpAddrCtrl[i];
      final devAddr = addrEndp & 0x7f;
      final epNum = (addrEndp >> 16) & 0xf;
      final isOut = (addrEndp & (1 << 25)) != 0; // INTEP_DIR bit

      // Debug: log endpoint config
      if (_sofFrameNumber % 500 == 0) {
        debug(
          'INT_EP[$i]: addrEndp=0x${addrEndp.toRadixString(16)} devAddr=$devAddr epNum=$epNum connectedAddr=${_connectedDevice?.address}',
        );
      }

      final connectedDevice = _connectedDevice;
      if (connectedDevice == null || connectedDevice.address != devAddr) {
        continue;
      }

      // Get the endpoint control register for interval checking
      final epCtrlOffset = _HOST_INT_EP_CTRL_BASE + i * 8;
      final epCtrl = rp2040.usbDPRAMView.getUint32(epCtrlOffset, Endian.little);
      final interval =
          ((epCtrl >> _EP_CTRL_HOST_INTERRUPT_INTERVAL_LSB) & 0x1ff) + 1;

      // Check if it's time to poll (simplified: poll every SOF for now)
      if (_sofFrameNumber % interval != 0) continue;

      // Get buffer control
      final bufCtrlOffset = _HOST_INT_EP_BUF_CTRL_BASE + i * 8;
      final bufCtrl = rp2040.usbDPRAMView.getUint32(
        bufCtrlOffset,
        Endian.little,
      );

      // Debug: log buffer status
      if (_sofFrameNumber % 500 == 0) {
        debug(
          'INT_EP[$i]: bufCtrl=0x${bufCtrl.toRadixString(16)} available=${(bufCtrl & _USB_BUF_CTRL_AVAILABLE) != 0}',
        );
      }

      // Only poll if buffer is available
      if ((bufCtrl & _USB_BUF_CTRL_AVAILABLE) == 0) continue;

      // For IN endpoints, request data from device
      if (!isOut) {
        final epAddr = 0x80 | epNum; // IN endpoint
        final result = connectedDevice.handleDataIn(epAddr);

        final data = result.data;
        if (result.status == USBTransferStatus.ack && data != null) {
          // Write data to the interrupt endpoint buffer
          final bufferOffset = epCtrl & 0xffc0;
          rp2040.usbDPRAM.setAll(bufferOffset, data);

          // Update buffer control
          var newBufCtrl = bufCtrl & ~_USB_BUF_CTRL_AVAILABLE;
          newBufCtrl |= _USB_BUF_CTRL_FULL;
          newBufCtrl =
              (newBufCtrl & ~_USB_BUF_CTRL_LEN_MASK) |
              (data.length & _USB_BUF_CTRL_LEN_MASK);
          rp2040.usbDPRAMView.setUint32(
            bufCtrlOffset,
            newBufCtrl,
            Endian.little,
          );

          // Set buffer status for this interrupt endpoint
          // Interrupt EPs use bits 2+ in buff_status (bit 0 is epx IN, bit 1 is epx OUT)
          _buffStatus |= 1 << ((i + 1) * 2);
          _buffStatusUpdated();
        }
      }
    }
  }

  void _startHostTransaction() {
    if (!_hostMode) return;

    final devAddr = _devAddrCtrl & 0x7f;
    final epNum = (_devAddrCtrl >> 16) & 0xf;

    debug(
      'Host transaction: dev=$devAddr ep=$epNum sieCtrl=0x${_sieCtrl.toRadixString(16)}',
    );

    if (_connectedDevice == null) {
      // No device connected - timeout
      _sieStatus |= _SIE_RX_TIMEOUT;
      _sieStatusUpdated();
      return;
    }

    // Determine transaction type
    if ((_sieCtrl & _SIE_CTRL_SEND_SETUP) != 0) {
      _handleSetupTransaction(devAddr);
    } else if ((_sieCtrl & _SIE_CTRL_RECEIVE_DATA) != 0) {
      _handleInTransaction(devAddr, epNum);
    } else if ((_sieCtrl & _SIE_CTRL_SEND_DATA) != 0) {
      _handleOutTransaction(devAddr, epNum);
    }
  }

  void _handleSetupTransaction(int devAddr) {
    // Read setup packet from DPRAM
    final setupPacket = rp2040.usbDPRAM.sublist(
      _HOST_SETUP_PACKET,
      _HOST_SETUP_PACKET + 8,
    );
    final setup = parseSetupPacket(setupPacket);

    debug(
      'SETUP: bmRequestType=0x${setup.bmRequestType.toRadixString(16)} bRequest=${setup.bRequest} wValue=0x${setup.wValue.toRadixString(16)} wIndex=${setup.wIndex} wLength=${setup.wLength}',
    );

    // Forward to device
    final result = _connectedDevice!.handleSetupPacket(setupPacket);

    // Handle SET_ADDRESS specially
    if (setup.bRequest == StandardRequest.SetAddress && setup.type == 0) {
      final newAddr = setup.wValue & 0x7f;
      _connectedDevice!.address = newAddr;
      _connectedDevice!.onAddressAssigned(newAddr);
      debug('Device address set to $newAddr');
    }

    // Store response data for subsequent IN transaction
    if (setup.direction == 'in' && result.data != null) {
      _pendingSetupResponse = result.data;
      _expectingStatusPhase = false;
    } else {
      _pendingSetupResponse = null;
      // Control OUT transfer - next IN will be status phase (zero-length ACK)
      _expectingStatusPhase = true;
    }

    // Reset data toggle for data phase
    _controlDataPid = 1;

    // SETUP always gets ACK (or STALL if error, but we handle that later)
    _sieStatus |= _SIE_ACK_REC;

    // Schedule transaction completion
    _hostTransactionAlarm.schedule(hostTransactionDelayMicroseconds * 1000);
  }

  void _handleInTransaction(int devAddr, int epNum) {
    final epAddr = 0x80 | epNum;
    USBTransferResult result;

    if (epNum == 0 && _expectingStatusPhase) {
      // Control OUT status phase - return zero-length ACK
      result = USBTransferResult(
        status: USBTransferStatus.ack,
        data: Uint8List(0),
      );
      _expectingStatusPhase = false;
      debug('Control OUT status phase (ZLP)');
    } else if (epNum == 0 && _pendingSetupResponse != null) {
      // Control IN - return pending setup response
      result = USBTransferResult(
        status: USBTransferStatus.ack,
        data: _pendingSetupResponse,
      );

      // Get requested length from buffer control
      final bufCtrl = rp2040.usbDPRAMView.getUint32(
        _HOST_EPX_BUF_CTRL,
        Endian.little,
      );
      final maxLen = bufCtrl & _USB_BUF_CTRL_LEN_MASK;

      // Trim data to requested length
      if (result.data != null && result.data!.length > maxLen) {
        result.data = result.data!.sublist(0, maxLen);
      }

      // Clear pending response if all data sent
      if (result.data == null || result.data!.length <= maxLen) {
        _pendingSetupResponse = null;
      }
    } else {
      result = _connectedDevice!.handleDataIn(epAddr);
    }

    final data = result.data;
    if (result.status == USBTransferStatus.ack && data != null) {
      // Write data to EPX data buffer
      rp2040.usbDPRAM.setAll(_HOST_EPX_DATA, data);

      // Update buffer control with actual length and FULL flag
      var bufCtrl = rp2040.usbDPRAMView.getUint32(
        _HOST_EPX_BUF_CTRL,
        Endian.little,
      );
      bufCtrl &= ~_USB_BUF_CTRL_LEN_MASK;
      bufCtrl |= data.length & _USB_BUF_CTRL_LEN_MASK;
      bufCtrl |= _USB_BUF_CTRL_FULL;
      bufCtrl &= ~_USB_BUF_CTRL_AVAILABLE;

      // Set DATA1 PID for control transfers
      if (_controlDataPid != 0) {
        bufCtrl |= _USB_BUF_CTRL_DATA1_PID;
      } else {
        bufCtrl &= ~_USB_BUF_CTRL_DATA1_PID;
      }
      _controlDataPid ^= 1;

      rp2040.usbDPRAMView.setUint32(_HOST_EPX_BUF_CTRL, bufCtrl, Endian.little);

      // Set buffer status
      _buffStatus |= 1; // Bit 0 for EPX
      _buffStatusUpdated();

      _sieStatus |= _SIE_ACK_REC;
    } else if (result.status == USBTransferStatus.nak) {
      _sieStatus |= _SIE_NAK_REC;
    } else if (result.status == USBTransferStatus.stall) {
      _sieStatus |= _SIE_STALL_REC;
    }

    _hostTransactionAlarm.schedule(hostTransactionDelayMicroseconds * 1000);
  }

  void _handleOutTransaction(int devAddr, int epNum) {
    final epAddr = epNum; // OUT endpoint

    // Read data from EPX data buffer
    final bufCtrl = rp2040.usbDPRAMView.getUint32(
      _HOST_EPX_BUF_CTRL,
      Endian.little,
    );
    final dataLen = bufCtrl & _USB_BUF_CTRL_LEN_MASK;
    final data = _slice(
      rp2040.usbDPRAM,
      _HOST_EPX_DATA,
      _HOST_EPX_DATA + dataLen,
    );

    USBTransferResult result;
    if (epNum == 0 && dataLen == 0) {
      // Zero-length status phase for control transfer
      result = USBTransferResult(status: USBTransferStatus.ack);
    } else {
      result = _connectedDevice!.handleDataOut(epAddr, data);
    }

    // Update buffer control
    var newBufCtrl = bufCtrl;
    newBufCtrl &= ~_USB_BUF_CTRL_AVAILABLE;

    // Toggle DATA PID
    if (_controlDataPid != 0) {
      newBufCtrl |= _USB_BUF_CTRL_DATA1_PID;
    } else {
      newBufCtrl &= ~_USB_BUF_CTRL_DATA1_PID;
    }
    _controlDataPid ^= 1;

    rp2040.usbDPRAMView.setUint32(
      _HOST_EPX_BUF_CTRL,
      newBufCtrl,
      Endian.little,
    );

    if (result.status == USBTransferStatus.ack) {
      _sieStatus |= _SIE_ACK_REC;
      _buffStatus |= 1; // Bit 0 for EPX
      _buffStatusUpdated();
    } else if (result.status == USBTransferStatus.nak) {
      _sieStatus |= _SIE_NAK_REC;
    } else if (result.status == USBTransferStatus.stall) {
      _sieStatus |= _SIE_STALL_REC;
    }

    _hostTransactionAlarm.schedule(hostTransactionDelayMicroseconds * 1000);
  }

  void _completeHostTransaction() {
    // Clear START_TRANS bit
    _sieCtrl &= ~_SIE_CTRL_START_TRANS;

    // Set transaction complete
    _sieStatus |= _SIE_TRANS_COMPLETE;
    _sieStatusUpdated();

    debug('Host transaction complete');
  }
}
