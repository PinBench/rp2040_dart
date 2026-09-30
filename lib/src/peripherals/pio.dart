// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'dart:async';
import 'dart:typed_data';

import '../rp2040.dart';
import '../utils/bit.dart';
import '../utils/fifo.dart';
import 'dma.dart';
import 'peripheral.dart';

// Generic registers
const int _CTRL = 0x000;
const int _FSTAT = 0x004;
const int _FDEBUG = 0x008;
const int _FLEVEL = 0x00c;
const int _IRQ = 0x030;
const int _IRQ_FORCE = 0x034;
const int _INPUT_SYNC_BYPASS = 0x038;
const int _DBG_PADOUT = 0x03c;
const int _DBG_PADOE = 0x040;
const int _DBG_CFGINFO = 0x044;
const int _INSTR_MEM0 = 0x48;
const int _INSTR_MEM31 = 0x0c4;

const int _INTR = 0x128; // Raw Interrupts
const int _IRQ0_INTE = 0x12c; // Interrupt Enable for irq0
const int _IRQ0_INTF = 0x130; // Interrupt Force for irq0
const int _IRQ0_INTS =
    0x134; // Interrupt status after masking & forcing for irq0
const int _IRQ1_INTE = 0x138; // Interrupt Enable for irq1
const int _IRQ1_INTF = 0x13c; // Interrupt Force for irq1
const int _IRQ1_INTS =
    0x140; // Interrupt status after masking & forcing for irq1

// State-machine specific registers
const int _TXF0 = 0x010;
const int _TXF1 = 0x014;
const int _TXF2 = 0x018;
const int _TXF3 = 0x01c;
const int _RXF0 = 0x020;
const int _RXF1 = 0x024;
const int _RXF2 = 0x028;
const int _RXF3 = 0x02c;
const int _SM0_CLKDIV = 0x0c8; // Clock divisor register for state machine 0
const int _SM0_EXECCTRL =
    0x0cc; // Execution/behavioural settings for state machine 0
const int _SM0_SHIFTCTRL =
    0x0d0; // Control behaviour of the input/output shift registers for state machine 0
const int _SM0_ADDR = 0x0d4; // Current instruction address of state machine 0
const int _SM0_INSTR =
    0x0d8; // Write to execute an instruction immediately (including jumps) and then resume execution.
const int _SM0_PINCTRL = 0x0dc; //State machine pin control
const int _SM1_CLKDIV = 0x0e0;
const int _SM1_PINCTRL = 0x0f4;
const int _SM2_CLKDIV = 0x0f8;
const int _SM2_PINCTRL = 0x10c;
const int _SM3_CLKDIV = 0x110;
const int _SM3_PINCTRL = 0x124;

// FSTAT bits
const int _FSTAT_TXEMPTY = 1 << 24;
const int _FSTAT_TXFULL = 1 << 16;
const int _FSTAT_RXEMPTY = 1 << 8;
const int _FSTAT_RXFULL = 1 << 0;

// FDEBUG bits
const int _FDEBUG_TXSTALL = 1 << 24;
const int _FDEBUG_TXOVER = 1 << 16;
const int _FDEBUG_RXUNDER = 1 << 8;
const int _FDEBUG_RXSTALL = 1 << 0;

// SHIFTCTRL bits
const int _SHIFTCTRL_AUTOPUSH = 1 << 16;
const int _SHIFTCTRL_AUTOPULL = 1 << 17;
const int _SHIFTCTRL_IN_SHIFTDIR =
    1 <<
    18; // 1 = shift input shift register to right (data enters from left). 0 = to left
const int _SHIFTCTRL_OUT_SHIFTDIR =
    1 << 19; // 1 = shift out of output shift register to right. 0 = to left

// EXECCTRL bits
const int _EXECCTRL_STATUS_SEL = 1 << 4;
const int _EXECCTRL_SIDE_PINDIR = 1 << 29;
const int _EXECCTRL_SIDE_EN = 1 << 30;
const int _EXECCTRL_EXEC_STALLED = 0x80000000; // 1 << 31, unsigned

enum WaitType {
  None,
  Pin,
  rxFIFO,
  txFIFO,
  IRQ,
  Out, // Out instruction
}

int _bitReverse(int x) {
  x = u32(((x & 0x55555555) << 1) | ((x & 0xaaaaaaaa) >>> 1));
  x = u32(((x & 0x33333333) << 2) | ((x & 0xcccccccc) >>> 2));
  x = u32(((x & 0x0f0f0f0f) << 4) | ((x & 0xf0f0f0f0) >>> 4));
  x = u32(((x & 0x00ff00ff) << 8) | ((x & 0xff00ff00) >>> 8));
  x = u32(((x & 0x0000ffff) << 16) | ((x & 0xffff0000) >>> 16));
  return x;
}

int _irqIndex(int irq, int machineIndex) {
  final rel = irq & 0x10 != 0;
  return rel ? (irq & 0x4) | (((irq & 0x3) + machineIndex) & 0x3) : irq & 0x7;
}

const List<int> _dreqRx0 = [
  DREQChannel.DREQ_PIO0_RX0,
  DREQChannel.DREQ_PIO0_RX1,
  DREQChannel.DREQ_PIO0_RX2,
  DREQChannel.DREQ_PIO0_RX3,
];
const List<int> _dreqTx0 = [
  DREQChannel.DREQ_PIO0_TX0,
  DREQChannel.DREQ_PIO0_TX1,
  DREQChannel.DREQ_PIO0_TX2,
  DREQChannel.DREQ_PIO0_TX3,
];
const List<int> _dreqRx1 = [
  DREQChannel.DREQ_PIO1_RX0,
  DREQChannel.DREQ_PIO1_RX1,
  DREQChannel.DREQ_PIO1_RX2,
  DREQChannel.DREQ_PIO1_RX3,
];
const List<int> _dreqTx1 = [
  DREQChannel.DREQ_PIO1_TX0,
  DREQChannel.DREQ_PIO1_TX1,
  DREQChannel.DREQ_PIO1_TX2,
  DREQChannel.DREQ_PIO1_TX3,
];

class StateMachine {
  bool enabled = false;

  // State machine registers
  int x = 0;
  int y = 0;
  int pc = 0;
  int inputShiftReg = 0;
  int inputShiftCount = 0;
  int outputShiftReg = 0;
  int outputShiftCount = 0;
  int cycles = 0;

  int execOpcode = 0;
  bool execValid = false;
  bool updatePC = true;

  int clockDivInt = 1;
  int clockDivFrac = 0;
  int execCtrl = 0x1f << 12;
  int shiftCtrl = 0x3 << 18;
  int pinCtrl = 0x5 << 26;
  final FIFO rxFIFO = FIFO(4);
  final FIFO txFIFO = FIFO(4);

  int outPinValues = 0;
  int outPinDirection = 0;

  bool waiting = false;
  WaitType waitType = WaitType.None;
  int waitIndex = 0;
  bool waitPolarity = false;
  int waitDelay = -1;

  final int dreqRx;
  final int dreqTx;

  final RP2040 rp2040;
  final RPPIO pio;
  final int index;

  StateMachine(this.rp2040, this.pio, this.index)
    : dreqRx = pio.dreqRx[index],
      dreqTx = pio.dreqTx[index] {
    _updateDMARx();
    _updateDMATx();
  }

  void _updateDMATx() {
    if (txFIFO.full) {
      rp2040.dma.clearDREQ(dreqTx);
    } else {
      rp2040.dma.setDREQ(dreqTx);
    }
  }

  void _updateDMARx() {
    if (rxFIFO.empty) {
      rp2040.dma.clearDREQ(dreqRx);
    } else {
      rp2040.dma.setDREQ(dreqRx);
    }
  }

  void writeFIFO(int value) {
    if (txFIFO.full) {
      pio.fdebug |= _FDEBUG_TXOVER << index;
      return;
    }
    txFIFO.push(value);
    pio.txStall = u32(pio.txStall & ~(_FDEBUG_TXSTALL << index));
    _updateDMATx();
    checkWait();
    if (txFIFO.full) {
      pio.checkInterrupts();
    }
  }

  int readFIFO() {
    if (rxFIFO.empty) {
      pio.fdebug |= _FDEBUG_RXUNDER << index;
      return 0;
    }
    final result = rxFIFO.pull();
    pio.rxStall = u32(pio.rxStall & ~(_FDEBUG_RXSTALL << index));
    _updateDMARx();
    checkWait();
    if (rxFIFO.empty) {
      pio.checkInterrupts();
    }
    return result;
  }

  int get status {
    final statusN = execCtrl & 0xf;
    if (execCtrl & _EXECCTRL_STATUS_SEL != 0) {
      return rxFIFO.itemCount < statusN ? 0xffffffff : 0;
    } else {
      return txFIFO.itemCount < statusN ? 0xffffffff : 0;
    }
  }

  bool jmpCondition(int condition) {
    switch (condition) {
      // (no condition): Always
      case 0x0:
        return true;

      // !X: scratch X zero
      case 0x1:
        return x == 0;

      // X--: scratch X non-zero, post-decrement
      case 0x2:
        {
          final oldX = x;
          x = u32(x - 1);
          return oldX != 0;
        }

      // !Y: scratch Y zero
      case 0x3:
        return y == 0;

      // Y--: scratch Y non-zero, post-decrement
      case 0x4:
        {
          final oldY = y;
          y = u32(y - 1);
          return oldY != 0;
        }

      // X!=Y: scratch X not equal scratch Y
      case 0x5:
        return x != y;

      // PIN: branch on input pin
      case 0x6:
        {
          final gpio = rp2040.gpio;
          final jmpPin = this.jmpPin;
          return jmpPin < gpio.length ? gpio[jmpPin].inputValue : false;
        }

      // !OSRE: output shift register not empty
      case 0x7:
        return outputShiftCount < pullThreshold;
    }

    pio.error('jmpCondition with unsupported condition: $condition');
    return false;
  }

  int get inPins {
    final gpioValues = rp2040.gpioValues;
    final inBase = this.inBase;
    // inBase is 1..31 here, so neither shift count reaches 32.
    return inBase != 0
        ? u32((gpioValues << (32 - inBase)) | (gpioValues >>> inBase))
        : gpioValues;
  }

  int inSourceValue(int source) {
    switch (source) {
      // PINS
      case 0x0:
        return inPins;

      // X (scratch register X)
      case 0x1:
        return x;

      // Y (scratch register Y)
      case 0x2:
        return y;

      // NULL (all zeroes)
      case 0x3:
        return 0;

      // Reserved
      case 0x4:
        return 0;

      // Reserved for IN, STATUS for MOV
      case 0x5:
        return status;

      // ISR
      case 0x6:
        return inputShiftReg;

      // OSR
      case 0x7:
        return outputShiftReg;
    }

    pio.error('inSourceValue with unsupported source: $source');
    return 0;
  }

  void writeOutValue(int destination, int value, int bitCount) {
    switch (destination) {
      // PINS
      case 0x0:
        setOutPins(value);
        break;

      // X (scratch register X)
      case 0x1:
        x = value;
        break;

      // Y (scratch register Y)
      case 0x2:
        y = value;
        break;

      // NULL (discard data)
      case 0x3:
        break;

      // PINDIRS
      case 0x4:
        setOutPinDirs(value);
        break;

      // PC
      case 0x5:
        pc = value & 0x1f;
        updatePC = false;
        break;

      // ISR (also sets ISR shift counter to Bit count)
      case 0x6:
        inputShiftReg = value;
        inputShiftCount = bitCount;
        break;

      // EXEC (Execute OSR shift data as instruction)
      case 0x7:
        execOpcode = value;
        execValid = true;
        break;
    }
  }

  int get pushThreshold {
    final value = (shiftCtrl >> 20) & 0x1f;
    return value != 0 ? value : 32;
  }

  int get pullThreshold {
    final value = (shiftCtrl >> 25) & 0x1f;
    return value != 0 ? value : 32;
  }

  int get sidesetCount => (pinCtrl >> 29) & 0x7;

  int get setCount => (pinCtrl >> 26) & 0x7;

  int get outCount => (pinCtrl >> 20) & 0x3f;

  int get inBase => (pinCtrl >> 15) & 0x1f;

  int get sidesetBase => (pinCtrl >> 10) & 0x1f;

  int get setBase => (pinCtrl >> 5) & 0x1f;

  int get outBase => (pinCtrl >> 0) & 0x1f;

  int get jmpPin => (execCtrl >> 24) & 0x1f;

  int get wrapTop => (execCtrl >> 12) & 0x1f;

  int get wrapBottom => (execCtrl >> 7) & 0x1f;

  void setOutPinDirs(int value) {
    outPinDirection = value;
    pio.pinDirectionsChanged(value, outBase, outCount);
  }

  void setOutPins(int value) {
    outPinValues = value;
    pio.pinValuesChanged(value, outBase, outCount);
  }

  void outInstruction(int arg) {
    final bitCount = arg & 0x1f;
    final destination = arg >> 5;

    if (bitCount == 0) {
      writeOutValue(destination, outputShiftReg, 32);
      outputShiftCount = 32;
    } else {
      // bitCount is 1..31 here: every shift count below stays under 32, and
      // `(1 << 31) - 1` is the same 0x7fffffff mask JS ends up with.
      if (shiftCtrl & _SHIFTCTRL_OUT_SHIFTDIR != 0) {
        final value = outputShiftReg & ((1 << bitCount) - 1);
        outputShiftReg >>>= bitCount;
        writeOutValue(destination, value, bitCount);
      } else {
        final value = outputShiftReg >>> (32 - bitCount);
        outputShiftReg = u32(outputShiftReg << bitCount);
        writeOutValue(destination, value, bitCount);
      }
      outputShiftCount += bitCount;
      if (outputShiftCount > 32) {
        outputShiftCount = 32;
      }
    }
  }

  void executeInstruction(int opcode) {
    final arg = opcode & 0xff;
    switch (opcode >>> 13) {
      /* JMP */
      case 0x0:
        if (jmpCondition(arg >> 5)) {
          pc = arg & 0x1f;
          updatePC = false;
        }
        break;

      /* WAIT */
      case 0x1:
        {
          final polarity = arg & 0x80 != 0;
          final source = (arg >> 5) & 0x3;
          final index = arg & 0x1f;
          switch (source) {
            // GPIO:
            case 0x0:
              wait(WaitType.Pin, polarity, index);
              break;

            // PIN:
            case 0x1:
              wait(WaitType.Pin, polarity, (index + inBase) % 32);
              break;

            // IRQ:
            case 0x2:
              wait(WaitType.IRQ, polarity, _irqIndex(index, this.index));
              break;
          }
          break;
        }

      /* IN */
      case 0x2:
        {
          final bitCount = arg & 0x1f;
          var sourceValue = inSourceValue(arg >> 5);

          if (bitCount == 0) {
            inputShiftReg = sourceValue;
            inputShiftCount = 32;
          } else {
            // bitCount is 1..31 here, so no shift count reaches 32.
            sourceValue &= (1 << bitCount) - 1;
            if (shiftCtrl & _SHIFTCTRL_IN_SHIFTDIR != 0) {
              inputShiftReg >>>= bitCount;
              inputShiftReg = u32(
                inputShiftReg | (sourceValue << (32 - bitCount)),
              );
            } else {
              inputShiftReg = u32(inputShiftReg << bitCount);
              inputShiftReg |= sourceValue;
            }
            inputShiftCount += bitCount;
            if (inputShiftCount > 32) {
              inputShiftCount = 32;
            }
          }

          if (shiftCtrl & _SHIFTCTRL_AUTOPUSH != 0 &&
              inputShiftCount >= pushThreshold) {
            if (!rxFIFO.full) {
              rxFIFO.push(inputShiftReg);
              _updateDMARx();
              pio.checkInterrupts();
            } else {
              pio.rxStall |= _FDEBUG_RXSTALL << index;
              pio.fdebug |= pio.rxStall;
              wait(WaitType.rxFIFO, false, inputShiftReg);
            }
            inputShiftCount = 0;
            inputShiftReg = 0;
          }

          break;
        }

      /* OUT */
      case 0x3:
        {
          if (shiftCtrl & _SHIFTCTRL_AUTOPULL != 0 &&
              outputShiftCount >= pullThreshold) {
            outputShiftCount = 0;
            if (!txFIFO.empty) {
              outputShiftReg = txFIFO.pull();
              _updateDMATx();
              pio.checkInterrupts();
            } else {
              pio.txStall |= _FDEBUG_TXSTALL << index;
              pio.fdebug |= pio.txStall;
              wait(WaitType.Out, false, arg);
            }
          }

          if (!waiting) {
            outInstruction(arg);
          }
          break;
        }

      /* PUSH/PULL */
      case 0x4:
        {
          final block = arg & (1 << 5) != 0;
          final ifFullOrEmpty = arg & (1 << 6) != 0;
          if (arg & 0x1f != 0) {
            // Unknown instruction
            break;
          }
          if (arg & 0x80 != 0) {
            // PULL
            if (ifFullOrEmpty &&
                shiftCtrl & _SHIFTCTRL_AUTOPULL != 0 &&
                outputShiftCount < pullThreshold) {
              break;
            }
            if (!txFIFO.empty) {
              outputShiftReg = txFIFO.pull();
              _updateDMATx();
              pio.checkInterrupts();
            } else {
              pio.txStall |= _FDEBUG_TXSTALL << index;
              pio.fdebug |= pio.txStall;
              if (block) {
                wait(WaitType.txFIFO, false, 0);
              } else {
                outputShiftReg = x;
              }
            }
            outputShiftCount = 0;
          } else {
            // PUSH
            if (ifFullOrEmpty &&
                shiftCtrl & _SHIFTCTRL_AUTOPUSH != 0 &&
                inputShiftCount < pushThreshold) {
              break;
            }
            if (!rxFIFO.full) {
              rxFIFO.push(inputShiftReg);
              _updateDMARx();
              pio.checkInterrupts();
            } else {
              pio.rxStall |= _FDEBUG_RXSTALL << index;
              pio.fdebug |= pio.rxStall;
              if (block) {
                wait(WaitType.rxFIFO, false, inputShiftReg);
              }
            }
            inputShiftReg = 0;
            inputShiftCount = 0;
          }
          break;
        }

      /* MOV */
      case 0x5:
        {
          final source = arg & 0x7;
          final op = (arg >> 3) & 0x3;
          final destination = (arg >> 5) & 0x7;
          final value = inSourceValue(source);
          final transformedValue = u32(transformMovValue(value, op));
          setMovDestination(destination, transformedValue);
          break;
        }

      /* IRQ */
      case 0x6:
        {
          if (arg & 0x80 != 0) {
            // Unknown instruction
            break;
          }
          final clear = arg & 0x40 != 0;
          final wait = arg & 0x20 != 0;
          final irq = _irqIndex(arg & 0x1f, index);
          if (clear) {
            pio.irq = u32(pio.irq & ~(1 << irq));
            pio.irqUpdated();
          } else {
            pio.irq |= 1 << irq;
            pio.irqUpdated();
            if (wait) {
              this.wait(WaitType.IRQ, false, irq);
            }
          }
          break;
        }

      /* SET */
      case 0x7:
        {
          final data = arg & 0x1f;
          final destination = arg >> 5;
          switch (destination) {
            case 0x0:
              setSetPins(data);
              break;
            case 0x1:
              x = data;
              break;
            case 0x2:
              y = data;
              break;
            case 0x4:
              setSetPinDirs(data);
              break;
          }
          break;
        }
    }

    cycles++;

    final sidesetCount = this.sidesetCount;
    final execCtrl = this.execCtrl;
    final delaySideset = (opcode >> 8) & 0x1f;
    final sideEn = execCtrl & _EXECCTRL_SIDE_EN != 0;
    // sidesetCount can be 6 or 7, making the shift count negative: JS takes it
    // mod 32 (so the mask becomes 0x7fffffff / 0x3fffffff), and `& 31` does the same.
    final delay = delaySideset & ((1 << ((5 - sidesetCount) & 31)) - 1);

    if (sidesetCount != 0 && (!sideEn || delaySideset & 0x10 != 0)) {
      final sideset = delaySideset >> ((5 - sidesetCount) & 31);
      setSideset(sideset, sideEn ? sidesetCount - 1 : sidesetCount);
    }

    if (execValid) {
      execValid = false;
      executeInstruction(execOpcode);
    } else if (waiting) {
      if (waitDelay < 0) {
        waitDelay = delay;
      }
      checkWait();
    } else {
      cycles += delay;
    }
  }

  void wait(WaitType type, bool polarity, int index) {
    waiting = true;
    waitType = type;
    waitPolarity = polarity;
    waitIndex = index;
    waitDelay = -1;
    updatePC = false;
  }

  void nextPC() {
    if (pc == wrapTop) {
      pc = wrapBottom;
    } else {
      pc = (pc + 1) & 0x1f;
    }
  }

  void step() {
    if (waiting) {
      checkWait();
      if (waiting) {
        return;
      }
    }

    updatePC = true;
    executeInstruction(pio.instructions[pc]);
    if (updatePC) {
      nextPC();
    }
  }

  void setSetPinDirs(int value) {
    pio.pinDirectionsChanged(value, setBase, setCount);
  }

  void setSetPins(int value) {
    pio.pinValuesChanged(value, setBase, setCount);
  }

  void setSideset(int value, int count) {
    if (execCtrl & _EXECCTRL_SIDE_PINDIR != 0) {
      pio.pinDirectionsChanged(value, sidesetBase, count);
    } else {
      pio.pinValuesChanged(value, sidesetBase, count);
    }
  }

  int transformMovValue(int value, int op) {
    switch (op) {
      case 0x0:
        return value;
      case 0x1:
        return u32(~value);
      case 0x2:
        return _bitReverse(value);
      case 0x3:
      default:
        return value; // reserved
    }
  }

  void setMovDestination(int destination, int value) {
    switch (destination) {
      // PINS
      case 0x0:
        setOutPins(value);
        break;

      // X (scratch register X)
      case 0x1:
        x = value;
        break;

      // Y (scratch register Y)
      case 0x2:
        y = value;
        break;

      // reserved (discard data)
      case 0x3:
        break;

      // EXEC
      case 0x4:
        execOpcode = value;
        execValid = true;
        break;

      // PC
      case 0x5:
        pc = value & 0x1f;
        updatePC = false;
        break;

      // ISR (Input shift counter is reset to 0 by this operation, i.e. empty)
      case 0x6:
        inputShiftReg = value;
        inputShiftCount = 0;
        break;

      // OSR (Output shift counter is reset to 0 by this operation, i.e. full)
      case 0x7:
        outputShiftReg = value;
        outputShiftCount = 0;
        break;
    }
  }

  int readUint32(int offset) {
    switch (offset + _SM0_CLKDIV) {
      case _SM0_CLKDIV:
        return u32((clockDivInt << 16) | (clockDivFrac << 8));
      case _SM0_EXECCTRL:
        return execCtrl;
      case _SM0_SHIFTCTRL:
        return shiftCtrl;
      case _SM0_ADDR:
        return pc;
      case _SM0_INSTR:
        return pio.instructions[pc];
      case _SM0_PINCTRL:
        return pinCtrl;
    }
    pio.error('Read from invalid state machine register: $offset');
    return 0;
  }

  void writeUint32(int offset, int value) {
    switch (offset + _SM0_CLKDIV) {
      case _SM0_CLKDIV:
        clockDivFrac = (value >>> 8) & 0xff;
        clockDivInt = value >>> 16;
        break;
      case _SM0_EXECCTRL:
        execCtrl = u32((value & 0x7fffffff) | (execCtrl & 0x80000000));
        break;
      case _SM0_SHIFTCTRL:
        shiftCtrl = value;
        break;
      case _SM0_ADDR:
        /* read-only */
        break;
      case _SM0_INSTR:
        executeInstruction(value & 0xffff);
        if (waiting) {
          execCtrl |= _EXECCTRL_EXEC_STALLED;
        }
        break;
      case _SM0_PINCTRL:
        pinCtrl = value;
        break;
      default:
        pio.error('Write to invalid state machine register: $offset');
    }
  }

  int get fifoStat {
    final result =
        (txFIFO.empty ? _FSTAT_TXEMPTY : 0) |
        (txFIFO.full ? _FSTAT_TXFULL : 0) |
        (rxFIFO.empty ? _FSTAT_RXEMPTY : 0) |
        (rxFIFO.full ? _FSTAT_RXFULL : 0);
    return u32(result << index);
  }

  void restart() {
    cycles = 0;
    inputShiftCount = 0;
    outputShiftCount = 32;
    inputShiftReg = 0;
    waiting = false;
    // TODO any pin write left asserted due to OUT_STICKY.
  }

  void clkDivRestart() {
    pio.warn('clkDivRestart not implemented');
  }

  void checkWait() {
    if (!waiting) {
      return;
    }

    switch (waitType) {
      case WaitType.IRQ:
        {
          final irqValue = pio.irq & (1 << waitIndex) != 0;
          if (irqValue == waitPolarity) {
            waiting = false;
            if (irqValue) {
              pio.irq = u32(pio.irq & ~(1 << waitIndex));
            }
          }
          break;
        }

      case WaitType.Pin:
        {
          if (waitIndex < rp2040.gpio.length &&
              rp2040.gpio[waitIndex].inputValue == waitPolarity) {
            waiting = false;
          }
          break;
        }

      case WaitType.rxFIFO:
        {
          if (!rxFIFO.full) {
            rxFIFO.push(waitIndex);
            waiting = false;
            _updateDMARx();
            pio.checkInterrupts();
          }
          break;
        }

      case WaitType.txFIFO:
        {
          if (!txFIFO.empty) {
            outputShiftReg = txFIFO.pull();
            waiting = false;
            _updateDMATx();
            pio.checkInterrupts();
          }
          break;
        }

      case WaitType.Out:
        {
          if (!txFIFO.empty) {
            outputShiftReg = txFIFO.pull();
            outInstruction(waitIndex);
            waiting = false;
            _updateDMATx();
            pio.checkInterrupts();
          }
          break;
        }

      case WaitType.None:
        break;
    }

    if (!waiting) {
      nextPC();
      cycles += waitDelay;
      execCtrl = u32(execCtrl & ~_EXECCTRL_EXEC_STALLED);
    }
  }
}

class RPPIO extends BasePeripheral implements Peripheral {
  final Uint32List instructions = Uint32List(32);
  final List<int> dreqRx;
  final List<int> dreqTx;

  /// Filled in the constructor body, in rp2040js's order (right after
  /// `dreqRx`/`dreqTx`): a Dart field initialiser cannot pass `this` to the
  /// state machines, and a `late` initialiser would create them (and set their
  /// DREQs) lazily instead of at construction.
  final List<StateMachine> machines = [];

  bool stopped = true;
  int fdebug = 0;
  int txStall = 0;
  int rxStall = 0;
  int inputSyncBypass = 0;
  int irq = 0;
  int pinValues = 0;
  int pinDirections = 0;
  int oldPinValues = 0;
  int oldPinDirections = 0;
  Timer? _runTimer;

  int irq0IntEnable = 0;
  int irq0IntForce = 0;
  int irq1IntEnable = 0;
  int irq1IntForce = 0;

  final int firstIrq;
  final int index;

  RPPIO(super.rp2040, super.name, this.firstIrq, this.index)
    : dreqRx = index != 0 ? _dreqRx1 : _dreqRx0,
      dreqTx = index != 0 ? _dreqTx1 : _dreqTx0 {
    machines.addAll([
      StateMachine(rp2040, this, 0),
      StateMachine(rp2040, this, 1),
      StateMachine(rp2040, this, 2),
      StateMachine(rp2040, this, 3),
    ]);
  }

  int get intRaw {
    return ((irq & 0xf) << 8) |
        (!machines[3].txFIFO.full ? 0x80 : 0) |
        (!machines[2].txFIFO.full ? 0x40 : 0) |
        (!machines[1].txFIFO.full ? 0x20 : 0) |
        (!machines[0].txFIFO.full ? 0x10 : 0) |
        (!machines[3].rxFIFO.empty ? 0x08 : 0) |
        (!machines[2].rxFIFO.empty ? 0x04 : 0) |
        (!machines[1].rxFIFO.empty ? 0x02 : 0) |
        (!machines[0].rxFIFO.empty ? 0x01 : 0);
  }

  int get irq0IntStatus => (intRaw & irq0IntEnable) | irq0IntForce;

  int get irq1IntStatus => (intRaw & irq1IntEnable) | irq1IntForce;

  @override
  int readUint32(int offset) {
    if (offset >= _SM0_CLKDIV && offset <= _SM0_PINCTRL) {
      return machines[0].readUint32(offset - _SM0_CLKDIV);
    }
    if (offset >= _SM1_CLKDIV && offset <= _SM1_PINCTRL) {
      return machines[1].readUint32(offset - _SM1_CLKDIV);
    }
    if (offset >= _SM2_CLKDIV && offset <= _SM2_PINCTRL) {
      return machines[2].readUint32(offset - _SM2_CLKDIV);
    }
    if (offset >= _SM3_CLKDIV && offset <= _SM3_PINCTRL) {
      return machines[3].readUint32(offset - _SM3_CLKDIV);
    }

    switch (offset) {
      case _CTRL:
        return (machines[0].enabled ? 1 << 0 : 0) |
            (machines[1].enabled ? 1 << 1 : 0) |
            (machines[2].enabled ? 1 << 2 : 0) |
            (machines[3].enabled ? 1 << 3 : 0);
      case _FSTAT:
        return machines[0].fifoStat |
            machines[1].fifoStat |
            machines[2].fifoStat |
            machines[3].fifoStat;
      case _FDEBUG:
        return fdebug;
      case _FLEVEL:
        return u32(
          (machines[0].txFIFO.itemCount & 0xf) |
              ((machines[0].rxFIFO.itemCount & 0xf) << 4) |
              ((machines[1].txFIFO.itemCount & 0xf) << 8) |
              ((machines[1].rxFIFO.itemCount & 0xf) << 12) |
              ((machines[2].txFIFO.itemCount & 0xf) << 16) |
              ((machines[2].rxFIFO.itemCount & 0xf) << 20) |
              ((machines[3].txFIFO.itemCount & 0xf) << 24) |
              ((machines[3].rxFIFO.itemCount & 0xf) << 28),
        );

      case _RXF0:
        return machines[0].readFIFO();
      case _RXF1:
        return machines[1].readFIFO();
      case _RXF2:
        return machines[2].readFIFO();
      case _RXF3:
        return machines[3].readFIFO();
      case _IRQ:
        return irq;
      case _IRQ_FORCE:
        return 0;
      case _INPUT_SYNC_BYPASS:
        return inputSyncBypass;
      case _DBG_PADOUT:
        return pinValues;
      case _DBG_PADOE:
        return pinDirections;
      case _DBG_CFGINFO:
        return 0x200404;
      case _INTR:
        return intRaw;
      case _IRQ0_INTE:
        return irq0IntEnable;
      case _IRQ0_INTF:
        return irq0IntForce;
      case _IRQ0_INTS:
        return irq0IntStatus;
      case _IRQ1_INTE:
        return irq1IntEnable;
      case _IRQ1_INTF:
        return irq1IntForce;
      case _IRQ1_INTS:
        return irq1IntStatus;
    }
    return super.readUint32(offset);
  }

  @override
  void writeUint32(int offset, int value) {
    if (offset >= _INSTR_MEM0 && offset <= _INSTR_MEM31) {
      final index = (offset - _INSTR_MEM0) >> 2;
      instructions[index] = value & 0xffff;
      return;
    }
    if (offset >= _SM0_CLKDIV && offset <= _SM0_PINCTRL) {
      machines[0].writeUint32(offset - _SM0_CLKDIV, value);
      return;
    }
    if (offset >= _SM1_CLKDIV && offset <= _SM1_PINCTRL) {
      machines[1].writeUint32(offset - _SM1_CLKDIV, value);
      return;
    }
    if (offset >= _SM2_CLKDIV && offset <= _SM2_PINCTRL) {
      machines[2].writeUint32(offset - _SM2_CLKDIV, value);
      return;
    }
    if (offset >= _SM3_CLKDIV && offset <= _SM3_PINCTRL) {
      machines[3].writeUint32(offset - _SM3_CLKDIV, value);
      return;
    }
    switch (offset) {
      case _CTRL:
        {
          for (var index = 0; index < 4; index++) {
            machines[index].enabled = value & (1 << index) != 0 ? true : false;
            if (value & (1 << (4 + index)) != 0) {
              machines[index].restart();
            }
            if (value & (1 << (8 + index)) != 0) {
              machines[index].clkDivRestart();
            }
          }
          final shouldRun = value & 0xf;
          if (stopped && shouldRun != 0) {
            stopped = false;
            run();
          }
          if (shouldRun == 0) {
            stopped = true;
          }
          break;
        }
      case _FDEBUG:
        fdebug = u32(fdebug & ~rawWriteValue);
        fdebug |= txStall | rxStall;
        break;
      case _TXF0:
        machines[0].writeFIFO(value);
        break;
      case _TXF1:
        machines[1].writeFIFO(value);
        break;
      case _TXF2:
        machines[2].writeFIFO(value);
        break;
      case _TXF3:
        machines[3].writeFIFO(value);
        break;
      case _IRQ:
        irq = u32(irq & ~rawWriteValue);
        irqUpdated();
        break;
      case _INPUT_SYNC_BYPASS:
        inputSyncBypass = value;
        break;
      case _IRQ_FORCE:
        irq |= value;
        irqUpdated();
        break;
      case _IRQ0_INTE:
        irq0IntEnable = value & 0xfff;
        checkInterrupts();
        break;
      case _IRQ0_INTF:
        irq0IntForce = value & 0xfff;
        checkInterrupts();
        break;
      case _IRQ1_INTE:
        irq1IntEnable = value & 0xfff;
        checkInterrupts();
        break;
      case _IRQ1_INTF:
        irq1IntForce = value & 0xfff;
        checkInterrupts();
        break;
      default:
        super.writeUint32(offset, value);
    }
  }

  void pinValuesChanged(int value, int firstPin, int count) {
    // TODO: wrapping after pin 31
    final mask = count > 31 ? 0xffffffff : u32(((1 << count) - 1) << firstPin);
    final newValue =
        ((pinValues & ~mask) | ((value << firstPin) & mask)) & 0x3fffffff;
    pinValues = newValue;
  }

  void pinDirectionsChanged(int value, int firstPin, int count) {
    // TODO: wrapping after pin 31
    final mask = count > 31 ? 0xffffffff : u32(((1 << count) - 1) << firstPin);
    final newValue =
        ((pinDirections & ~mask) | ((value << firstPin) & mask)) & 0x3fffffff;
    pinDirections = newValue;
  }

  void checkInterrupts() {
    final firstIrq = this.firstIrq;
    rp2040.setInterrupt(firstIrq, irq0IntStatus != 0);
    rp2040.setInterrupt(firstIrq + 1, irq1IntStatus != 0);
  }

  void irqUpdated() {
    for (final machine in machines) {
      machine.checkWait();
    }
    checkInterrupts();
  }

  void checkChangedPins() {
    final changedPins =
        (oldPinDirections ^ pinDirections) | (oldPinValues ^ pinValues);
    if (changedPins != 0) {
      oldPinDirections = pinDirections;
      oldPinValues = pinValues;

      // Notify GPIO about the changed pins
      final gpio = rp2040.gpio;
      for (var gpioIndex = 0; gpioIndex < gpio.length; gpioIndex++) {
        if (changedPins & (1 << gpioIndex) != 0) {
          gpio[gpioIndex].checkForUpdates();
        }
      }
    }
  }

  void step() {
    for (final machine in machines) {
      machine.step();
    }
    checkChangedPins();
  }

  void run() {
    for (var i = 0; i < 1000 && !stopped; i++) {
      step();
    }
    if (!stopped) {
      _runTimer = Timer(Duration.zero, run);
    }
  }

  void stop() {
    for (final machine in machines) {
      machine.enabled = false;
    }
    stopped = true;
    final runTimer = _runTimer;
    if (runTimer != null) {
      runTimer.cancel();
      _runTimer = null;
    }
  }
}
