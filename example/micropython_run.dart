// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'dart:io';

import 'package:rp2040_dart/bootrom.dart';
import 'package:rp2040_dart/gdb_tcp_server.dart';
import 'package:rp2040_dart/rp2040_dart.dart';

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
      'image', // UF2 image to load; defaults to "RPI_PICO-20230426-v1.20.0.uf2"
      'expect-text', // Text to expect on the serial console, process will exit with code 0 if found
    },
    booleans: {
      'gdb', // start GDB server on 3333
      'circuitpython', // use CircuitPython instead of MicroPython
    },
  );
  final expectText = args['expect-text'] as String?;
  final circuitpython = args['circuitpython'] == true;

  final simulator = Simulator();
  final mcu = simulator.rp2040;
  mcu.loadBootrom(bootromB1);
  mcu.logger = ConsoleLogger(LogLevel.Error);

  String imageName;
  if (!circuitpython) {
    imageName = args['image'] as String? ?? 'RPI_PICO-20230426-v1.20.0.uf2';
  } else {
    imageName =
        args['image'] as String? ??
        'adafruit-circuitpython-raspberry_pi_pico-en_US-8.0.2.uf2';
  }
  print('Loading uf2 image $imageName');
  loadUF2(imageName, mcu);

  if (File('littlefs.img').existsSync() && !circuitpython) {
    print('Loading uf2 image littlefs.img');
    loadMicropythonFlashImage('littlefs.img', mcu);
  } else if (File('fat12.img').existsSync() && circuitpython) {
    loadCircuitpythonFlashImage('fat12.img', mcu);
    // Instead of reading from file, it would also be possible to generate the LittleFS image on-the-fly here, e.g. using
    // https://github.com/wokwi/littlefs-wasm or https://github.com/littlefs-project/littlefs-js
  }

  if (args['gdb'] == true) {
    final gdbServer = GDBTCPServer(simulator, 3333);
    print('RP2040 GDB Server ready! Listening on port ${gdbServer.port}');
  }

  final cdc = USBCDC(mcu.usbCtrl);
  cdc.onDeviceConnected = () {
    if (!circuitpython) {
      // We send a newline so the user sees the MicroPython prompt
      cdc.sendSerialByte('\r'.codeUnitAt(0));
      cdc.sendSerialByte('\n'.codeUnitAt(0));
    } else {
      cdc.sendSerialByte(3);
    }
  };

  var currentLine = '';
  cdc.onSerialData = (value) {
    stdout.add(value);

    for (final byte in value) {
      final char = String.fromCharCode(byte);
      if (char == '\n') {
        if (expectText != null &&
            expectText.isNotEmpty &&
            currentLine.contains(expectText)) {
          print('Expected text found: "$expectText"');
          print('TEST PASSED.');
          exit(0);
        }
        currentLine = '';
      } else {
        currentLine += char;
      }
    }
  };

  if (stdin.hasTerminal) {
    // Node's `setRawMode(true)`. `hasTerminal` is also true for character
    // devices that are not terminals (`< /dev/null` on macOS), where setting
    // the mode fails; the REPL then just runs without raw input.
    try {
      stdin.echoMode = false;
      stdin.lineMode = false;
    } on StdinException {
      // Not a real terminal.
    }
  }
  stdin.listen((chunk) {
    // 24 is Ctrl+X
    if (chunk.isNotEmpty && chunk[0] == 24) {
      exit(0);
    }
    for (final byte in chunk) {
      cdc.sendSerialByte(byte);
    }
  });

  simulator.rp2040.core.PC = 0x10000000;
  simulator.execute();
}
