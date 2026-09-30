// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'dart:io';
import 'dart:typed_data';

import 'package:rp2040_dart/rp2040_dart.dart';
import 'package:rp2040_dart/src/rp2040.dart' show FLASH_START_ADDRESS;

const int MICROPYTHON_FS_FLASH_START = 0xa0000;
const int MICROPYTHON_FS_BLOCKSIZE = 4096;
const int MICROPYTHON_FS_BLOCKCOUNT = 352;

const int CIRCUITPYTHON_FS_FLASH_START = 0x100000;
const int CIRCUITPYTHON_FS_BLOCKSIZE = 4096;
const int CIRCUITPYTHON_FS_BLOCKCOUNT = 512;

void _loadFlashImage(
  String filename,
  RP2040 rp2040,
  int flashStart,
  int blockSize,
) {
  final file = File(filename).openSync();
  final buffer = Uint8List(blockSize);
  var flashAddress = flashStart;
  while (file.readIntoSync(buffer) == buffer.length) {
    rp2040.flash.setAll(flashAddress, buffer);
    flashAddress += buffer.length;
  }
  file.closeSync();
}

void loadMicropythonFlashImage(String filename, RP2040 rp2040) {
  _loadFlashImage(
    filename,
    rp2040,
    MICROPYTHON_FS_FLASH_START,
    MICROPYTHON_FS_BLOCKSIZE,
  );
}

void loadCircuitpythonFlashImage(String filename, RP2040 rp2040) {
  _loadFlashImage(
    filename,
    rp2040,
    CIRCUITPYTHON_FS_FLASH_START,
    CIRCUITPYTHON_FS_BLOCKSIZE,
  );
}

void loadUF2(String filename, RP2040 rp2040) {
  final file = File(filename).openSync();
  final buffer = Uint8List(512);
  while (file.readIntoSync(buffer) == buffer.length) {
    final block = decodeBlock(buffer);
    final flashAddress = block.flashAddress;
    final payload = block.payload;
    rp2040.flash.setAll(flashAddress - FLASH_START_ADDRESS, payload);
  }
  file.closeSync();
}

/*
 * A minimal UF2 block decoder, in place of the `uf2` npm package's
 * `decodeBlock()`. See https://github.com/microsoft/uf2 for the format.
 */

const int UF2_MAGIC_START0 = 0x0a324655; // "UF2\n"
const int UF2_MAGIC_START1 = 0x9e5d5157;
const int UF2_MAGIC_END = 0x0ab16f30;

const int UF2_FLAG_NOT_MAIN_FLASH = 0x00000001;
const int UF2_FLAG_FILE_CONTAINER = 0x00001000;
const int UF2_FLAG_FAMILY_ID_PRESENT = 0x00002000;
const int UF2_FLAG_MD5_PRESENT = 0x00004000;

class UF2DecodeError implements Exception {
  final String message;

  UF2DecodeError(this.message);

  @override
  String toString() => 'UF2DecodeError: $message';
}

class UF2BlockData {
  final int flags;
  final int flashAddress;
  final Uint8List payload;
  final int blockNumber;
  final int totalBlocks;
  final int boardFamily;

  UF2BlockData({
    required this.flags,
    required this.flashAddress,
    required this.payload,
    required this.blockNumber,
    required this.totalBlocks,
    required this.boardFamily,
  });
}

/// Decodes one 512-byte UF2 block: magic numbers at 0, 4 and 508, flags at 8,
/// target address at 12, payload size at 16, block number at 20, block count
/// at 24, family ID (or file size) at 28 and up to 476 bytes of data at 32.
UF2BlockData decodeBlock(Uint8List block) {
  if (block.length != 512) {
    throw UF2DecodeError('Invalid UF2 block size: ${block.length}');
  }
  final view = ByteData.sublistView(block);
  if (view.getUint32(0, Endian.little) != UF2_MAGIC_START0 ||
      view.getUint32(4, Endian.little) != UF2_MAGIC_START1) {
    throw UF2DecodeError('Invalid magic value');
  }
  if (view.getUint32(508, Endian.little) != UF2_MAGIC_END) {
    throw UF2DecodeError('Invalid magic end value');
  }
  final flags = view.getUint32(8, Endian.little);
  final payloadSize = view.getUint32(16, Endian.little);
  if (payloadSize > 476) {
    throw UF2DecodeError('Invalid payload size: $payloadSize');
  }
  return UF2BlockData(
    flags: flags,
    flashAddress: view.getUint32(12, Endian.little),
    payload: block.sublist(32, 32 + payloadSize),
    blockNumber: view.getUint32(20, Endian.little),
    totalBlocks: view.getUint32(24, Endian.little),
    boardFamily: flags & UF2_FLAG_FAMILY_ID_PRESENT != 0
        ? view.getUint32(28, Endian.little)
        : 0,
  );
}
