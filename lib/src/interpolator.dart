// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'utils/bit.dart';

// Dart port note: every intermediate below is kept as an unsigned 32-bit
// value, where rp2040js lets `|`, `&` and `<<` produce signed int32s. The
// results are the same modulo 2^32; signed comparisons go through `s32()`.

class InterpolatorConfig {
  int shift = 0;
  int maskLSB = 0;
  int maskMSB = 0;
  bool signed = false;
  bool crossInput = false;
  bool crossResult = false;
  bool addRaw = false;
  int forceMSB = 0;
  bool blend = false;
  bool clamp = false;
  bool overf0 = false;
  bool overf1 = false;
  bool overf = false;

  InterpolatorConfig(int value) {
    value = u32(value);
    shift = (value >>> 0) & 0x1f;
    maskLSB = (value >>> 5) & 0x1f;
    maskMSB = (value >>> 10) & 0x1f;
    signed = (value >>> 15) & 1 != 0;
    crossInput = (value >>> 16) & 1 != 0;
    crossResult = (value >>> 17) & 1 != 0;
    addRaw = (value >>> 18) & 1 != 0;
    forceMSB = (value >>> 19) & 0x3;
    blend = (value >>> 21) & 1 != 0;
    clamp = (value >>> 22) & 1 != 0;
    overf0 = (value >>> 23) & 1 != 0;
    overf1 = (value >>> 24) & 1 != 0;
    overf = (value >>> 25) & 1 != 0;
  }

  int toUint32() {
    return ((shift & 0x1f) << 0) |
        ((maskLSB & 0x1f) << 5) |
        ((maskMSB & 0x1f) << 10) |
        ((signed ? 1 : 0) << 15) |
        ((crossInput ? 1 : 0) << 16) |
        ((crossResult ? 1 : 0) << 17) |
        ((addRaw ? 1 : 0) << 18) |
        ((forceMSB & 0x3) << 19) |
        ((blend ? 1 : 0) << 21) |
        ((clamp ? 1 : 0) << 22) |
        ((overf0 ? 1 : 0) << 23) |
        ((overf1 ? 1 : 0) << 24) |
        ((overf ? 1 : 0) << 25);
  }
}

class Interpolator {
  int accum0 = 0;
  int accum1 = 0;
  int base0 = 0;
  int base1 = 0;
  int base2 = 0;
  int ctrl0 = 0;
  int ctrl1 = 0;
  int result0 = 0;
  int result1 = 0;
  int result2 = 0;
  int smresult0 = 0;
  int smresult1 = 0;

  final int _index;

  Interpolator(this._index) {
    update();
  }

  void update() {
    final N = _index;
    final ctrl0 = InterpolatorConfig(this.ctrl0);
    final ctrl1 = InterpolatorConfig(this.ctrl1);

    final do_clamp = ctrl0.clamp && N == 1;
    final do_blend = ctrl0.blend && N == 0;

    ctrl0.clamp = do_clamp;
    ctrl0.blend = do_blend;
    ctrl1.clamp = false;
    ctrl1.blend = false;
    ctrl1.overf0 = false;
    ctrl1.overf1 = false;
    ctrl1.overf = false;

    final input0 = s32(ctrl0.crossInput ? accum1 : accum0);
    final input1 = s32(ctrl1.crossInput ? accum0 : accum1);

    final msbmask0 = ctrl0.maskMSB == 31
        ? 0xffffffff
        : (1 << (ctrl0.maskMSB + 1)) - 1;
    final msbmask1 = ctrl1.maskMSB == 31
        ? 0xffffffff
        : (1 << (ctrl1.maskMSB + 1)) - 1;
    final mask0 = msbmask0 & u32(~((1 << ctrl0.maskLSB) - 1));
    final mask1 = msbmask1 & u32(~((1 << ctrl1.maskLSB) - 1));

    final uresult0 = (u32(input0) >>> ctrl0.shift) & mask0;
    final uresult1 = (u32(input1) >>> ctrl1.shift) & mask1;

    final overf0 = (u32(input0) >>> ctrl0.shift) & u32(~msbmask0) != 0;
    final overf1 = (u32(input1) >>> ctrl1.shift) & u32(~msbmask1) != 0;
    final overf = overf0 || overf1;

    final sextmask0 = uresult0 & (1 << ctrl0.maskMSB) != 0
        ? u32(0xffffffff << ctrl0.maskMSB)
        : 0;
    final sextmask1 = uresult1 & (1 << ctrl1.maskMSB) != 0
        ? u32(0xffffffff << ctrl1.maskMSB)
        : 0;

    final sresult0 = uresult0 | sextmask0;
    final sresult1 = uresult1 | sextmask1;

    final result0 = ctrl0.signed ? sresult0 : uresult0;
    final result1 = ctrl1.signed ? sresult1 : uresult1;

    final addresult0 = u32(base0 + (ctrl0.addRaw ? u32(input0) : result0));
    final addresult1 = u32(base1 + (ctrl1.addRaw ? u32(input1) : result1));
    final addresult2 = u32(base2 + result0 + (do_blend ? 0 : result1));

    final uclamp0 = u32(result0) < u32(base0)
        ? base0
        : u32(result0) > u32(base1)
        ? base1
        : result0;
    final sclamp0 = s32(result0) < s32(base0)
        ? base0
        : s32(result0) > s32(base1)
        ? base1
        : result0;
    final clamp0 = ctrl0.signed ? sclamp0 : uclamp0;

    final alpha1 = result1 & 0xff;
    // The products stay below 2^40, so the double arithmetic is exact on
    // every platform, as it is in rp2040js.
    final ublend1 = u32(
      u32(base0) + s32(((alpha1 * (u32(base1) - u32(base0))) / 256).floor()),
    );
    final sblend1 = u32(
      s32(base0) + s32(((alpha1 * (s32(base1) - s32(base0))) / 256).floor()),
    );
    final blend1 = ctrl1.signed ? sblend1 : ublend1;

    smresult0 = u32(result0);
    smresult1 = u32(result1);
    this.result0 = u32(
      do_blend
          ? alpha1
          : (do_clamp ? clamp0 : addresult0) | (ctrl0.forceMSB << 28),
    );
    this.result1 = u32(
      (do_blend ? blend1 : addresult1) | (ctrl0.forceMSB << 28),
    );
    result2 = u32(addresult2);

    ctrl0.overf0 = overf0;
    ctrl0.overf1 = overf1;
    ctrl0.overf = overf;
    this.ctrl0 = ctrl0.toUint32();
    this.ctrl1 = ctrl1.toUint32();
  }

  void writeback() {
    final ctrl0 = InterpolatorConfig(this.ctrl0);
    final ctrl1 = InterpolatorConfig(this.ctrl1);

    accum0 = u32(ctrl0.crossResult ? result1 : result0);
    accum1 = u32(ctrl1.crossResult ? result0 : result1);

    update();
  }

  void setBase01(int value) {
    final N = _index;
    final ctrl0 = InterpolatorConfig(this.ctrl0);
    final ctrl1 = InterpolatorConfig(this.ctrl1);

    final do_blend = ctrl0.blend && N == 0;

    final input0 = value & 0xffff;
    final input1 = (u32(value) >>> 16) & 0xffff;

    final sextmask0 = input0 & (1 << 15) != 0 ? u32(0xffffffff << 15) : 0;
    final sextmask1 = input1 & (1 << 15) != 0 ? u32(0xffffffff << 15) : 0;

    final base0 = (do_blend ? ctrl1.signed : ctrl0.signed)
        ? input0 | sextmask0
        : input0;
    final base1 = ctrl1.signed ? input1 | sextmask1 : input1;

    this.base0 = u32(base0);
    this.base1 = u32(base1);

    update();
  }
}
