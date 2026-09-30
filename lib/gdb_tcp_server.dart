// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

/// A GDB remote-protocol server over TCP, for the native Dart VM.
///
/// A separate library from `package:rp2040_dart/rp2040_dart.dart` because it
/// uses `dart:io` sockets, which keeps the main library usable on the web.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'src/gdb/gdb_connection.dart';
import 'src/gdb/gdb_server.dart';

export 'src/gdb/gdb_target.dart' show IGDBTarget;

class GDBTCPServer extends GDBServer {
  ServerSocket? _socketServer;

  final int port;

  /// Completes once the server listens on [port]. Node's `listen()` also binds
  /// in the background; Dart exposes it as a future. A bind error surfaces here.
  late final Future<void> listening;

  GDBTCPServer(super.target, [this.port = 3333]) {
    // Start binding right away, as rp2040js does in its constructor.
    listening = _listen();
  }

  Future<void> _listen() async {
    // Node's `listen(port)` binds the unspecified address, dual-stack when IPv6 is available.
    ServerSocket socketServer;
    try {
      socketServer = await ServerSocket.bind(
        InternetAddress.anyIPv6,
        port,
        v6Only: false,
      );
    } on SocketException {
      socketServer = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    }
    _socketServer = socketServer;
    socketServer.listen((socket) => handleConnection(socket));
  }

  /// Stops listening for new connections (rp2040js has no equivalent).
  Future<void> close() async {
    await listening;
    await _socketServer?.close();
  }

  void handleConnection(Socket socket) {
    info('GDB connected');
    socket.setOption(SocketOption.tcpNoDelay, true);

    final connection = GDBConnection(this, (data) {
      socket.write(data);
    });

    // Write errors are also reported on the socket stream below.
    unawaited(socket.done.catchError((_) {}));

    socket.listen(
      (data) {
        connection.feedData(utf8.decode(data, allowMalformed: true));
      },
      onError: (Object err) {
        removeConnection(connection);
        error('GDB socket error $err');
      },
      onDone: () {
        removeConnection(connection);
        info('GDB disconnected');
      },
    );
  }
}
