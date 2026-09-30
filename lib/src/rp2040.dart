// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'dart:typed_data';

import 'clock/clock.dart';
import 'clock/simulation_clock.dart';
import 'cortex_m0_core.dart';
import 'gpio_pin.dart';
import 'irq.dart';
import 'peripherals/adc.dart';
import 'peripherals/busctrl.dart';
import 'peripherals/clocks.dart';
import 'peripherals/dma.dart';
import 'peripherals/i2c.dart';
import 'peripherals/io.dart';
import 'peripherals/pads.dart';
import 'peripherals/peripheral.dart';
import 'peripherals/pio.dart';
import 'peripherals/pll.dart';
import 'peripherals/ppb.dart';
import 'peripherals/psm.dart';
import 'peripherals/pwm.dart';
import 'peripherals/reset.dart';
import 'peripherals/rtc.dart';
import 'peripherals/spi.dart';
import 'peripherals/ssi.dart';
import 'peripherals/syscfg.dart';
import 'peripherals/sysinfo.dart';
import 'peripherals/tbman.dart';
import 'peripherals/timer.dart';
import 'peripherals/uart.dart';
import 'peripherals/usb.dart';
import 'peripherals/watchdog.dart';
import 'peripherals/xosc.dart';
import 'sio.dart';
import 'utils/bit.dart';
import 'utils/logging.dart';

const int FLASH_START_ADDRESS = 0x10000000;
const int FLASH_END_ADDRESS = 0x14000000;
const int RAM_START_ADDRESS = 0x20000000;
const int APB_START_ADDRESS = 0x40000000;
const int DPRAM_START_ADDRESS = 0x50100000;
const int SIO_START_ADDRESS = 0xd0000000;

const String _LOG_NAME = 'RP2040';

/// Notified after clk_sys changes. Listeners that cache a frequency derived from clk_sys
/// (PIO clock dividers, for instance) use this to re-derive it.
typedef ClockListener = void Function(double clkSys, double oldClkSys);

const int _KB = 1024;
const int _MB = 1024 * _KB;
const double _MHz = 1000000;

class RP2040 {
  final Uint32List bootrom = Uint32List(4 * _KB);
  final Uint8List sram;
  final ByteData sramView;
  final Uint8List flash;
  final Uint16List flash16;
  final ByteData flashView;
  final Uint8List usbDPRAM;
  final ByteData usbDPRAMView;

  // Assigned in the constructor body, in rp2040js's declaration order: a Dart
  // field initialiser cannot pass `this` to the peripheral it creates.
  late final CortexM0Core core;

  /* Clocks */
  double clkSys = 125 * _MHz;
  double clkPeri = 125 * _MHz;

  /// Crystal oscillator frequency. 12 MHz on the Raspberry Pi Pico and most other boards.
  double xoscFreq = 12 * _MHz;

  /// Ring oscillator frequency. Varies with voltage/temperature on real silicon.
  double roscFreq = 6.5 * _MHz;

  late final RPPLL pllSys;
  late final RPPLL pllUsb;
  late final RPClocks clocks;

  late final RPPPB ppb;
  late final RPSIO sio;

  late final List<RPUART> uart;
  late final List<RPI2C> i2c;
  late final RPPWM pwm;
  late final RPADC adc;

  late final List<GPIOPin> gpio;

  late final List<GPIOPin> qspi;

  late final RPDMA dma;
  late final List<RPPIO> pio;
  late final RPUSBController usbCtrl;
  late final List<RPSPI> spi;

  Logger logger = ConsoleLogger(LogLevel.Debug, true);

  final Set<ClockListener> _clockListeners = {};

  late final Map<int, Peripheral> peripherals;

  // Debugging
  void Function(int code) onBreak = (code) {
    // TODO: raise HardFault exception
    // console.error('Breakpoint!', code);
  };

  final IClock clock;

  RP2040([IClock? clock])
    : this._(
        clock ?? SimulationClock(),
        Uint8List(264 * _KB),
        Uint8List(16 * _MB),
        Uint8List(4 * _KB),
      );

  RP2040._(this.clock, this.sram, this.flash, this.usbDPRAM)
    : sramView = ByteData.view(sram.buffer),
      flash16 = Uint16List.view(flash.buffer),
      flashView = ByteData.view(flash.buffer),
      usbDPRAMView = ByteData.view(usbDPRAM.buffer) {
    core = CortexM0Core(this);
    pllSys = RPPLL(this, 'PLL_SYS_BASE');
    pllUsb = RPPLL(this, 'PLL_USB_BASE');
    clocks = RPClocks(this, 'CLOCKS_BASE');
    ppb = RPPPB(this, 'PPB');
    sio = RPSIO(this);
    uart = [
      RPUART(
        this,
        'UART0',
        IRQ.UART0,
        const IUARTDMAChannels(
          rx: DREQChannel.DREQ_UART0_RX,
          tx: DREQChannel.DREQ_UART0_TX,
        ),
      ),
      RPUART(
        this,
        'UART1',
        IRQ.UART1,
        const IUARTDMAChannels(
          rx: DREQChannel.DREQ_UART1_RX,
          tx: DREQChannel.DREQ_UART1_TX,
        ),
      ),
    ];
    i2c = [RPI2C(this, 'I2C0', IRQ.I2C0), RPI2C(this, 'I2C1', IRQ.I2C1)];
    pwm = RPPWM(this, 'PWM_BASE');
    adc = RPADC(this, 'ADC');
    gpio = [for (var i = 0; i < 30; i++) GPIOPin(this, i)];
    qspi = [
      GPIOPin(this, 0, 'SCLK'),
      GPIOPin(this, 1, 'SS'),
      GPIOPin(this, 2, 'SD0'),
      GPIOPin(this, 3, 'SD1'),
      GPIOPin(this, 4, 'SD2'),
      GPIOPin(this, 5, 'SD3'),
    ];
    dma = RPDMA(this, 'DMA');
    pio = [
      RPPIO(this, 'PIO0', IRQ.PIO0_IRQ0, 0),
      RPPIO(this, 'PIO1', IRQ.PIO1_IRQ0, 1),
    ];
    usbCtrl = RPUSBController(this, 'USB');
    spi = [
      RPSPI(
        this,
        'SPI0',
        IRQ.SPI0,
        const ISPIDMAChannels(
          rx: DREQChannel.DREQ_SPI0_RX,
          tx: DREQChannel.DREQ_SPI0_TX,
        ),
      ),
      RPSPI(
        this,
        'SPI1',
        IRQ.SPI1,
        const ISPIDMAChannels(
          rx: DREQChannel.DREQ_SPI1_RX,
          tx: DREQChannel.DREQ_SPI1_TX,
        ),
      ),
    ];
    peripherals = {
      0x18000: RPSSI(this, 'SSI'),
      0x40000: RP2040SysInfo(this, 'SYSINFO_BASE'),
      0x40004: RP2040SysCfg(this, 'SYSCFG'),
      0x40008: clocks,
      0x4000c: RPReset(this, 'RESETS_BASE'),
      0x40010: RPPSM(this, 'PSM_BASE'),
      0x40014: RPIO(this, 'IO_BANK0_BASE'),
      0x40018: UnimplementedPeripheral(this, 'IO_QSPI_BASE'),
      0x4001c: RPPADS(this, 'PADS_BANK0_BASE', 'bank0'),
      0x40020: RPPADS(this, 'PADS_QSPI_BASE', 'qspi'),
      0x40024: RPXOSC(this, 'XOSC_BASE'),
      0x40028: pllSys,
      0x4002c: pllUsb,
      0x40030: RPBUSCTRL(this, 'BUSCTRL_BASE'),
      0x40034: uart[0],
      0x40038: uart[1],
      0x4003c: spi[0],
      0x40040: spi[1],
      0x40044: i2c[0],
      0x40048: i2c[1],
      0x4004c: adc,
      0x40050: pwm,
      0x40054: RPTimer(this, 'TIMER_BASE'),
      0x40058: RPWatchdog(this, 'WATCHDOG_BASE'),
      0x4005c: RP2040RTC(this, 'RTC_BASE'),
      0x40060: UnimplementedPeripheral(this, 'ROSC_BASE'),
      0x40064: UnimplementedPeripheral(this, 'VREG_AND_CHIP_RESET_BASE'),
      0x4006c: RPTBMAN(this, 'TBMAN_BASE'),
      0x50000: dma,
      0x50110: usbCtrl,
      0x50200: pio[0],
      0x50300: pio[1],
    };
    reset();
  }

  void loadBootrom(Uint32List bootromData) {
    bootrom.setAll(0, bootromData);
    reset();
  }

  void reset() {
    core.reset();
    pwm.reset();
    flash.fillRange(0, flash.length, 0xff);
  }

  int readUint32(int address) {
    address = u32(address); // round to 32-bits, unsigned
    if (address & 0x3 != 0) {
      logger.error(
        _LOG_NAME,
        'read from address ${address.toRadixString(16)}, which is not 32 bit aligned',
      );
    }

    if (address < bootrom.length * 4) {
      return bootrom[address >> 2];
    } else if (address >= FLASH_START_ADDRESS && address < FLASH_END_ADDRESS) {
      // Flash is mirrored four times:
      // - 0x10000000 XIP
      // - 0x11000000 XIP_NOALLOC
      // - 0x12000000 XIP_NOCACHE
      // - 0x13000000 XIP_NOCACHE_NOALLOC
      final offset = address & 0x00ffffff;
      return flashView.getUint32(offset, Endian.little);
    } else if (address >= RAM_START_ADDRESS &&
        address < RAM_START_ADDRESS + sram.length) {
      return sramView.getUint32(address - RAM_START_ADDRESS, Endian.little);
    } else if (address >= DPRAM_START_ADDRESS &&
        address < DPRAM_START_ADDRESS + usbDPRAM.length) {
      return usbDPRAMView.getUint32(
        address - DPRAM_START_ADDRESS,
        Endian.little,
      );
    } else if (address >>> 12 == 0xe000e) {
      return ppb.readUint32(address & 0xfff);
    } else if (address >= SIO_START_ADDRESS &&
        address < SIO_START_ADDRESS + 0x10000000) {
      return sio.readUint32(address - SIO_START_ADDRESS);
    }

    final peripheral = findPeripheral(address);
    if (peripheral != null) {
      return peripheral.readUint32(address & 0x3fff);
    }

    logger.warn(
      _LOG_NAME,
      'Read from invalid memory address: ${address.toRadixString(16)}',
    );
    return 0xffffffff;
  }

  /// Recomputes `clkSys` and `clkPeri` from the PLL and CLOCKS registers and updates the
  /// peripherals derived from them. Until firmware configures the clock tree, each keeps its default.
  void updateClocks() {
    _updateClkSys();
    _updateClkPeri();
  }

  void _updateClkSys() {
    final clkSys = clocks.sysFreq;
    // 0 means clk_sys is fed from an unmodelled or unconfigured source: keep the last value
    if (clkSys == 0 || clkSys == this.clkSys) {
      return;
    }
    final oldClkSys = this.clkSys;
    this.clkSys = clkSys;
    ppb.systickTimer.frequency = clkSys;
    for (final channel in pwm.channels) {
      channel.timer.frequency = pwm.clockFreq;
    }
    for (final listener in _clockListeners.toList()) {
      listener(clkSys, oldClkSys);
    }
  }

  void _updateClkPeri() {
    final clkPeri = clocks.periFreq;
    // 0 means the clock generator is stopped, or the source is one we do not model
    if (clkPeri == 0 || clkPeri == this.clkPeri) {
      return;
    }
    this.clkPeri = clkPeri;
    for (final uart in this.uart) {
      uart.clkPeriChanged();
    }
  }

  /// Registers a listener to be notified whenever clk_sys changes. Returns an unsubscribe function.
  bool Function() addClockListener(ClockListener listener) {
    _clockListeners.add(listener);
    return () => _clockListeners.remove(listener);
  }

  Peripheral? findPeripheral(int address) =>
      peripherals[(u32(address) >>> 14) << 2];

  /// We assume the address is 16-bit aligned
  int readUint16(int address) {
    address = u32(address);
    if (address >= FLASH_START_ADDRESS &&
        address < FLASH_START_ADDRESS + flash.length) {
      return flashView.getUint16(address - FLASH_START_ADDRESS, Endian.little);
    } else if (address >= RAM_START_ADDRESS &&
        address < RAM_START_ADDRESS + sram.length) {
      return sramView.getUint16(address - RAM_START_ADDRESS, Endian.little);
    }

    final value = readUint32(address & 0xfffffffc);
    return address & 0x2 != 0 ? (value & 0xffff0000) >>> 16 : value & 0xffff;
  }

  int readUint8(int address) {
    address = u32(address);
    if (address >= FLASH_START_ADDRESS &&
        address < FLASH_START_ADDRESS + flash.length) {
      return flash[address - FLASH_START_ADDRESS];
    } else if (address >= RAM_START_ADDRESS &&
        address < RAM_START_ADDRESS + sram.length) {
      return sram[address - RAM_START_ADDRESS];
    }

    final value = readUint16(address & 0xfffffffe);
    return address & 0x1 != 0 ? (value & 0xff00) >>> 8 : value & 0xff;
  }

  void writeUint32(int address, int value) {
    address = u32(address);
    value = u32(value);
    final peripheral = findPeripheral(address);
    if (peripheral != null) {
      final atomicType = (address & 0x3000) >> 12;
      final offset = address & 0xfff;
      peripheral.writeUint32Atomic(offset, value, atomicType);
    } else if (address < bootrom.length * 4) {
      bootrom[address >> 2] = value;
    } else if (address >= FLASH_START_ADDRESS &&
        address < FLASH_START_ADDRESS + flash.length) {
      flashView.setUint32(address - FLASH_START_ADDRESS, value, Endian.little);
    } else if (address >= RAM_START_ADDRESS &&
        address < RAM_START_ADDRESS + sram.length) {
      sramView.setUint32(address - RAM_START_ADDRESS, value, Endian.little);
    } else if (address >= DPRAM_START_ADDRESS &&
        address < DPRAM_START_ADDRESS + usbDPRAM.length) {
      final offset = address - DPRAM_START_ADDRESS;
      usbDPRAMView.setUint32(offset, value, Endian.little);
      usbCtrl.DPRAMUpdated(offset, value);
    } else if (address >= SIO_START_ADDRESS &&
        address < SIO_START_ADDRESS + 0x10000000) {
      sio.writeUint32(address - SIO_START_ADDRESS, value);
    } else if (address >>> 12 == 0xe000e) {
      ppb.writeUint32(address & 0xfff, value);
    } else {
      logger.warn(
        _LOG_NAME,
        'Write to undefined address: ${address.toRadixString(16)}',
      );
    }
  }

  void writeUint8(int address, int value) {
    address = u32(address);
    if (address >= RAM_START_ADDRESS &&
        address < RAM_START_ADDRESS + sram.length) {
      sram[address - RAM_START_ADDRESS] = value;
      return;
    }

    final alignedAddress = address & 0xfffffffc;
    final offset = address & 0x3;
    final peripheral = findPeripheral(address);
    if (peripheral != null) {
      final atomicType = (alignedAddress & 0x3000) >> 12;
      final offset = alignedAddress & 0xfff;
      final byte = value & 0xff;
      peripheral.writeUint32Atomic(
        offset,
        u32(byte | (byte << 8) | (byte << 16) | (byte << 24)),
        atomicType,
      );
      return;
    }
    final originalValue = readUint32(alignedAddress);
    // Replaces one byte of the little-endian word, as rp2040js does through a DataView.
    final shift = offset * 8;
    final newValue = u32(
      (originalValue & ~(0xff << shift)) | ((value & 0xff) << shift),
    );
    writeUint32(alignedAddress, newValue);
  }

  void writeUint16(int address, int value) {
    // we assume that addess is 16-bit aligned.
    // Ideally we should generate a fault if not!
    address = u32(address);

    if (address >= RAM_START_ADDRESS &&
        address < RAM_START_ADDRESS + sram.length) {
      sramView.setUint16(
        address - RAM_START_ADDRESS,
        value & 0xffff,
        Endian.little,
      );
      return;
    }

    final alignedAddress = address & 0xfffffffc;
    final offset = address & 0x3;
    final peripheral = findPeripheral(address);
    if (peripheral != null) {
      final atomicType = (alignedAddress & 0x3000) >> 12;
      final offset = alignedAddress & 0xfff;
      peripheral.writeUint32Atomic(
        offset,
        u32((value & 0xffff) | ((value & 0xffff) << 16)),
        atomicType,
      );
      return;
    }
    final originalValue = readUint32(alignedAddress);
    // Replaces one half of the little-endian word, as rp2040js does through a DataView.
    // (An offset of 1 or 3 is unaligned; rp2040js assumes it never happens.)
    final shift = offset * 8;
    final newValue = u32(
      (originalValue & ~(0xffff << shift)) | ((value & 0xffff) << shift),
    );
    writeUint32(alignedAddress, newValue);
  }

  int get gpioValues {
    var result = 0;
    for (var gpioIndex = 0; gpioIndex < gpio.length; gpioIndex++) {
      if (gpio[gpioIndex].inputValue) {
        result |= 1 << gpioIndex;
      }
    }
    return result;
  }

  void setInterrupt(int irq, bool value) {
    core.setInterrupt(irq, value);
  }

  void updateIOInterrupt() {
    var interruptValue = false;
    for (final pin in gpio) {
      if (pin.irqValue) {
        interruptValue = true;
      }
    }
    setInterrupt(IRQ.IO_BANK0, interruptValue);
  }

  void step() {
    core.executeInstruction();
  }
}
