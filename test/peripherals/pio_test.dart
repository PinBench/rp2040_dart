// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'package:rp2040_dart/src/utils/pio_assembler.dart';
import 'package:test/test.dart';

import '../test_utils/create_test_driver.dart';
import '../test_utils/test_driver.dart';

const CTRL = 0x50200000;
const FLEVEL = 0x5020000c;
const TXF0 = 0x50200010;
const RXF0 = 0x50200020;
const IRQ = 0x50200030;
const INSTR_MEM0 = 0x50200048;
const INSTR_MEM1 = 0x5020004c;
const INSTR_MEM2 = 0x50200050;
const INSTR_MEM3 = 0x50200054;
const SM0_SHIFTCTRL = 0x502000d0;
const SM0_EXECCTRL = 0x502000cc;
const SM0_ADDR = 0x502000d4;
const SM0_INSTR = 0x502000d8;
const SM0_PINCTRL = 0x502000dc;
const SM2_INSTR = 0x50200108;
const INTR = 0x50200128;
const IRQ0_INTE = 0x5020012c;
const FDEBUG = 0x50200008; // Debug register

const NVIC_ISPR = 0xe000e200;
const NVIC_ICPR = 0xe000e280;

// Interrupt flags
const PIO_IRQ0 = 1 << 7;
const INTR_SM0_RXNEMPTY = 1 << 0;
const INTR_SM0_TXNFULL = 1 << 4;

// SHIFTs for FLEVEL
const TX0_SHIFT = 0;
const RX0_SHIFT = 4;

// SM0_SHIFTCTRL bits:
const FJOIN_RX = 1 << 30;
const IN_SHIFTDIR = 1 << 18;
const OUT_SHIFTDIR = 1 << 19;
const SHIFTCTRL_AUTOPULL = 1 << 17;
const SHIFTCTRL_AUTOPUSH = 1 << 16;
const SHIFTCTRL_PULL_THRESH_SHIFT = 25;
const SHIFTCTRL_PUSH_THRESH_SHIFT = 20;

// EXECCTRL bits:
const EXECCTRL_EXEC_STALLED = 0x80000000; // 1 << 31, unsigned
const EXECCTRL_STATUS_SEL = 1 << 4;
const EXECCTRL_WRAP_BOTTOM_SHIFT = 7;
const EXECCTRL_WRAP_TOP_SHIFT = 12;
const EXECCTRL_STATUS_N_SHIFT = 0;

// FDEBUG bits
const FDEBUG_TXSTALL = 1 << 24;

const DBG_PADOUT = 0x5020003c;

const SET_COUNT_SHIFT = 26;
const SET_COUNT_BASE = 5;
const OUT_COUNT_SHIFT = 20;

const VALID_PINS_MASK = 0x3fffffff;

void main() {
  group('PIO', () {
    late ICortexTestDriver cpu;

    setUp(() {
      cpu = createTestDriver();
    });

    tearDown(() {
      cpu.tearDown();
    });

    void resetStateMachines() {
      cpu.writeUint32(CTRL, 0xf0);
      cpu.writeUint32(
        SM0_INSTR,
        pioJMP(PIO_COND_ALWAYS, 0),
      ); // Jump machine 0 to address 0
      // Clear FIFOs
      cpu.writeUint32(SM0_SHIFTCTRL, FJOIN_RX);
      // Values at reset
      cpu.writeUint32(SM0_SHIFTCTRL, IN_SHIFTDIR | OUT_SHIFTDIR);
      cpu.writeUint32(SM0_PINCTRL, 5 << SET_COUNT_SHIFT);
    }

    test('should execute a `SET PINS` instruction correctly', () {
      // SET PINS, 13
      // then check the debug register and verify that that output from the pins matches the PINS value
      const shiftAmount = 0;
      const pinsQty = 5;
      const pinsValue = 13;
      resetStateMachines();
      cpu.writeUint32(
        SM0_PINCTRL,
        (pinsQty << SET_COUNT_SHIFT) | (shiftAmount << SET_COUNT_BASE),
      );
      cpu.writeUint32(SM0_INSTR, pioSET(PIO_DEST_PINS, pinsValue));
      expect(
        cpu.readUint32(DBG_PADOUT) & (((1 << pinsQty) - 1) << shiftAmount),
        pinsValue << shiftAmount,
      );
    });

    test('should execute a `MOV PINS, X` instruction correctly', () {
      resetStateMachines();
      cpu.writeUint32(SM0_PINCTRL, 32 << OUT_COUNT_SHIFT);
      cpu.writeUint32(SM0_INSTR, pioSET(PIO_DEST_X, 8));
      cpu.writeUint32(SM0_INSTR, pioMOV(PIO_DEST_PINS, PIO_OP_NONE, PIO_SRC_X));
      expect(cpu.readUint32(DBG_PADOUT), 8);
    });

    test('should execute a `MOV PINS, ~X` instruction', () {
      resetStateMachines();
      cpu.writeUint32(SM0_PINCTRL, 32 << OUT_COUNT_SHIFT);
      cpu.writeUint32(SM0_INSTR, pioSET(PIO_DEST_X, 29));
      cpu.writeUint32(
        SM0_INSTR,
        pioMOV(PIO_DEST_PINS, PIO_OP_INVERT, PIO_SRC_X),
      );
      expect(cpu.readUint32(DBG_PADOUT), ~29 & VALID_PINS_MASK);
    });

    test('should correctly `MOV PINS, ::X` instruction', () {
      resetStateMachines();
      cpu.writeUint32(SM0_PINCTRL, 32 << OUT_COUNT_SHIFT);
      cpu.writeUint32(SM0_INSTR, pioSET(PIO_DEST_X, 0x19 /* 0b11001 */));
      cpu.writeUint32(
        SM0_INSTR,
        pioMOV(PIO_DEST_PINS, PIO_OP_BITREV, PIO_SRC_X),
      );
      expect(cpu.readUint32(DBG_PADOUT), 0x98000000 & VALID_PINS_MASK);
    });

    test('should correctly a `MOV Y, X` instruction', () {
      resetStateMachines();
      cpu.writeUint32(SM0_PINCTRL, 32 << OUT_COUNT_SHIFT);
      cpu.writeUint32(SM0_INSTR, pioSET(PIO_DEST_X, 11));
      cpu.writeUint32(
        SM0_INSTR,
        pioMOV(PIO_MOV_DEST_Y, PIO_OP_NONE, PIO_SRC_X),
      );
      cpu.writeUint32(SM0_INSTR, pioMOV(PIO_DEST_PINS, PIO_OP_NONE, PIO_SRC_Y));
      expect(cpu.readUint32(DBG_PADOUT), 11);
    });

    test('should correctly a `MOV PC, Y` instruction', () {
      resetStateMachines();
      expect(cpu.readUint32(SM0_ADDR), 0);
      cpu.writeUint32(SM0_INSTR, pioSET(PIO_DEST_Y, 23));
      cpu.writeUint32(
        SM0_INSTR,
        pioMOV(PIO_MOV_DEST_PC, PIO_OP_NONE, PIO_SRC_Y),
      );
      expect(cpu.readUint32(SM0_ADDR), 23);
    });

    test(
      'should correctly a `MOV ISR, STATUS` instruction when the STATUS_SEL is 0 (TX FIFO)',
      () {
        resetStateMachines();
        cpu.writeUint32(SM0_EXECCTRL, 2 << EXECCTRL_STATUS_N_SHIFT);
        cpu.writeUint32(
          SM0_INSTR,
          pioMOV(PIO_MOV_DEST_ISR, PIO_OP_NONE, PIO_SRC_STATUS),
        );
        cpu.writeUint32(SM0_INSTR, pioPUSH(false, false));
        expect(cpu.readUint32(RXF0), 0xffffffff);

        cpu.writeUint32(TXF0, 1);
        cpu.writeUint32(TXF0, 2);
        cpu.writeUint32(
          SM0_INSTR,
          pioMOV(PIO_MOV_DEST_ISR, PIO_OP_NONE, PIO_SRC_STATUS),
        );
        cpu.writeUint32(SM0_INSTR, pioPUSH(false, false));
        expect(cpu.readUint32(RXF0), 0);
      },
    );

    test(
      'should correctly a `MOV ISR, STATUS` instruction when the STATUS_SEL is 1 (RX FIFO)',
      () {
        resetStateMachines();
        cpu.writeUint32(
          SM0_EXECCTRL,
          (1 << EXECCTRL_STATUS_N_SHIFT) | EXECCTRL_STATUS_SEL,
        );

        cpu.writeUint32(
          SM0_INSTR,
          pioMOV(PIO_MOV_DEST_ISR, PIO_OP_NONE, PIO_SRC_STATUS),
        );
        cpu.writeUint32(SM0_INSTR, pioPUSH(false, false));
        cpu.writeUint32(
          SM0_INSTR,
          pioMOV(PIO_MOV_DEST_ISR, PIO_OP_NONE, PIO_SRC_STATUS),
        );
        cpu.writeUint32(SM0_INSTR, pioPUSH(false, false));
        expect(cpu.readUint32(RXF0), 0xffffffff);
        expect(cpu.readUint32(RXF0), 0);
      },
    );

    test('should correctly execute a `JMP` (always) instruction', () {
      resetStateMachines();
      cpu.writeUint32(SM0_INSTR, pioJMP(PIO_COND_ALWAYS, 10));
      expect(cpu.readUint32(SM0_ADDR), 10);
    });

    test('should correctly execute a `JMP !X` instruction', () {
      resetStateMachines();
      expect(cpu.readUint32(SM0_ADDR), 0);
      cpu.writeUint32(SM0_INSTR, pioSET(PIO_DEST_X, 5));
      cpu.writeUint32(SM0_INSTR, pioJMP(PIO_COND_NOTX, 8));
      expect(cpu.readUint32(SM0_ADDR), 0);
      cpu.writeUint32(SM0_INSTR, pioSET(PIO_DEST_X, 0));
      cpu.writeUint32(SM0_INSTR, pioJMP(PIO_COND_NOTX, 8));
      expect(cpu.readUint32(SM0_ADDR), 8);
    });

    test('should correctly execute a `JMP X--` instruction', () {
      resetStateMachines();
      cpu.writeUint32(SM0_PINCTRL, 32 << OUT_COUNT_SHIFT);
      expect(cpu.readUint32(SM0_ADDR), 0);
      cpu.writeUint32(SM0_INSTR, pioSET(PIO_DEST_X, 5));
      cpu.writeUint32(SM0_INSTR, pioJMP(PIO_COND_XDEC, 12));
      expect(cpu.readUint32(SM0_ADDR), 12);
      // X should be 4:
      cpu.writeUint32(SM0_INSTR, pioMOV(PIO_DEST_PINS, PIO_OP_NONE, PIO_SRC_X));
      expect(cpu.readUint32(DBG_PADOUT), 4);
      // now set X to zero and ensure that we don't jump again
      cpu.writeUint32(SM0_INSTR, pioSET(PIO_DEST_X, 0));
      cpu.writeUint32(SM0_INSTR, pioJMP(PIO_COND_XDEC, 6));
      expect(cpu.readUint32(SM0_ADDR), 12);
    });

    test('should correctly execute a `JMP !Y` instruction', () {
      resetStateMachines();
      expect(cpu.readUint32(SM0_ADDR), 0);
      cpu.writeUint32(SM0_INSTR, pioSET(PIO_DEST_Y, 6));
      cpu.writeUint32(SM0_INSTR, pioJMP(PIO_COND_NOTY, 8));
      expect(cpu.readUint32(SM0_ADDR), 0);
      cpu.writeUint32(SM0_INSTR, pioSET(PIO_DEST_Y, 0));
      cpu.writeUint32(SM0_INSTR, pioJMP(PIO_COND_NOTY, 8));
      expect(cpu.readUint32(SM0_ADDR), 8);
    });

    test('should correctly execute a `JMP Y--` instruction', () {
      resetStateMachines();
      cpu.writeUint32(SM0_PINCTRL, 32 << OUT_COUNT_SHIFT);
      expect(cpu.readUint32(SM0_ADDR), 0);
      cpu.writeUint32(SM0_INSTR, pioSET(PIO_DEST_Y, 15));
      cpu.writeUint32(SM0_INSTR, pioJMP(PIO_COND_YDEC, 12));
      expect(cpu.readUint32(SM0_ADDR), 12);
      // Y should be 14:
      cpu.writeUint32(SM0_INSTR, pioMOV(PIO_DEST_PINS, PIO_OP_NONE, PIO_SRC_Y));
      expect(cpu.readUint32(DBG_PADOUT), 14);
      // now set X to zero and ensure that we don't jump again
      cpu.writeUint32(SM0_INSTR, pioSET(PIO_DEST_Y, 0));
      cpu.writeUint32(SM0_INSTR, pioJMP(PIO_COND_YDEC, 6));
      expect(cpu.readUint32(SM0_ADDR), 12);
    });

    test('should correctly execute a `JMP X!=Y` instruction', () {
      resetStateMachines();
      cpu.writeUint32(SM0_PINCTRL, 32 << OUT_COUNT_SHIFT);
      expect(cpu.readUint32(SM0_ADDR), 0);
      cpu.writeUint32(SM0_INSTR, pioSET(PIO_DEST_X, 23));
      cpu.writeUint32(SM0_INSTR, pioSET(PIO_DEST_Y, 23));
      cpu.writeUint32(SM0_INSTR, pioJMP(PIO_COND_XNEY, 26));
      expect(cpu.readUint32(SM0_ADDR), 0);
      // Set X to a value different from Y:
      cpu.writeUint32(SM0_INSTR, pioSET(PIO_DEST_X, 3));
      cpu.writeUint32(SM0_INSTR, pioJMP(PIO_COND_XNEY, 26));
      expect(cpu.readUint32(SM0_ADDR), 26);
    });

    test('should correctly execute a `JMP OSRE` instruction', () {
      resetStateMachines();
      cpu.writeUint32(SM0_PINCTRL, 32 << OUT_COUNT_SHIFT);
      expect(cpu.readUint32(SM0_ADDR), 0);
      // The following command fills the OSR (Output Shift Register)
      cpu.writeUint32(
        SM0_INSTR,
        pioMOV(PIO_MOV_DEST_OSR, PIO_OP_NONE, PIO_SRC_NULL),
      );
      cpu.writeUint32(SM0_INSTR, pioJMP(PIO_COND_NOTEMPTYOSR, 11));
      expect(cpu.readUint32(SM0_ADDR), 11);
      // Now empty the OSR by shifting bits out of it, and observe that the JMP isn't taken
      cpu.writeUint32(SM0_INSTR, pioOUT(PIO_DEST_NULL, 32));
      cpu.writeUint32(SM0_INSTR, pioJMP(PIO_COND_NOTEMPTYOSR, 22));
      expect(cpu.readUint32(SM0_ADDR), 11);
    });

    test('should correctly execute a program with `PULL` instruction', () {
      resetStateMachines();
      cpu.writeUint32(SM0_PINCTRL, 32 << OUT_COUNT_SHIFT);
      cpu.writeUint32(TXF0, 0x42f00d43);
      expect(cpu.readUint32(FLEVEL), 1 << TX0_SHIFT); // TX0 should have 1 item
      cpu.writeUint32(SM0_INSTR, pioPULL(false, false));
      expect(
        cpu.readUint32(FLEVEL),
        0 << TX0_SHIFT,
      ); // TX0 should now have 0 items
      cpu.writeUint32(SM0_INSTR, pioOUT(PIO_DEST_PINS, 32));
      expect(cpu.readUint32(DBG_PADOUT), 0x42f00d43 & VALID_PINS_MASK);
    });

    test('should correctly execute the `OUT EXEC` instructions', () {
      resetStateMachines();
      cpu.writeUint32(SM0_PINCTRL, 32 << OUT_COUNT_SHIFT);
      cpu.writeUint32(TXF0, pioJMP(PIO_COND_ALWAYS, 16));
      cpu.writeUint32(SM0_INSTR, pioPULL(false, false));
      expect(cpu.readUint32(SM0_ADDR), 0);
      cpu.writeUint32(SM0_INSTR, pioOUT(PIO_DEST_EXEC, 32));
      expect(cpu.readUint32(SM0_ADDR), 16);
    });

    test('should correctly execute the `OUT PC` instruction', () {
      resetStateMachines();
      cpu.writeUint32(SM0_PINCTRL, 32 << OUT_COUNT_SHIFT);
      cpu.writeUint32(TXF0, 29);
      cpu.writeUint32(SM0_INSTR, pioPULL(false, false));
      expect(cpu.readUint32(SM0_ADDR), 0);
      cpu.writeUint32(SM0_INSTR, pioOUT(PIO_DEST_PC, 32));
      expect(cpu.readUint32(SM0_ADDR), 29);
    });

    test('should correctly execute a program with a `PUSH` instruction', () {
      resetStateMachines();
      expect(cpu.readUint32(FLEVEL), 0 << RX0_SHIFT); // RX0 should have 0 items
      cpu.writeUint32(SM0_INSTR, pioSET(PIO_DEST_X, 9));
      cpu.writeUint32(SM0_INSTR, pioIN(PIO_SRC_X, 32));
      cpu.writeUint32(SM0_INSTR, pioPUSH(false, false));
      expect(
        cpu.readUint32(FLEVEL),
        1 << RX0_SHIFT,
      ); // RX0 should now have 1 item
      cpu.writeUint32(SM0_INSTR, pioPUSH(false, false));
      expect(
        cpu.readUint32(FLEVEL),
        2 << RX0_SHIFT,
      ); // RX0 should now have 2 item
      expect(cpu.readUint32(RXF0), 9); // What we had in X
      expect(
        cpu.readUint32(FLEVEL),
        1 << RX0_SHIFT,
      ); // RX0 should now have 1 item
      expect(
        cpu.readUint32(RXF0),
        0,
      ); // ISR should be zeroed after the first push
      expect(cpu.readUint32(FLEVEL), 0 << RX0_SHIFT); // RX0 should have 0 items
    });

    test('should correctly execute a program with an `IRQ 2` instruction', () {
      resetStateMachines();
      cpu.writeUint32(IRQ, 0xff);
      cpu.writeUint32(SM0_INSTR, pioIRQ(false, false, 2));
      expect(cpu.readUint32(IRQ), 1 << 2);
      cpu.writeUint32(SM0_INSTR, pioIRQ(true, false, 2));
      expect(cpu.readUint32(IRQ), 0);
    });

    test(
      'should correctly execute a program with an `IRQ 3 rel` instruction',
      () {
        resetStateMachines();
        cpu.writeUint32(IRQ, 0xff);
        cpu.writeUint32(SM2_INSTR, pioIRQ(false, false, 0x13));
        expect(cpu.readUint32(IRQ), 1 << 1);
        cpu.writeUint32(SM2_INSTR, pioIRQ(true, false, 0x13));
        expect(cpu.readUint32(IRQ), 0);
        cpu.writeUint32(SM0_INSTR, pioIRQ(false, false, 0x13));
        expect(cpu.readUint32(IRQ), 1 << 3);
      },
    );

    test(
      'should correctly execute a program with an `WAIT IRQ 7` instruction',
      () {
        resetStateMachines();
        cpu.writeUint32(IRQ, 0xff);
        cpu.writeUint32(
          INSTR_MEM0,
          pioMOV(PIO_MOV_DEST_X, PIO_OP_NONE, PIO_SRC_X),
        );
        cpu.writeUint32(INSTR_MEM1, pioWAIT(true, PIO_WAIT_SRC_IRQ, 7));
        cpu.writeUint32(INSTR_MEM2, pioJMP(PIO_COND_ALWAYS, 2));
        cpu.writeUint32(CTRL, 1); // Starts State Machine #0
        expect(cpu.readUint32(SM0_ADDR), 1);
        cpu.writeUint32(SM2_INSTR, pioIRQ(false, false, 5)); // Set IRQ 5
        expect(cpu.readUint32(SM0_ADDR), 1);
        cpu.writeUint32(SM2_INSTR, pioIRQ(false, false, 7)); // Set IRQ 7
        expect(cpu.readUint32(SM0_ADDR), 2);
        expect(cpu.readUint32(IRQ), 1 << 5); // Wait should have cleared IRQ 7
      },
    );

    test(
      'should correctly execute a program with an `WAIT 0 IRQ 7` instruction',
      () {
        resetStateMachines();
        cpu.writeUint32(IRQ, 0xff);
        cpu.writeUint32(SM0_INSTR, pioIRQ(false, false, 7)); // Set IRQ 7
        cpu.writeUint32(
          INSTR_MEM0,
          pioMOV(PIO_MOV_DEST_X, PIO_OP_NONE, PIO_SRC_X),
        );
        cpu.writeUint32(INSTR_MEM1, pioWAIT(false, PIO_WAIT_SRC_IRQ, 7));
        cpu.writeUint32(INSTR_MEM2, pioJMP(PIO_COND_ALWAYS, 2));
        cpu.writeUint32(CTRL, 1); // Starts State Machine #0
        expect(cpu.readUint32(SM0_ADDR), 1);
        cpu.writeUint32(IRQ, 1 << 7); // Clear IRQ 7
        expect(cpu.readUint32(SM0_ADDR), 2);
      },
    );

    test('should update INTR after executing an `IRQ 2` instruction', () {
      resetStateMachines();
      cpu.writeUint32(IRQ, 0xff); // Clear all IRQs
      cpu.writeUint32(SM2_INSTR, pioIRQ(false, false, 0x2));
      expect(cpu.readUint32(INTR) & 0xf00, 1 << 10);
    });

    test(
      'should correctly compare X to 0xffffffff after executing a `mov x, ~null` instruction',
      () {
        resetStateMachines();
        cpu.writeUint32(TXF0, 0xffffffff);
        cpu.writeUint32(SM0_INSTR, pioPULL(false, false));
        cpu.writeUint32(
          SM0_INSTR,
          pioMOV(PIO_DEST_X, PIO_OP_INVERT, PIO_SRC_NULL),
        ); // X <- ~0 = 0xffffffff
        cpu.writeUint32(SM0_INSTR, pioOUT(PIO_DEST_Y, 32)); // Y <- 0xffffffff
        cpu.writeUint32(SM0_INSTR, pioJMP(PIO_COND_ALWAYS, 8));
        cpu.writeUint32(
          SM0_INSTR,
          pioJMP(PIO_COND_XNEY, 16),
        ); // Shouldn't take the jump
        expect(
          cpu.readUint32(SM0_ADDR),
          8,
        ); // Assert that the 2nd jump wasn't taken
      },
    );

    test('should wrap the program when it gets to EXECCTRL_WRAP_TOP', () {
      resetStateMachines();
      cpu.writeUint32(
        SM0_EXECCTRL,
        (1 << EXECCTRL_WRAP_BOTTOM_SHIFT) | (2 << EXECCTRL_WRAP_TOP_SHIFT),
      );

      // State machine Pseudo code:
      //   jmp .label2
      // .wrap_target
      // label1:
      //   jmp label1
      // label2:
      //   mov x, null
      // .wrap
      // label3:
      //   jmp label3

      cpu.writeUint32(INSTR_MEM0, pioJMP(PIO_COND_ALWAYS, 2));
      cpu.writeUint32(INSTR_MEM1, pioJMP(PIO_COND_ALWAYS, 1)); // infinite loop
      cpu.writeUint32(INSTR_MEM2, pioMOV(PIO_DEST_X, PIO_OP_NONE, PIO_SRC_X));
      cpu.writeUint32(INSTR_MEM3, pioJMP(PIO_COND_ALWAYS, 3)); // infinite loop

      cpu.writeUint32(CTRL, 1); // Starts State Machine #0
      expect(cpu.readUint32(SM0_ADDR), 1);
    });

    test('should automatically pull when Autopull is enabled', () {
      resetStateMachines();
      cpu.writeUint32(
        SM0_SHIFTCTRL,
        SHIFTCTRL_AUTOPULL | (4 << SHIFTCTRL_PULL_THRESH_SHIFT) | OUT_SHIFTDIR,
      );
      cpu.writeUint32(TXF0, 0x5);
      cpu.writeUint32(TXF0, 0x6);
      cpu.writeUint32(TXF0, 0x7);

      cpu.writeUint32(SM0_INSTR, pioOUT(PIO_DEST_X, 4)); // 5
      cpu.writeUint32(SM0_INSTR, pioIN(PIO_SRC_X, 4));
      cpu.writeUint32(SM0_INSTR, pioOUT(PIO_DEST_X, 4)); // 6
      cpu.writeUint32(SM0_INSTR, pioIN(PIO_SRC_X, 4));
      cpu.writeUint32(SM0_INSTR, pioOUT(PIO_DEST_X, 4)); // 7
      cpu.writeUint32(SM0_INSTR, pioIN(PIO_SRC_X, 4));
      cpu.writeUint32(SM0_INSTR, pioPUSH(false, false));

      expect(cpu.readUint32(RXF0), 0x567);
    });

    test('should not Autopull in the middle of OUT instruction', () {
      resetStateMachines();
      cpu.writeUint32(
        SM0_SHIFTCTRL,
        SHIFTCTRL_AUTOPULL | (4 << SHIFTCTRL_PULL_THRESH_SHIFT) | OUT_SHIFTDIR,
      );
      cpu.writeUint32(TXF0, 0x25);
      cpu.writeUint32(TXF0, 0x36);

      cpu.writeUint32(SM0_INSTR, pioOUT(PIO_DEST_X, 8));
      cpu.writeUint32(SM0_INSTR, pioIN(PIO_SRC_X, 8));
      cpu.writeUint32(SM0_INSTR, pioPUSH(false, false));

      expect(cpu.readUint32(RXF0), 0x25);
    });

    test(
      'should stall until the TX FIFO fills when executing an OUT instruction with Autopull',
      () {
        resetStateMachines();
        cpu.writeUint32(
          SM0_SHIFTCTRL,
          SHIFTCTRL_AUTOPULL |
              (4 << SHIFTCTRL_PULL_THRESH_SHIFT) |
              OUT_SHIFTDIR,
        );

        cpu.writeUint32(SM0_INSTR, pioOUT(PIO_DEST_X, 4));

        expect(
          cpu.readUint32(SM0_EXECCTRL) & EXECCTRL_EXEC_STALLED,
          EXECCTRL_EXEC_STALLED,
        );

        print('now writing to TXF0');
        cpu.writeUint32(TXF0, 0x36); // Unstalls the machine
        expect(cpu.readUint32(SM0_EXECCTRL) & EXECCTRL_EXEC_STALLED, 0);
      },
    );

    test('should automatically push when Autopush is enabled', () {
      resetStateMachines();
      cpu.writeUint32(
        SM0_SHIFTCTRL,
        SHIFTCTRL_AUTOPUSH | (8 << SHIFTCTRL_PUSH_THRESH_SHIFT) | OUT_SHIFTDIR,
      );

      cpu.writeUint32(SM0_INSTR, pioSET(PIO_DEST_X, 0x13));
      cpu.writeUint32(SM0_INSTR, pioIN(PIO_SRC_X, 8));

      expect(cpu.readUint32(RXF0), 0x13);
    });

    test('should only Autopush at the end the the IN instruction', () {
      resetStateMachines();
      cpu.writeUint32(
        SM0_SHIFTCTRL,
        SHIFTCTRL_AUTOPUSH | (8 << SHIFTCTRL_PUSH_THRESH_SHIFT) | OUT_SHIFTDIR,
      );

      cpu.writeUint32(
        SM0_INSTR,
        pioMOV(PIO_DEST_X, PIO_OP_INVERT, PIO_SRC_NULL),
      );
      cpu.writeUint32(SM0_INSTR, pioIN(PIO_SRC_X, 16));

      expect(cpu.readUint32(RXF0), 0xffff);
    });

    test(
      'should stall until the RX FIFO has capacity when executing an IN instruction with Autopush',
      () {
        resetStateMachines();
        cpu.writeUint32(
          SM0_SHIFTCTRL,
          SHIFTCTRL_AUTOPUSH |
              (8 << SHIFTCTRL_PUSH_THRESH_SHIFT) |
              OUT_SHIFTDIR,
        );

        cpu.writeUint32(SM0_INSTR, pioSET(PIO_DEST_X, 15));
        cpu.writeUint32(SM0_INSTR, pioIN(PIO_SRC_X, 8));
        cpu.writeUint32(SM0_INSTR, pioSET(PIO_DEST_X, 16));
        cpu.writeUint32(SM0_INSTR, pioIN(PIO_SRC_X, 8));
        cpu.writeUint32(SM0_INSTR, pioSET(PIO_DEST_X, 17));
        cpu.writeUint32(SM0_INSTR, pioIN(PIO_SRC_X, 8));
        cpu.writeUint32(SM0_INSTR, pioSET(PIO_DEST_X, 18));
        cpu.writeUint32(SM0_INSTR, pioIN(PIO_SRC_X, 8));
        cpu.writeUint32(SM0_INSTR, pioSET(PIO_DEST_X, 19));
        cpu.writeUint32(
          SM0_INSTR,
          pioIN(PIO_SRC_X, 8),
        ); // Should fill the RX FIFO and stall!

        expect(
          cpu.readUint32(SM0_EXECCTRL) & EXECCTRL_EXEC_STALLED,
          EXECCTRL_EXEC_STALLED,
        );

        expect(cpu.readUint16(RXF0), 15); // Unstalls the machine
        expect(cpu.readUint32(SM0_EXECCTRL) & EXECCTRL_EXEC_STALLED, 0);
        expect(cpu.readUint16(RXF0), 16);
        expect(cpu.readUint16(RXF0), 17);
        expect(cpu.readUint16(RXF0), 18);
        expect(cpu.readUint16(RXF0), 19);
      },
    );

    test(
      'should update TXNFULL flag in INTR according to the level of the TX FIFO (issue #73)',
      () {
        resetStateMachines();
        cpu.writeUint32(IRQ0_INTE, INTR_SM0_TXNFULL);
        expect(cpu.readUint32(INTR) & INTR_SM0_TXNFULL, INTR_SM0_TXNFULL);
        expect(cpu.readUint32(NVIC_ISPR) & PIO_IRQ0, PIO_IRQ0);
        cpu.writeUint32(TXF0, 1);
        cpu.writeUint32(TXF0, 2);
        cpu.writeUint32(TXF0, 3);
        cpu.writeUint32(NVIC_ICPR, PIO_IRQ0);
        expect(cpu.readUint32(INTR) & INTR_SM0_TXNFULL, INTR_SM0_TXNFULL);
        cpu.writeUint32(TXF0, 3);
        cpu.writeUint32(NVIC_ICPR, PIO_IRQ0);

        // At this point, TX FIFO should be full and the flag/interrupt will be cleared
        expect(cpu.readUint32(INTR) & INTR_SM0_TXNFULL, 0);
        expect(cpu.readUint32(NVIC_ISPR) & PIO_IRQ0, 0);

        // Pull an item, so TX FIFO should be "not empty" again
        cpu.writeUint32(SM0_INSTR, pioPULL(false, false));
        expect(cpu.readUint32(INTR) & INTR_SM0_TXNFULL, INTR_SM0_TXNFULL);
        expect(cpu.readUint32(NVIC_ISPR) & PIO_IRQ0, PIO_IRQ0);
      },
    );

    test(
      'should set TXSTALL flag in FDEBUG when trying to pull from an empty TX FIFO and only clear it after TX is no longer stalled',
      () {
        resetStateMachines();

        // Clear FDEBUG register
        cpu.writeUint32(FDEBUG, 0xffffffff);
        expect(cpu.readUint32(FDEBUG), 0);

        // Make sure TX FIFO is empty
        expect(cpu.readUint32(FLEVEL), 0 << TX0_SHIFT);

        // Attempt to pull from an empty TX FIFO
        cpu.writeUint32(SM0_INSTR, pioPULL(false, false));

        // Check that the TXSTALL flag is set
        expect(
          cpu.readUint32(FDEBUG) & (FDEBUG_TXSTALL << 0),
          FDEBUG_TXSTALL << 0,
        );

        // Try clearing the TXSTALL flag while TX FIFO is still empty
        cpu.writeUint32(FDEBUG, FDEBUG_TXSTALL << 0);

        // Verify the flag is NOT cleared because TX is still stalled
        expect(
          cpu.readUint32(FDEBUG) & (FDEBUG_TXSTALL << 0),
          FDEBUG_TXSTALL << 0,
        );

        // Push something to TX FIFO to unstall it
        cpu.writeUint32(TXF0, 42);

        // Now try clearing the flag again
        cpu.writeUint32(FDEBUG, FDEBUG_TXSTALL << 0);

        // Now the flag should be cleared
        expect(cpu.readUint32(FDEBUG) & (FDEBUG_TXSTALL << 0), 0);
      },
    );

    test(
      'should update RXFNEMPTY flag in INTR according to the level of the RX FIFO (issue #73)',
      () {
        resetStateMachines();
        cpu.writeUint32(IRQ0_INTE, INTR_SM0_RXNEMPTY);
        cpu.writeUint32(NVIC_ICPR, PIO_IRQ0);

        // RX FIFO starts empty
        expect(cpu.readUint32(INTR) & INTR_SM0_RXNEMPTY, 0);
        expect(cpu.readUint32(NVIC_ISPR) & PIO_IRQ0, 0);

        // Push an item so it's no longer empty...
        cpu.writeUint32(SM0_INSTR, pioPUSH(false, false));
        expect(cpu.readUint32(INTR) & INTR_SM0_RXNEMPTY, INTR_SM0_RXNEMPTY);
        expect(cpu.readUint32(NVIC_ISPR) & PIO_IRQ0, PIO_IRQ0);

        // Read the item and it should be empty again
        cpu.readUint32(RXF0);
        cpu.writeUint32(NVIC_ICPR, PIO_IRQ0);
        expect(cpu.readUint32(INTR) & INTR_SM0_RXNEMPTY, 0);
        expect(cpu.readUint32(NVIC_ISPR) & PIO_IRQ0, 0);
      },
    );
  });
}
