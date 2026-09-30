// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

// The register map is kept whole, as in rp2040js, including the constants
// this file does not use yet.
// ignore_for_file: unused_element

import 'peripheral.dart';

const _CLK_GPOUT0_CTRL = 0x00;
const _CLK_GPOUT0_DIV = 0x04;
const _CLK_GPOUT0_SELECTED = 0x8;
const _CLK_GPOUT1_CTRL = 0x0c;
const _CLK_GPOUT1_DIV = 0x10;
const _CLK_GPOUT1_SELECTED = 0x14;
const _CLK_GPOUT2_CTRL = 0x18;
const _CLK_GPOUT2_DIV = 0x01c;
const _CLK_GPOUT2_SELECTED = 0x20;
const _CLK_GPOUT3_CTRL = 0x24;
const _CLK_GPOUT3_DIV = 0x28;
const _CLK_GPOUT3_SELECTED = 0x2c;
const _CLK_REF_CTRL = 0x30;
const _CLK_REF_DIV = 0x34;
const _CLK_REF_SELECTED = 0x38;
const _CLK_SYS_CTRL = 0x3c;
const _CLK_SYS_DIV = 0x40;
const _CLK_SYS_SELECTED = 0x44;
const _CLK_PERI_CTRL = 0x48;
const _CLK_PERI_DIV = 0x4c;
const _CLK_PERI_SELECTED = 0x50;
const _CLK_USB_CTRL = 0x54;
const _CLK_USB_DIV = 0x58;
const _CLK_USB_SELECTED = 0x5c;
const _CLK_ADC_CTRL = 0x60;
const _CLK_ADC_DIV = 0x64;
const _CLK_ADC_SELECTED = 0x68;
const _CLK_RTC_CTRL = 0x6c;
const _CLK_RTC_DIV = 0x70;
const _CLK_RTC_SELECTED = 0x74;
const _CLK_SYS_RESUS_CTRL = 0x78;
const _CLK_SYS_RESUS_STATUS = 0x7c;

// CLK_REF_CTRL
const _CLK_REF_CTRL_SRC_MASK = 0x3;
const _CLK_REF_CTRL_SRC_ROSC = 0x0;
const _CLK_REF_CTRL_SRC_AUX = 0x1;
const _CLK_REF_CTRL_SRC_XOSC = 0x2;
const _CLK_REF_CTRL_AUXSRC_SHIFT = 5;
const _CLK_REF_CTRL_AUXSRC_MASK = 0x3;
const _CLK_REF_CTRL_AUXSRC_PLL_USB = 0x0;

// CLK_REF_DIV has no fractional part, only INT (bits 9:8)
const _CLK_REF_DIV_INT_BITS = 0x300;

// CLK_SYS_CTRL
const _CLK_SYS_CTRL_SRC_MASK = 0x1;
const _CLK_SYS_CTRL_SRC_REF = 0x0;
const _CLK_SYS_CTRL_AUXSRC_SHIFT = 5;
const _CLK_SYS_CTRL_AUXSRC_MASK = 0x7;
const _CLK_SYS_CTRL_AUXSRC_PLL_SYS = 0x0;
const _CLK_SYS_CTRL_AUXSRC_PLL_USB = 0x1;
const _CLK_SYS_CTRL_AUXSRC_ROSC = 0x2;
const _CLK_SYS_CTRL_AUXSRC_XOSC = 0x3;

// CLK_PERI_CTRL. clk_peri has no SRC mux and no divider: it is driven straight from AUXSRC,
// which uses its own encoding (not the CLK_SYS one).
const _CLK_PERI_CTRL_ENABLE = 1 << 11;
const _CLK_PERI_CTRL_KILL = 1 << 10;
const _CLK_PERI_CTRL_AUXSRC_SHIFT = 5;
const _CLK_PERI_CTRL_AUXSRC_MASK = 0x7;
const _CLK_PERI_CTRL_AUXSRC_CLK_SYS = 0x0;
const _CLK_PERI_CTRL_AUXSRC_PLL_SYS = 0x1;
const _CLK_PERI_CTRL_AUXSRC_PLL_USB = 0x2;
const _CLK_PERI_CTRL_AUXSRC_ROSC = 0x3;
const _CLK_PERI_CTRL_AUXSRC_XOSC = 0x4;

// CLK_x_DIV: 24.8 fixed point (INT bits 31:8, FRAC bits 7:0)
const _CLK_DIV_INT_SHIFT = 8;
const _CLK_DIV_FRAC_MASK = 0xff;

/// Decodes a CLK_x_DIV register value. INT = 0 means divide by 2^16.
double _clockDivisor(int div) {
  final int = div >>> _CLK_DIV_INT_SHIFT;
  return int != 0 ? int + (div & _CLK_DIV_FRAC_MASK) / 256 : 0x10000;
}

class RPClocks extends BasePeripheral implements Peripheral {
  int gpout0Ctrl = 0;
  int gpout0Div = 0x100;
  int gpout1Ctrl = 0;
  int gpout1Div = 0x100;
  int gpout2Ctrl = 0;
  int gpout2Div = 0x100;
  int gpout3Ctrl = 0;
  int gpout3Div = 0x100;
  int refCtrl = 0;
  int refDiv = 0x100;
  int periCtrl = 0;
  int periDiv = 0x100;
  int usbCtrl = 0;
  int usbDiv = 0x100;
  int sysCtrl = 0;
  int sysDiv = 0x100;
  int adcCtrl = 0;
  int adcDiv = 0x100;
  int rtcCtrl = 0;
  int rtcDiv = 0x100;
  RPClocks(super.rp2040, super.name);

  /// clk_ref frequency, in Hz. GPIN0/GPIN1 are not modelled and yield 0.
  double get refFreq =>
      _refSourceFreq / _clockDivisor(refDiv & _CLK_REF_DIV_INT_BITS);

  /// clk_sys frequency, in Hz. GPIN0/GPIN1 are not modelled and yield 0.
  double get sysFreq => _sysSourceFreq / _clockDivisor(sysDiv);

  /// clk_peri frequency, in Hz. Feeds the UART and SPI baud rate generators. Returns 0 while
  /// the clock generator is stopped, and for the GPIN0/GPIN1 sources we do not model.
  double get periFreq {
    final rp2040 = this.rp2040;
    if (periCtrl & _CLK_PERI_CTRL_ENABLE == 0 ||
        periCtrl & _CLK_PERI_CTRL_KILL != 0) {
      return 0;
    }
    switch ((periCtrl >>> _CLK_PERI_CTRL_AUXSRC_SHIFT) &
        _CLK_PERI_CTRL_AUXSRC_MASK) {
      case _CLK_PERI_CTRL_AUXSRC_CLK_SYS:
        return sysFreq;
      case _CLK_PERI_CTRL_AUXSRC_PLL_SYS:
        return rp2040.pllSys.frequency;
      case _CLK_PERI_CTRL_AUXSRC_PLL_USB:
        return rp2040.pllUsb.frequency;
      case _CLK_PERI_CTRL_AUXSRC_ROSC:
        return rp2040.roscFreq;
      case _CLK_PERI_CTRL_AUXSRC_XOSC:
        return rp2040.xoscFreq;
      default:
        return 0;
    }
  }

  double get _refSourceFreq {
    final rp2040 = this.rp2040;
    switch (refCtrl & _CLK_REF_CTRL_SRC_MASK) {
      case _CLK_REF_CTRL_SRC_ROSC:
        return rp2040.roscFreq;
      case _CLK_REF_CTRL_SRC_XOSC:
        return rp2040.xoscFreq;
      case _CLK_REF_CTRL_SRC_AUX:
        {
          final auxsrc =
              (refCtrl >>> _CLK_REF_CTRL_AUXSRC_SHIFT) &
              _CLK_REF_CTRL_AUXSRC_MASK;
          return auxsrc == _CLK_REF_CTRL_AUXSRC_PLL_USB
              ? rp2040.pllUsb.frequency
              : 0;
        }
      default:
        return 0;
    }
  }

  double get _sysSourceFreq {
    final rp2040 = this.rp2040;
    if ((sysCtrl & _CLK_SYS_CTRL_SRC_MASK) == _CLK_SYS_CTRL_SRC_REF) {
      return refFreq;
    }
    switch ((sysCtrl >>> _CLK_SYS_CTRL_AUXSRC_SHIFT) &
        _CLK_SYS_CTRL_AUXSRC_MASK) {
      case _CLK_SYS_CTRL_AUXSRC_PLL_SYS:
        return rp2040.pllSys.frequency;
      case _CLK_SYS_CTRL_AUXSRC_PLL_USB:
        return rp2040.pllUsb.frequency;
      case _CLK_SYS_CTRL_AUXSRC_ROSC:
        return rp2040.roscFreq;
      case _CLK_SYS_CTRL_AUXSRC_XOSC:
        return rp2040.xoscFreq;
      default:
        return 0;
    }
  }

  @override
  int readUint32(int offset) {
    switch (offset) {
      case _CLK_GPOUT0_CTRL:
        return gpout0Ctrl & 0x131de0; // 0b100110001110111100000
      case _CLK_GPOUT0_DIV:
        return gpout0Div;
      case _CLK_GPOUT0_SELECTED:
        return 1;
      case _CLK_GPOUT1_CTRL:
        return gpout1Ctrl & 0x131de0; // 0b100110001110111100000
      case _CLK_GPOUT1_DIV:
        return gpout1Div;
      case _CLK_GPOUT1_SELECTED:
        return 1;
      case _CLK_GPOUT2_CTRL:
        return gpout2Ctrl & 0x131de0; // 0b100110001110111100000
      case _CLK_GPOUT2_DIV:
        return gpout2Div;
      case _CLK_GPOUT2_SELECTED:
        return 1;
      case _CLK_GPOUT3_CTRL:
        return gpout3Ctrl & 0x131de0; // 0b100110001110111100000
      case _CLK_GPOUT3_DIV:
        return gpout3Div;
      case _CLK_GPOUT3_SELECTED:
        return 1;
      case _CLK_REF_CTRL:
        return refCtrl & 0x063; // 0b000001100011
      case _CLK_REF_DIV:
        return refDiv & 0x30; // b8..9 = int divisor. no frac divisor present
      case _CLK_REF_SELECTED:
        return 1 << (refCtrl & 0x03);
      case _CLK_SYS_CTRL:
        return sysCtrl & 0x0e1; // 0b000011100001
      case _CLK_SYS_DIV:
        return sysDiv;
      case _CLK_SYS_SELECTED:
        return 1 << (sysCtrl & 0x01);
      case _CLK_PERI_CTRL:
        return periCtrl & 0xce0; // 0b110011100000
      case _CLK_PERI_DIV:
        return periDiv;
      case _CLK_PERI_SELECTED:
        return 1;
      case _CLK_USB_CTRL:
        return usbCtrl & 0x130ce0; // 0b100110000110011100000
      case _CLK_USB_DIV:
        return usbDiv;
      case _CLK_USB_SELECTED:
        return 1;
      case _CLK_ADC_CTRL:
        return adcCtrl & 0x130ce0; // 0b100110000110011100000
      case _CLK_ADC_DIV:
        return adcDiv & 0x30;
      case _CLK_ADC_SELECTED:
        return 1;
      case _CLK_RTC_CTRL:
        return rtcCtrl & 0x130ce0; // 0b100110000110011100000
      case _CLK_RTC_DIV:
        return rtcDiv & 0x30;
      case _CLK_RTC_SELECTED:
        return 1;
      case _CLK_SYS_RESUS_CTRL:
        return 0xff;
      case _CLK_SYS_RESUS_STATUS:
        return 0; /* clock resus not implemented */
    }
    return super.readUint32(offset);
  }

  @override
  void writeUint32(int offset, int value) {
    switch (offset) {
      case _CLK_GPOUT0_CTRL:
        gpout0Ctrl = value;
        break;
      case _CLK_GPOUT0_DIV:
        gpout0Div = value;
        break;
      case _CLK_GPOUT1_CTRL:
        gpout1Ctrl = value;
        break;
      case _CLK_GPOUT1_DIV:
        gpout1Div = value;
        break;
      case _CLK_GPOUT2_CTRL:
        gpout2Ctrl = value;
        break;
      case _CLK_GPOUT2_DIV:
        gpout2Div = value;
        break;
      case _CLK_GPOUT3_CTRL:
        gpout3Ctrl = value;
        break;
      case _CLK_GPOUT3_DIV:
        gpout3Div = value;
        break;
      case _CLK_REF_CTRL:
        refCtrl = value;
        rp2040.updateClocks();
        break;
      case _CLK_REF_DIV:
        refDiv = value;
        rp2040.updateClocks();
        break;
      case _CLK_SYS_CTRL:
        sysCtrl = value;
        rp2040.updateClocks();
        break;
      case _CLK_SYS_DIV:
        sysDiv = value;
        rp2040.updateClocks();
        break;
      case _CLK_PERI_CTRL:
        periCtrl = value;
        rp2040.updateClocks();
        break;
      case _CLK_PERI_DIV:
        periDiv = value;
        break;
      case _CLK_USB_CTRL:
        usbCtrl = value;
        break;
      case _CLK_USB_DIV:
        usbDiv = value;
        break;
      case _CLK_ADC_CTRL:
        adcCtrl = value;
        break;
      case _CLK_ADC_DIV:
        adcDiv = value;
        break;
      case _CLK_RTC_CTRL:
        rtcCtrl = value;
        break;
      case _CLK_RTC_DIV:
        rtcDiv = value;
        break;
      case _CLK_SYS_RESUS_CTRL:
        return; /* clock resus not implemented */
      default:
        super.writeUint32(offset, value);
        break;
    }
  }
}
