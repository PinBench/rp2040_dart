/// The RP2040 B1 boot ROM image (Raspberry Pi, BSD-3-Clause), for
/// `RP2040.loadBootrom`. A separate library so the 16 KB image is only
/// compiled into programs that use it.
library;

export 'src/bootrom.dart' show bootromB1;
