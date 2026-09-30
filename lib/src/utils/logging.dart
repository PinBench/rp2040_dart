// SPDX-License-Identifier: MIT
// Copyright (c) Uri Shaked and contributors (rp2040js); Dart port by PinBench

import 'time.dart';

abstract interface class Logger {
  void debug(String componentName, String message);
  void warn(String componentName, String message);
  void error(String componentName, String message);
  void info(String componentName, String message);
}

enum LogLevel { Debug, Info, Warn, Error }

class ConsoleLogger implements Logger {
  LogLevel currentLogLevel;
  final bool _throwOnError;

  ConsoleLogger(this.currentLogLevel, [this._throwOnError = true]);

  bool _aboveLogLevel(LogLevel logLevel) =>
      logLevel.index >= currentLogLevel.index;

  String _formatMessage(String componentName, String message) {
    final currentTime = formatTime(DateTime.now());
    return '$currentTime [$componentName] $message';
  }

  @override
  void debug(String componentName, String message) {
    if (_aboveLogLevel(LogLevel.Debug)) {
      print(_formatMessage(componentName, message));
    }
  }

  @override
  void warn(String componentName, String message) {
    if (_aboveLogLevel(LogLevel.Warn)) {
      print(_formatMessage(componentName, message));
    }
  }

  @override
  void error(String componentName, String message) {
    if (_aboveLogLevel(LogLevel.Error)) {
      print(_formatMessage(componentName, message));
      if (_throwOnError) {
        throw StateError('[$componentName] $message');
      }
    }
  }

  @override
  void info(String componentName, String message) {
    if (_aboveLogLevel(LogLevel.Info)) {
      print(_formatMessage(componentName, message));
    }
  }
}
