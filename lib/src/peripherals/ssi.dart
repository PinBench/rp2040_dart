// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

// ignore_for_file: unused_element

import 'peripheral.dart';

/* See RP2040 datasheet sect 4.10.13 */
const int _SSI_CTRLR0 = 0x00000000;
const int _SSI_CTRLR1 = 0x00000004;
const int _SSI_SSIENR = 0x00000008;
const int _SSI_MWCR = 0x0000000c;
const int _SSI_SER = 0x00000010;
const int _SSI_BAUDR = 0x00000014;
const int _SSI_TXFTLR = 0x00000018;
const int _SSI_RXFTLR = 0x0000001c;
const int _SSI_TXFLR = 0x00000020;
const int _SSI_RXFLR = 0x00000024;
const int _SSI_SR = 0x00000028;
const int _SSI_SR_TFNF_BITS = 0x00000002;
const int _SSI_SR_TFE_BITS = 0x00000004;
const int _SSI_SR_RFNE_BITS = 0x00000008;
const int _SSI_IMR = 0x0000002c;
const int _SSI_ISR = 0x00000030;
const int _SSI_RISR = 0x00000034;
const int _SSI_TXOICR = 0x00000038;
const int _SSI_RXOICR = 0x0000003c;
const int _SSI_RXUICR = 0x00000040;
const int _SSI_MSTICR = 0x00000044;
const int _SSI_ICR = 0x00000048;
const int _SSI_DMACR = 0x0000004c;
const int _SSI_DMATDLR = 0x00000050;
const int _SSI_DMARDLR = 0x00000054;

/// Identification register
const int _SSI_IDR = 0x00000058;
const int _SSI_VERSION_ID = 0x0000005c;
const int _SSI_DR0 = 0x00000060;
const int _SSI_RX_SAMPLE_DLY = 0x000000f0;
const int _SSI_SPI_CTRL_R0 = 0x000000f4;
const int _SSI_TXD_DRIVE_EDGE = 0x000000f8;

const int _CMD_READ_STATUS = 0x05;

class RPSSI extends BasePeripheral implements Peripheral {
  int _dr0 = 0;
  int _txflr = 0;
  int _rxflr = 0;
  int _baudr = 0;
  int _crtlr0 = 0;
  int _crtlr1 = 0;
  int _ssienr = 0;
  int _spictlr0 = 0;
  int _rxsampldly = 0;
  int _txddriveedge = 0;

  RPSSI(super.rp2040, super.name);

  @override
  int readUint32(int offset) {
    switch (offset) {
      case _SSI_TXFLR:
        return _txflr;
      case _SSI_RXFLR:
        return _rxflr;
      case _SSI_CTRLR0:
        return _crtlr0; /*  & 0x017FFFFF = b23,b25..31 reserved */
      case _SSI_CTRLR1:
        return _crtlr1;
      case _SSI_SSIENR:
        return _ssienr;
      case _SSI_BAUDR:
        return _baudr;
      case _SSI_SR:
        return _SSI_SR_TFE_BITS | _SSI_SR_RFNE_BITS | _SSI_SR_TFNF_BITS;
      case _SSI_IDR:
        return 0x51535049;
      case _SSI_VERSION_ID:
        return 0x3430312a;
      case _SSI_RX_SAMPLE_DLY:
        return _rxsampldly;
      case _SSI_TXD_DRIVE_EDGE:
        return _txddriveedge;
      case _SSI_SPI_CTRL_R0:
        return _spictlr0; /* b6,7,10,19..23 reserved */
      case _SSI_DR0:
        return _dr0;
    }
    return super.readUint32(offset);
  }

  @override
  void writeUint32(int offset, int value) {
    switch (offset) {
      case _SSI_TXFLR:
        _txflr = value;
        return;
      case _SSI_RXFLR:
        _rxflr = value;
        return;
      case _SSI_CTRLR0:
        _crtlr0 = value; /*  & 0x017FFFFF = b23,b25..31 reserved */
        return;
      case _SSI_CTRLR1:
        _crtlr1 = value;
        return;
      case _SSI_SSIENR:
        _ssienr = value;
        return;
      case _SSI_BAUDR:
        _baudr = value;
        return;
      case _SSI_RX_SAMPLE_DLY:
        _rxsampldly = value & 0xff;
        return;
      case _SSI_TXD_DRIVE_EDGE:
        _txddriveedge = value & 0xff;
        return;
      case _SSI_SPI_CTRL_R0:
        _spictlr0 = value;
        return;
      case _SSI_DR0:
        if (value == _CMD_READ_STATUS) {
          _dr0 = 0; // tell stage2 that we completed a write
        }
        return;
      default:
        super.writeUint32(offset, value);
    }
  }
}
