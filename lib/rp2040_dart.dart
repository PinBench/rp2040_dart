/// A pure Dart port of rp2040js, the Raspberry Pi RP2040 emulator.
///
/// Mirrors rp2040js's `src/index.ts`. The GDB TCP server, which needs
/// `dart:io`, is a separate library: `package:rp2040_dart/gdb_tcp_server.dart`.
/// The boot ROM image is `package:rp2040_dart/bootrom.dart`.
library;

import 'src/usb/usb_device.dart' as usb_device;

export 'src/gdb/gdb_connection.dart' show GDBConnection;
export 'src/gdb/gdb_server.dart' show GDBServer;
export 'src/gpio_pin.dart' show GPIOPin, GPIOPinState;
export 'src/peripherals/i2c.dart' show I2CMode, I2CSpeed, RPI2C;
export 'src/peripherals/peripheral.dart' show BasePeripheral, Peripheral;
export 'src/peripherals/pio.dart' show RPPIO, StateMachine;
export 'src/peripherals/usb.dart' show RPUSBController;
export 'src/rp2040.dart' show RP2040, ClockListener;
export 'src/simulator.dart' show Simulator;
export 'src/usb/cdc.dart' show USBCDC;
export 'src/usb/interfaces.dart'
    show
        DataDirection,
        DescriptorType,
        SetupRecipient,
        SetupRequest,
        SetupType,
        ISetupPacketParams;
export 'src/usb/setup.dart'
    show
        createSetupPacket,
        getDescriptorPacket,
        setDeviceAddressPacket,
        setDeviceConfigurationPacket;
export 'src/usb/usb_device.dart'
    show
        StandardRequest,
        parseSetupPacket,
        USBDevice,
        USBTransferResult,
        USBTransferStatus;
export 'src/utils/fifo.dart' show FIFO;
export 'src/utils/logging.dart' show ConsoleLogger, LogLevel, Logger;

/// rp2040js exports usb-device's `DescriptorType` under this name, since
/// `interfaces.dart` has a `DescriptorType` of its own.
typedef USBDescriptorType = usb_device.DescriptorType;
