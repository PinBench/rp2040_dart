// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'package:rp2040_dart/src/clock/mock_clock.dart';
import 'package:rp2040_dart/src/rp2040.dart';
import 'package:test/test.dart';

const PWM_BASE = 0x40050000;
const CH0_CSR = PWM_BASE + 0x00;
const CH0_CTR = PWM_BASE + 0x08;
const CH0_TOP = PWM_BASE + 0x10;
const PWM_INTR = PWM_BASE + 0xa4;

const ATOMIC_SET = 0x2000;

/* CH0_CSR bits */
const CSR_PH_ADV = 1 << 7;
const CSR_PH_RET = 1 << 6;
const CSR_EN = 1 << 0;

void main() {
  group('RPPWM', () {
    group('PH_ADV / PH_RET', () {
      test('should advance the counter by 1 when setting the PH_ADV bit', () {
        final rp2040 = RP2040(MockClock());
        rp2040.writeUint32(CH0_CSR, CSR_EN);
        rp2040.writeUint32(CH0_CTR, 10);
        // pwm_advance_count() sets the bit through the atomic set alias
        rp2040.writeUint32(CH0_CSR | ATOMIC_SET, CSR_PH_ADV);
        expect(rp2040.readUint32(CH0_CTR), 11);
      });

      test('should retard the counter by 1 when setting the PH_RET bit', () {
        final rp2040 = RP2040(MockClock());
        rp2040.writeUint32(CH0_CSR, CSR_EN);
        rp2040.writeUint32(CH0_CTR, 10);
        rp2040.writeUint32(CH0_CSR | ATOMIC_SET, CSR_PH_RET);
        expect(rp2040.readUint32(CH0_CTR), 9);
      });

      test('should self-clear the PH_ADV and PH_RET bits', () {
        // pwm_advance_count() polls the bit until it reads back as zero
        final rp2040 = RP2040(MockClock());
        rp2040.writeUint32(CH0_CSR, CSR_EN | CSR_PH_ADV | CSR_PH_RET);
        expect(rp2040.readUint32(CH0_CSR) & (CSR_PH_ADV | CSR_PH_RET), 0);
      });

      test(
        'should wrap around to TOP when retarding the counter past zero',
        () {
          final rp2040 = RP2040(MockClock());
          rp2040.writeUint32(CH0_CSR, CSR_EN);
          rp2040.writeUint32(CH0_CTR, 0);
          rp2040.writeUint32(CH0_CSR | ATOMIC_SET, CSR_PH_RET);
          expect(rp2040.readUint32(CH0_CTR), 0xffff);
        },
      );

      test('should not change the counter when the channel is not running', () {
        // Both bits are documented as acting on a running counter
        final rp2040 = RP2040(MockClock());
        rp2040.writeUint32(CH0_CTR, 10);
        rp2040.writeUint32(CH0_CSR | ATOMIC_SET, CSR_PH_ADV);
        expect(rp2040.readUint32(CH0_CTR), 10);
      });

      test(
        'should apply the advance when EN and PH_ADV are set in the same write',
        () {
          final rp2040 = RP2040(MockClock());
          rp2040.writeUint32(CH0_CSR, CSR_EN);
          rp2040.writeUint32(CH0_CTR, 10);
          rp2040.writeUint32(CH0_CSR, 0);
          rp2040.writeUint32(CH0_CSR, CSR_EN | CSR_PH_ADV);
          expect(rp2040.readUint32(CH0_CTR), 11);
        },
      );

      test('should not advance the counter on the write that clears EN', () {
        final rp2040 = RP2040(MockClock());
        rp2040.writeUint32(CH0_CSR, CSR_EN);
        rp2040.writeUint32(CH0_CTR, 10);
        rp2040.writeUint32(CH0_CSR, CSR_PH_ADV);
        expect(rp2040.readUint32(CH0_CTR), 10);
      });

      test(
        'should bring the wrap interrupt forward by one cycle when advancing',
        () {
          final clock = MockClock();
          final rp2040 = RP2040(clock);
          rp2040.writeUint32(CH0_TOP, 999);
          rp2040.writeUint32(CH0_CSR, CSR_EN);
          rp2040.writeUint32(CH0_CTR, 0);
          rp2040.writeUint32(CH0_CSR | ATOMIC_SET, CSR_PH_ADV);
          // 1000 cycles at 125MHz is 8000ns, so the advance should pull the wrap in to 7992ns
          clock.tick(7991);
          expect(rp2040.readUint32(PWM_INTR) & 1, 0);
          clock.tick(1);
          expect(rp2040.readUint32(PWM_INTR) & 1, 1);
        },
      );
    });
  });
}
