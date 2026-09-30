// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'gdb_server.dart';
import 'gdb_target.dart';
import 'gdb_utils.dart';

typedef GDBResponseHandler = void Function(String value);

class GDBConnection {
  final IGDBTarget target;
  String _buf = '';

  final GDBServer _server;
  final GDBResponseHandler _onResponse;

  GDBConnection(this._server, this._onResponse) : target = _server.target {
    _server.addConnection(this);
    _onResponse('+');
  }

  void feedData(String data) {
    final onResponse = _onResponse;
    if (data.isNotEmpty && data.codeUnitAt(0) == 3) {
      _server.info('BREAK');
      target.stop();
      onResponse(gdbMessage(STOP_REPLY_SIGINT));
      data = data.substring(1);
    }

    _buf += data;
    for (;;) {
      final dolla = _buf.indexOf('\$');
      final hash = _buf.indexOf('#', dolla + 1);
      if (dolla < 0 || hash < 0 || hash + 2 > _buf.length) {
        return;
      }
      final cmd = _buf.substring(dolla + 1, hash);
      final cksum = _buf.substring(
        hash + 1,
        hash + 3 > _buf.length ? _buf.length : hash + 3,
      );
      // rp2040js keeps the checksum's last character (`substr(hash + 2)`);
      // the next search for '$' skips it.
      _buf = _buf.substring(hash + 2);
      if (gdbChecksum(cmd) != cksum) {
        _server.warn('GDB checksum error in message: $cmd');
        onResponse('-');
      } else {
        onResponse('+');
        _server.debug('>$cmd');
        final response = _server.processGDBMessage(cmd);
        if (response != null && response.isNotEmpty) {
          _server.debug('<$response');
          onResponse(response);
        }
      }
    }
  }

  void onBreakpoint() {
    try {
      _onResponse(gdbMessage(STOP_REPLY_TRAP));
    } catch (e) {
      _server.removeConnection(this);
    }
  }
}
