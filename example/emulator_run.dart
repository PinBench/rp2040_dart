// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'dart:io';

import 'package:rp2040_dart/bootrom.dart';
import 'package:rp2040_dart/gdb_tcp_server.dart';
import 'package:rp2040_dart/rp2040_dart.dart';

import 'intelhex.dart';
import 'load_flash.dart';

/// A tiny stand-in for `minimist`: `--name value`, `--name=value`, `--flag`.
Map<String, Object> _parseArgs(
  List<String> arguments, {
  Set<String> strings = const {},
  Set<String> booleans = const {},
}) {
  final result = <String, Object>{};
  for (var i = 0; i < arguments.length; i++) {
    final arg = arguments[i];
    if (!arg.startsWith('--')) {
      continue;
    }
    final eq = arg.indexOf('=');
    final name = eq < 0 ? arg.substring(2) : arg.substring(2, eq);
    if (booleans.contains(name)) {
      result[name] = eq < 0 || arg.substring(eq + 1) != 'false';
    } else if (eq >= 0) {
      result[name] = arg.substring(eq + 1);
    } else if (i + 1 < arguments.length && !arguments[i + 1].startsWith('--')) {
      result[name] = arguments[++i];
    } else {
      result[name] = strings.contains(name) ? '' : true;
    }
  }
  return result;
}

void main(List<String> arguments) {
  final args = _parseArgs(
    arguments,
    strings: {
      'image', // An image to load, hex and UF2 are supported
    },
  );

  final simulator = Simulator();
  final mcu = simulator.rp2040;
  mcu.loadBootrom(bootromB1);

  final imageName = args['image'] as String? ?? 'hello_uart.hex';

  // Check the extension of the file
  final extension = imageName.split('.').last;
  if (extension == 'hex') {
    // Create an array with the compiled code of blink
    // Execute the instructions from this array, one by one.
    final hex = File(imageName).readAsStringSync();

    print('Loading hex image $imageName');
    loadHex(hex, mcu.flash, 0x10000000);
  } else if (extension == 'uf2') {
    print('Loading uf2 image $imageName');
    loadUF2(imageName, mcu);
  } else {
    print('Unsupported file type: $extension');
    exit(1);
  }

  final gdbServer = GDBTCPServer(simulator, 3333);
  print('RP2040 GDB Server ready! Listening on port ${gdbServer.port}');

  mcu.uart[0].onByte = (value) {
    stdout.add([value]);
  };

  simulator.rp2040.core.PC = 0x10000000;
  simulator.execute();
}
