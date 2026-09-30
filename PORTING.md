# Porting rules: rp2040js → rp2040_dart

The port follows **rp2040js v1.4.0** (commit `a304c74`, 2026-09-25). A copy
of that source is in `reference/` (git-ignored; recreate it with
`git clone https://github.com/wokwi/rp2040js reference && git -C reference checkout a304c74`).

The goal is a **faithful, line-by-line port**: same classes, same member
names, same structure, same comments, so a change upstream can be carried
over by reading the two side by side. Optimise later, separately, with the
tests and a benchmark as the safety net.

## Files

| rp2040js | rp2040_dart |
| --- | --- |
| `src/foo-bar.ts` | `lib/src/foo_bar.dart` |
| `src/peripherals/foo.ts` | `lib/src/peripherals/foo.dart` |
| `src/x/foo.spec.ts` | `test/x/foo_test.dart` (top-level specs in `test/`) |
| `test-utils/*.ts` | `test/test_utils/*.dart` (the RP2040 driver only; no GDB driver) |
| `demo/*.ts` | `example/*.dart` (`bootrom.ts` → `lib/src/bootrom.dart`) |
| `src/index.ts` | `lib/rp2040_dart.dart` |

One Dart library per TS module. Import siblings relatively
(`import '../rp2040.dart';`).

## Numbers: the one thing to get right

TypeScript numbers are doubles, and its bitwise operators work on **32-bit**
values: `|`, `&`, `^`, `~`, `<<`, `>>` produce a *signed* int32, `>>>` an
unsigned one, and shift counts are taken mod 32. Dart `int` is 64-bit on the
VM and in Wasm, and a double under dart2js. The same Dart must give the same
answer on all three, so:

1. **Every 32-bit register, bus and memory value is an unsigned Dart `int` in
   `[0, 0xFFFFFFFF]`**, whatever the TS left it as. Store it that way; a
   `Uint32List` does it for you.
2. **Mask whenever an operation can leave that range**: `<<`, `~`, `+`, `-`,
   `*`, or `|`/`^` with anything negative. Use `u32(x)` (`x & 0xFFFFFFFF`)
   from `lib/src/utils/bit.dart`. `&` with a mask below 2³², `>>` and `>>>`
   of an in-range value cannot leave the range and need no mask.
3. **Signed semantics are explicit.** TS `x | 0` → `s32(x)`. TS `x >> n`
   on a value that may have bit 31 set → `u32(s32(x) >> n)` (arithmetic
   shift). Sign extension: `signExtend8/16` helpers, or `x.toSigned(8)`.
   A TS comparison that relies on a value being negative int32
   (`(a | 0) < 0`, `a < b` where either came from `|`/`<<`) → compare
   `s32(...)` values.
4. **`Math.imul(a, b)` → `imul(a, b)`** (never a raw `*` of two 32-bit
   values: under dart2js the product exceeds 2⁵³ and loses bits).
5. **Shift counts.** JS takes them mod 32 (`x << 32 === x`); Dart does not.
   Where the count can be ≥ 32, write what the TS actually does
   (`x << (n & 31)`), and check the TS: the CPU core often handles ≥ 32 on
   purpose.
6. **`>>> 0` / `u32()` in the TS** → `u32()` in Dart (or drop it where the
   value is provably in range already).
7. **Time and frequency are `double`** (nanoseconds are fractional:
   `1e9 / 133e6`). Register values, counts, addresses and indices are `int`.
   `Math.floor(x)` → `x.floor()`, `Math.round` → `.round()`,
   `Math.min/max` → `math.min/max` (`dart:math`).

## Types and idioms

- `Uint8Array`/`Uint16Array`/`Uint32Array`/`Int32Array` → `Uint8List`/…
  (`dart:typed_data`). `new DataView(a.buffer)` → `ByteData.view(a.buffer)`;
  `getUint32(o, true)` → `getUint32(o, Endian.little)` (always pass the
  endianness: Dart defaults to **big**-endian). `a.set(b, o)` →
  `a.setAll(o, b)`; `a.fill(v)` → `a.fillRange(0, a.length, v)`;
  `a.subarray(s, e)` → `Uint8List.sublistView(a, s, e)` (a view, like
  subarray); `slice` → `sublist` (a copy).
- **No `late` fields in anything the CPU touches per instruction** (a `late`
  field costs a check on every read). Initialise in the declaration or the
  initializer list.
- TS numeric `enum`s used as numbers → `abstract final class X { static const int A = 0; ... }`.
  Enums only compared, never used as numbers → a Dart `enum`.
- `interface` → `abstract interface class`; `type X = (...) => void` →
  `typedef X = void Function(...)`.
- Arrow-function properties (`onBreak = (code: number) => {}`) → function-typed
  fields with a default: `void Function(int code) onBreak = (_) {};`.
- `readonly` → `final`. `private foo` → `_foo`, unless another file (or a
  test) uses it: then keep it public. `protected` → public.
- Optional/nullable (`x?: T`, `T | null`) → `T?`. `undefined` and `null` →
  `null`.
- `console.log/warn/error` → go through the `Logger` where the TS does;
  elsewhere `print`.
- `Set`/`Map`/arrays → `Set`/`Map`/`List`. `for (const x of xs)` → `for (final x in xs)`.
- Strings: `x.toString(16)` → `x.toRadixString(16)`; template literals →
  Dart interpolation.
- Async: only where the TS genuinely awaits I/O. The test driver is
  synchronous in Dart.
- Keep the upstream comments, and the SPDX header on every file:

  ```dart
  // SPDX-License-Identifier: MIT
  // Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench
  ```

## Tests

- `vitest` → `package:test`: `describe` → `group`, `it` → `test`,
  `beforeEach`/`afterEach` → `setUp`/`tearDown`,
  `expect(a).toEqual(b)`/`toBe(b)` → `expect(a, b)`.
- `vi.fn()` / `vi.spyOn` → a small hand-written fake that records calls
  (no mocking package).
- Port **every** spec case, with the same names, so the suites can be
  compared by count. A case that cannot pass yet stays, marked
  `skip: 'reason'`.
- Run `dart test` (VM). Before release the suite also runs compiled to JS
  (`dart test -p node`) and Wasm, which is what catches a missed `u32`.
