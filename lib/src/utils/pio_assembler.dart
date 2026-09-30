// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

const int PIO_SRC_PINS = 0;
const int PIO_SRC_X = 1;
const int PIO_SRC_Y = 2;
const int PIO_SRC_NULL = 3;
const int PIO_SRC_STATUS = 5;
const int PIO_SRC_ISR = 6;
const int PIO_SRC_OSR = 7;

const int PIO_DEST_PINS = 0;
const int PIO_DEST_X = 1;
const int PIO_DEST_Y = 2;
const int PIO_DEST_NULL = 3;
const int PIO_DEST_PINDIRS = 4;
const int PIO_DEST_PC = 5;
const int PIO_DEST_ISR = 6;
const int PIO_DEST_EXEC = 7;

const int PIO_MOV_DEST_PINS = 0;
const int PIO_MOV_DEST_X = 1;
const int PIO_MOV_DEST_Y = 2;
const int PIO_MOV_DEST_EXEC = 4;
const int PIO_MOV_DEST_PC = 5;
const int PIO_MOV_DEST_ISR = 6;
const int PIO_MOV_DEST_OSR = 7;

const int PIO_OP_NONE = 0;
const int PIO_OP_INVERT = 1;
const int PIO_OP_BITREV = 2;

const int PIO_WAIT_SRC_GPIO = 0;
const int PIO_WAIT_SRC_PIN = 1;
const int PIO_WAIT_SRC_IRQ = 2;

const int PIO_COND_ALWAYS = 0;
const int PIO_COND_NOTX = 1;
const int PIO_COND_XDEC = 2;
const int PIO_COND_NOTY = 3;
const int PIO_COND_YDEC = 4;
const int PIO_COND_XNEY = 5;
const int PIO_COND_PIN = 6;
const int PIO_COND_NOTEMPTYOSR = 7;

// rp2040js gives `cond` (and `op` in pioMOV) a default value, but they come
// before a required parameter, so every caller passes them anyway: in Dart
// they are required positional parameters.

int pioJMP(int cond, int address, [int delay = 0]) {
  return ((delay & 0x1f) << 8) | ((cond & 0x7) << 5) | (address & 0x1f);
}

int pioWAIT(bool polarity, int src, int index, [int delay = 0]) {
  return (1 << 13) |
      ((delay & 0x1f) << 8) |
      ((polarity ? 1 : 0) << 7) |
      ((src & 0x3) << 5) |
      (index & 0x1f);
}

int pioIN(int src, int bitCount, [int delay = 0]) {
  return (2 << 13) |
      ((delay & 0x1f) << 8) |
      ((src & 0x7) << 5) |
      (bitCount & 0x1f);
}

int pioOUT(int Dest, int bitCount, [int delay = 0]) {
  return (3 << 13) |
      ((delay & 0x1f) << 8) |
      ((Dest & 0x7) << 5) |
      (bitCount & 0x1f);
}

int pioPUSH(bool ifFull, bool noBlock, [int delay = 0]) {
  return (4 << 13) |
      ((delay & 0x1f) << 8) |
      ((ifFull ? 1 : 0) << 6) |
      ((noBlock ? 1 : 0) << 5);
}

int pioPULL(bool ifEmpty, bool noBlock, [int delay = 0]) {
  return (4 << 13) |
      ((delay & 0x1f) << 8) |
      (1 << 7) |
      ((ifEmpty ? 1 : 0) << 6) |
      ((noBlock ? 1 : 0) << 5);
}

int pioMOV(int dest, int op, int src, [int delay = 0]) {
  return (5 << 13) |
      ((delay & 0x1f) << 8) |
      ((dest & 0x7) << 5) |
      ((op & 0x3) << 3) |
      (src & 0x7);
}

int pioIRQ(bool clear, bool wait, int index, [int delay = 0]) {
  return (6 << 13) |
      ((delay & 0x1f) << 8) |
      ((clear ? 1 : 0) << 6) |
      ((wait ? 1 : 0) << 5) |
      (index & 0x1f);
}

int pioSET(int dest, int data, [int delay = 0]) {
  return (7 << 13) |
      ((delay & 0x1f) << 8) |
      ((dest & 0x7) << 5) |
      (data & 0x1f);
}
