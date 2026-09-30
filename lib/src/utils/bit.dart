// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

/// 32-bit helpers. See PORTING.md, "Numbers": every 32-bit value is kept as
/// an unsigned int in `[0, 0xFFFFFFFF]` on every platform.
library;

int bit(int n) => u32(1 << n);

/// TS `n | 0`: the value as a signed 32-bit integer.
int s32(int n) => n.toSigned(32);

/// TS `n >>> 0`: the value as an unsigned 32-bit integer.
int u32(int n) => n & 0xffffffff;

/// TS `Math.imul(a, b)`, as an unsigned 32-bit result.
///
/// Split into 16-bit halves so no intermediate exceeds 2^53: a plain `a * b`
/// of two 32-bit values loses its low bits when compiled to JavaScript.
int imul(int a, int b) {
  a = u32(a);
  b = u32(b);
  final aLow = a & 0xffff;
  final aHigh = a >>> 16;
  return u32(aLow * b + u32((aHigh * b) & 0xffff) * 0x10000);
}
