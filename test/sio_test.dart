// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'package:rp2040_dart/src/rp2040.dart';
import 'package:test/test.dart';

import 'test_utils/create_test_driver.dart';
import 'test_utils/test_driver.dart';

//Hardware Divider registers absolute address
const int SIO_DIV_UDIVIDEND =
    SIO_START_ADDRESS + 0x060; //  Divider unsigned dividend
const int SIO_DIV_UDIVISOR =
    SIO_START_ADDRESS + 0x064; //  Divider unsigned divisor
const int SIO_DIV_SDIVIDEND =
    SIO_START_ADDRESS + 0x068; //  Divider signed dividend
const int SIO_DIV_SDIVISOR =
    SIO_START_ADDRESS + 0x06c; //  Divider signed divisor
const int SIO_DIV_QUOTIENT =
    SIO_START_ADDRESS + 0x070; //  Divider result quotient
const int SIO_DIV_REMAINDER =
    SIO_START_ADDRESS + 0x074; //Divider result remainder
const int SIO_DIV_CSR = SIO_START_ADDRESS + 0x078;

//SPINLOCK
const int SIO_SPINLOCK10 = SIO_START_ADDRESS + 0x128;
const int SIO_SPINLOCKST = SIO_START_ADDRESS + 0x5c;

void main() {
  group('RPSIO', () {
    late ICortexTestDriver cpu;

    setUp(() {
      cpu = createTestDriver();
    });

    tearDown(() {
      cpu.tearDown();
    });

    group('Hardware Divider', () {
      test(
        'should perform a signed hardware divider 123456 / -321 = -384 REM 192',
        () {
          cpu.writeUint32(SIO_DIV_SDIVIDEND, 123456);
          expect(cpu.readInt32(SIO_DIV_SDIVIDEND), 123456);
          cpu.writeUint32(SIO_DIV_SDIVISOR, -321);
          expect(cpu.readUint32(SIO_DIV_CSR), 3);
          expect(cpu.readInt32(SIO_DIV_SDIVISOR), -321);
          expect(cpu.readInt32(SIO_DIV_REMAINDER), 192);
          expect(cpu.readInt32(SIO_DIV_QUOTIENT), -384);
          expect(cpu.readUint32(SIO_DIV_CSR), 1);
        },
      );

      test(
        'should perform a signed hardware divider -3000 / 2 = -1500 REM 0',
        () {
          cpu.writeUint32(SIO_DIV_SDIVIDEND, -3000);
          expect(cpu.readInt32(SIO_DIV_SDIVIDEND), -3000);
          cpu.writeUint32(SIO_DIV_SDIVISOR, 2);
          expect(cpu.readUint32(SIO_DIV_CSR), 3);
          expect(cpu.readInt32(SIO_DIV_SDIVISOR), 2);
          expect(cpu.readInt32(SIO_DIV_REMAINDER), 0);
          expect(cpu.readInt32(SIO_DIV_QUOTIENT), -1500);
          expect(cpu.readUint32(SIO_DIV_CSR), 1);
        },
      );

      test(
        'should perform an unsigned hardware divider 123456 / 321 = 384 REM 192',
        () {
          cpu.writeUint32(SIO_DIV_UDIVIDEND, 123456);
          cpu.writeUint32(SIO_DIV_UDIVISOR, 321);
          expect(cpu.readUint32(SIO_DIV_CSR), 3);
          expect(cpu.readUint32(SIO_DIV_REMAINDER), 192);
          expect(cpu.readUint32(SIO_DIV_QUOTIENT), 384);
          expect(cpu.readUint32(SIO_DIV_CSR), 1);
        },
      );

      test(
        'should perform a division, store the result, do another division then restore the previously stored result ',
        () {
          cpu.writeUint32(SIO_DIV_SDIVIDEND, 123456);
          cpu.writeUint32(SIO_DIV_SDIVISOR, -321);
          final remainder = cpu.readInt32(SIO_DIV_REMAINDER);
          final quotient = cpu.readInt32(SIO_DIV_QUOTIENT);
          expect(remainder, 192);
          expect(quotient, -384);
          cpu.writeUint32(SIO_DIV_UDIVIDEND, 123);
          cpu.writeUint32(SIO_DIV_UDIVISOR, 7);
          expect(cpu.readUint32(SIO_DIV_REMAINDER), 4);
          expect(cpu.readUint32(SIO_DIV_QUOTIENT), 17);
          cpu.writeUint32(SIO_DIV_REMAINDER, remainder);
          cpu.writeUint32(SIO_DIV_QUOTIENT, quotient);
          expect(cpu.readUint32(SIO_DIV_CSR), 3);
          expect(cpu.readInt32(SIO_DIV_REMAINDER), 192);
          expect(cpu.readInt32(SIO_DIV_QUOTIENT), -384);
        },
      );

      test(
        'should perform an unsigned division by zero 123456 / 0 = 0xffffffff REM 123456',
        () {
          cpu.writeUint32(SIO_DIV_UDIVIDEND, 123456);
          cpu.writeUint32(SIO_DIV_UDIVISOR, 0);
          expect(cpu.readUint32(SIO_DIV_REMAINDER), 123456);
          expect(cpu.readUint32(SIO_DIV_QUOTIENT), 0xffffffff);
        },
      );

      test(
        'should perform an unsigned division by zero 0x80000000 / 0 = 0xffffffff REM 0x80000000',
        () {
          cpu.writeUint32(SIO_DIV_UDIVIDEND, 0x80000000);
          cpu.writeUint32(SIO_DIV_UDIVISOR, 0);
          expect(cpu.readUint32(SIO_DIV_REMAINDER), 0x80000000);
          expect(cpu.readUint32(SIO_DIV_QUOTIENT), 0xffffffff);
        },
      );

      test(
        'should perform a signed division by zero 3000 / 0 = -1 REM 3000',
        () {
          cpu.writeUint32(SIO_DIV_SDIVIDEND, 3000);
          cpu.writeUint32(SIO_DIV_SDIVISOR, 0);
          expect(cpu.readInt32(SIO_DIV_REMAINDER), 3000);
          expect(cpu.readInt32(SIO_DIV_QUOTIENT), -1);
        },
      );

      test(
        'should perform a signed division by zero -3000 / 0 = 1 REM -3000',
        () {
          cpu.writeUint32(SIO_DIV_SDIVIDEND, -3000);
          cpu.writeUint32(SIO_DIV_SDIVISOR, 0);
          expect(cpu.readInt32(SIO_DIV_REMAINDER), -3000);
          expect(cpu.readInt32(SIO_DIV_QUOTIENT), 1);
        },
      );

      test(
        'should perform a signed division 0x80000000 / 2 = 0xc0000000 REM 0',
        () {
          cpu.writeUint32(SIO_DIV_SDIVIDEND, 0x80000000);
          cpu.writeUint32(SIO_DIV_SDIVISOR, 2);
          expect(cpu.readUint32(SIO_DIV_REMAINDER), 0);
          expect(cpu.readUint32(SIO_DIV_QUOTIENT), 0xc0000000);
        },
      );

      test(
        'should perform an unsigned division 0x80000000 / 2 = 0x40000000 REM 0',
        () {
          cpu.writeUint32(SIO_DIV_UDIVIDEND, 0x80000000);
          cpu.writeUint32(SIO_DIV_UDIVISOR, 2);
          expect(cpu.readUint32(SIO_DIV_REMAINDER), 0);
          expect(cpu.readUint32(SIO_DIV_QUOTIENT), 0x40000000);
        },
      );
    });

    test('should unlock, lock and check lock status of spinlock10', () {
      cpu.writeUint32(
        SIO_SPINLOCK10,
        0x00000001,
      ); //ensure the spinlock is released
      expect(
        cpu.readUint32(SIO_SPINLOCK10),
        1024,
      ); // lock spinlock, return 1<<spinlock num if previously unlocked
      expect(
        cpu.readUint32(SIO_SPINLOCKST),
        1024,
      ); //bit mask of all spinlocks, locked=1<<spinlock
      expect(cpu.readUint32(SIO_SPINLOCK10), 0); //0=already locked
      expect(cpu.readUint32(SIO_SPINLOCKST), 1024);
      cpu.writeUint32(SIO_SPINLOCK10, 0x00000001); //release the spinlock
      expect(cpu.readUint32(SIO_SPINLOCKST), 0);
    });
  });
}
