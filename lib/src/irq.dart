// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

abstract final class IRQ {
  static const int TIMER_0 = 0;
  static const int TIMER_1 = 1;
  static const int TIMER_2 = 2;
  static const int TIMER_3 = 3;
  static const int PWM_WRAP = 4;
  static const int USBCTRL = 5;
  static const int XIP = 6;
  static const int PIO0_IRQ0 = 7;
  static const int PIO0_IRQ1 = 8;
  static const int PIO1_IRQ0 = 9;
  static const int PIO1_IRQ1 = 10;
  static const int DMA_IRQ0 = 11;
  static const int DMA_IRQ1 = 12;
  static const int IO_BANK0 = 13;
  static const int IO_QSPI = 14;
  static const int SIO_PROC0 = 15;
  static const int SIO_PROC1 = 16;
  static const int CLOCKS = 17;
  static const int SPI0 = 18;
  static const int SPI1 = 19;
  static const int UART0 = 20;
  static const int UART1 = 21;
  static const int ADC_FIFO = 22;
  static const int I2C0 = 23;
  static const int I2C1 = 24;
  static const int RTC = 25;
}

const int MAX_HARDWARE_IRQ = IRQ.RTC;
