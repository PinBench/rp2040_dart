// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

// RP2040 GDB Server
//
// Copyright (C) 2021, Uri Shaked

import 'dart:math' as math;
import 'dart:typed_data';

import '../cortex_m0_core.dart';
import '../utils/bit.dart';
import '../utils/logging.dart';
import 'gdb_connection.dart';
import 'gdb_target.dart';
import 'gdb_utils.dart';

const String STOP_REPLY_SIGINT = 'S02';
const String STOP_REPLY_TRAP = 'S05';

/* string value: armv6m-none-unknown-eabi */
const String _lldbTriple = '61726d76366d2d6e6f6e652d756e6b6e6f776e2d65616269';

const List<String> _registers = [
  'name:r0;bitsize:32;offset:0;encoding:int;format:hex;set:General Purpose Registers;generic:arg1;gcc:0;dwarf:0;',
  'name:r1;bitsize:32;offset:4;encoding:int;format:hex;set:General Purpose Registers;generic:arg2;gcc:1;dwarf:1;',
  'name:r2;bitsize:32;offset:8;encoding:int;format:hex;set:General Purpose Registers;generic:arg3;gcc:2;dwarf:2;',
  'name:r3;bitsize:32;offset:12;encoding:int;format:hex;set:General Purpose Registers;generic:arg4;gcc:3;dwarf:3;',
  'name:r4;bitsize:32;offset:16;encoding:int;format:hex;set:General Purpose Registers;gcc:4;dwarf:4;',
  'name:r5;bitsize:32;offset:20;encoding:int;format:hex;set:General Purpose Registers;gcc:5;dwarf:5;',
  'name:r6;bitsize:32;offset:24;encoding:int;format:hex;set:General Purpose Registers;gcc:6;dwarf:6;',
  'name:r7;bitsize:32;offset:28;encoding:int;format:hex;set:General Purpose Registers;gcc:7;dwarf:7;',
  'name:r8;bitsize:32;offset:32;encoding:int;format:hex;set:General Purpose Registers;gcc:8;dwarf:8;',
  'name:r9;bitsize:32;offset:36;encoding:int;format:hex;set:General Purpose Registers;gcc:9;dwarf:9;',
  'name:r10;bitsize:32;offset:40;encoding:int;format:hex;set:General Purpose Registers;gcc:10;dwarf:10;',
  'name:r11;bitsize:32;offset:44;encoding:int;format:hex;set:General Purpose Registers;generic:fp;gcc:11;dwarf:11;',
  'name:r12;bitsize:32;offset:48;encoding:int;format:hex;set:General Purpose Registers;gcc:12;dwarf:12;',
  'name:sp;bitsize:32;offset:52;encoding:int;format:hex;set:General Purpose Registers;generic:sp;alt-name:r13;gcc:13;dwarf:13;',
  'name:lr;bitsize:32;offset:56;encoding:int;format:hex;set:General Purpose Registers;generic:ra;alt-name:r14;gcc:14;dwarf:14;',
  'name:pc;bitsize:32;offset:60;encoding:int;format:hex;set:General Purpose Registers;generic:pc;alt-name:r15;gcc:15;dwarf:15;',
  'name:cpsr;bitsize:32;offset:64;encoding:int;format:hex;set:General Purpose Registers;generic:flags;alt-name:psr;gcc:16;dwarf:16;',
];

const String _targetXML = '''
<?xml version="1.0"?>
<!DOCTYPE target SYSTEM "gdb-target.dtd">
<target version="1.0">
<architecture>arm</architecture>
<feature name="org.gnu.gdb.arm.m-profile">
<reg name="r0" bitsize="32" regnum="0" save-restore="yes" type="int" group="general"/>
<reg name="r1" bitsize="32" regnum="1" save-restore="yes" type="int" group="general"/>
<reg name="r2" bitsize="32" regnum="2" save-restore="yes" type="int" group="general"/>
<reg name="r3" bitsize="32" regnum="3" save-restore="yes" type="int" group="general"/>
<reg name="r4" bitsize="32" regnum="4" save-restore="yes" type="int" group="general"/>
<reg name="r5" bitsize="32" regnum="5" save-restore="yes" type="int" group="general"/>
<reg name="r6" bitsize="32" regnum="6" save-restore="yes" type="int" group="general"/>
<reg name="r7" bitsize="32" regnum="7" save-restore="yes" type="int" group="general"/>
<reg name="r8" bitsize="32" regnum="8" save-restore="yes" type="int" group="general"/>
<reg name="r9" bitsize="32" regnum="9" save-restore="yes" type="int" group="general"/>
<reg name="r10" bitsize="32" regnum="10" save-restore="yes" type="int" group="general"/>
<reg name="r11" bitsize="32" regnum="11" save-restore="yes" type="int" group="general"/>
<reg name="r12" bitsize="32" regnum="12" save-restore="yes" type="int" group="general"/>
<reg name="sp" bitsize="32" regnum="13" save-restore="yes" type="data_ptr" group="general"/>
<reg name="lr" bitsize="32" regnum="14" save-restore="yes" type="int" group="general"/>
<reg name="pc" bitsize="32" regnum="15" save-restore="yes" type="code_ptr" group="general"/>
<reg name="xPSR" bitsize="32" regnum="16" save-restore="yes" type="int" group="general"/>
</feature>
<feature name="org.gnu.gdb.arm.m-system">
<reg name="msp" bitsize="32" regnum="17" save-restore="yes" type="data_ptr" group="system"/>
<reg name="psp" bitsize="32" regnum="18" save-restore="yes" type="data_ptr" group="system"/>
<reg name="primask" bitsize="1" regnum="19" save-restore="yes" type="int8" group="system"/>
<reg name="basepri" bitsize="8" regnum="20" save-restore="yes" type="int8" group="system"/>
<reg name="faultmask" bitsize="1" regnum="21" save-restore="yes" type="int8" group="system"/>
<reg name="control" bitsize="2" regnum="22" save-restore="yes" type="int8" group="system"/>
</feature>
</target>''';

const String _LOG_NAME = 'GDBServer';

class GDBServer {
  Logger logger = ConsoleLogger(LogLevel.Warn, true);

  final Set<GDBConnection> _connections = {};

  final IGDBTarget target;

  GDBServer(this.target);

  String? processGDBMessage(String cmd) {
    final rp2040 = target.rp2040;
    final core = rp2040.core;
    if (cmd == 'Hg0') {
      return gdbMessage('OK');
    }

    switch (cmd.isEmpty ? '' : cmd[0]) {
      case '?':
        return gdbMessage(STOP_REPLY_TRAP);

      case 'q':
        // Query things
        if (cmd.startsWith('qSupported:')) {
          return gdbMessage(
            'PacketSize=4000;vContSupported+;qXfer:features:read+',
          );
        }
        if (cmd == 'qAttached') {
          return gdbMessage('1');
        }
        if (cmd.startsWith('qXfer:features:read:target.xml')) {
          return gdbMessage('l$_targetXML');
        }
        if (cmd.startsWith('qRegisterInfo')) {
          final index = parseHexInt(cmd.substring(13));
          if (index != null && index >= 0 && index < _registers.length) {
            return gdbMessage(_registers[index]);
          } else {
            return gdbMessage('E45');
          }
        }
        if (cmd == 'qHostInfo') {
          return gdbMessage('triple:$_lldbTriple;endian:little;ptrsize:4;');
        }
        if (cmd == 'qProcessInfo') {
          return gdbMessage('pid:1;endian:little;ptrsize:4;');
        }
        return gdbMessage('');

      case 'v':
        if (cmd == 'vCont?') {
          return gdbMessage('vCont;c;C;s;S');
        }
        if (cmd.startsWith('vCont;c')) {
          if (!target.executing) {
            target.execute();
          }
          return null;
        }
        if (cmd.startsWith('vCont;s')) {
          rp2040.step();
          final registerStatus = <String>[];
          for (var i = 0; i < 17; i++) {
            final value = i == 16 ? core.xPSR : core.registers[i];
            registerStatus.add('${encodeHexByte(i)}:${encodeHexUint32(value)}');
          }
          return gdbMessage('T05${registerStatus.join(';')};reason:trace;');
        }
        break;

      case 'c':
        if (!target.executing) {
          target.execute();
        }
        return gdbMessage('OK');

      case 'g':
        {
          // Read registers
          final buf = Uint32List(17);
          buf.setAll(0, core.registers);
          buf[16] = core.xPSR;
          return gdbMessage(encodeHexBuf(Uint8List.view(buf.buffer)));
        }

      case 'p':
        {
          // Read register
          final registerIndex = parseHexInt(cmd.substring(1));
          if (registerIndex == null) {
            break;
          }
          if (registerIndex >= 0 && registerIndex <= 15) {
            return gdbMessage(encodeHexUint32(core.registers[registerIndex]));
          }
          String specialRegister(int sysm) =>
              gdbMessage(encodeHexUint32(core.readSpecialRegister(sysm)));
          switch (registerIndex) {
            case 0x10:
              return gdbMessage(encodeHexUint32(core.xPSR));
            case 0x11:
              return specialRegister(SYSM_MSP);
            case 0x12:
              return specialRegister(SYSM_PSP);
            case 0x13:
              return specialRegister(SYSM_PRIMASK);
            case 0x14:
              logger.warn(_LOG_NAME, 'TODO BASEPRI');
              return gdbMessage(encodeHexUint32(0)); // TODO BASEPRI
            case 0x15:
              logger.warn(_LOG_NAME, 'TODO faultmask');
              return gdbMessage(encodeHexUint32(0)); // TODO faultmask
            case 0x16:
              return specialRegister(SYSM_CONTROL);
          }
          break;
        }

      case 'P':
        {
          // Write register
          final params = cmd.substring(1).split('=');
          // `parseInt` gives NaN (here null) for a malformed index; every
          // comparison with NaN is false, so it passes the range check below.
          final registerIndex = parseHexInt(params[0]);
          final registerValue = params[1].trim();
          final registerBytes = registerIndex != null && registerIndex > 0x12
              ? 1
              : 4;
          final decodedValue = decodeHexBuf(registerValue);
          if (registerIndex != null &&
                  (registerIndex < 0 || registerIndex > 0x16) ||
              decodedValue.length != registerBytes) {
            return gdbMessage('E00');
          }
          final valueBuffer = Uint8List(4);
          valueBuffer.setAll(
            0,
            decodedValue.sublist(0, math.min(4, decodedValue.length)),
          );
          final value = ByteData.view(
            valueBuffer.buffer,
          ).getUint32(0, Endian.little);
          switch (registerIndex) {
            case 0x10:
              core.xPSR = value;
              break;
            case 0x11:
              core.writeSpecialRegister(SYSM_MSP, value);
              break;
            case 0x12:
              core.writeSpecialRegister(SYSM_PSP, value);
              break;
            case 0x13:
              core.writeSpecialRegister(SYSM_PRIMASK, value);
              break;
            case 0x14:
              logger.warn(_LOG_NAME, 'TODO BASEPRI');
              break; // TODO BASEPRI
            case 0x15:
              logger.warn(_LOG_NAME, 'TODO faultmask');
              break; // TODO faultmask
            case 0x16:
              core.writeSpecialRegister(SYSM_CONTROL, value);
              break;
            default:
              // Writing `registers[NaN]` of a typed array is a no-op in JS
              if (registerIndex != null) {
                core.registers[registerIndex] = value;
              }
              break;
          }
          return gdbMessage('OK');
        }

      case 'm':
        {
          // Read memory
          final params = cmd.substring(1).split(',');
          // JS: `NaN >>> 0` is 0, and `i < NaN` is false
          final address = parseHexInt(params[0]) ?? 0;
          final length = params.length > 1 ? parseHexInt(params[1]) ?? 0 : 0;
          final result = StringBuffer();
          for (var i = 0; i < length; i++) {
            result.write(encodeHexByte(rp2040.readUint8(u32(address + i))));
          }
          return gdbMessage(result.toString());
        }

      case 'M':
        {
          // Write memory
          final params = cmd.substring(1).split(RegExp('[,:]'));
          final address = parseHexInt(params[0]) ?? 0;
          final length = parseHexInt(params[1]) ?? 0;
          final data = decodeHexBuf(
            params[2].substring(0, (length * 2).clamp(0, params[2].length)),
          );
          for (var i = 0; i < data.length; i++) {
            debug(
              'Write ${data[i].toRadixString(16)} to ${(address + i).toRadixString(16)}',
            );
            rp2040.writeUint8(u32(address + i), data[i]);
          }
          return gdbMessage('OK');
        }
    }

    return gdbMessage('');
  }

  void addConnection(GDBConnection connection) {
    final rp2040 = target.rp2040;
    _connections.add(connection);
    rp2040.onBreak = (_) {
      target.stop();
      rp2040.core.PC = u32(rp2040.core.PC - rp2040.core.breakRewind);
      // A copy: onBreakpoint() removes a connection whose socket is gone.
      for (final connection in _connections.toList()) {
        connection.onBreakpoint();
      }
    };
  }

  void removeConnection(GDBConnection connection) {
    _connections.remove(connection);
  }

  void debug(String msg) {
    logger.debug(_LOG_NAME, msg);
  }

  void info(String msg) {
    logger.info(_LOG_NAME, msg);
  }

  void warn(String msg) {
    logger.warn(_LOG_NAME, msg);
  }

  void error(String msg) {
    logger.error(_LOG_NAME, msg);
  }
}
