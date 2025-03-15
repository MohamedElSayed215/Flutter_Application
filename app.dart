import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:go_router/go_router.dart';
import 'package:kdgaugeview/kdgaugeview.dart';
import 'package:lottie/lottie.dart';
import 'package:rc_controller_ble/utils/utils.dart';

import '../utils/extra.dart';
import 'constants.dart';

class ControlScreen extends StatefulWidget {
  final BluetoothDevice device;

  const ControlScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  int? _rssi;

  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;
  List<BluetoothService> _services = [];
  bool _isDiscoveringServices = false;
  bool _isConnecting = false;
  bool _isDisconnecting = false;

  late StreamSubscription<BluetoothConnectionState>
      _connectionStateSubscription;
  late StreamSubscription<bool> _isConnectingSubscription;
  late StreamSubscription<bool> _isDisconnectingSubscription;

  List<int> _value = [];
  late StreamSubscription<List<int>> _lastValueSubscription;

  BluetoothCharacteristic? _characteristicTX;
  
  double _rowWidth = 0;

  final speedNotifier = ValueNotifier<double>(10);
  final key = GlobalKey<KdGaugeViewState>();

  bool _anim = false;

  @override
  void initState() {
    super.initState();

    _connectionStateSubscription =
        widget.device.connectionState.listen((state) async {
      _connectionState = state;
      if (state == BluetoothConnectionState.connected) {
        _services = []; // must rediscover services
      }
      if (state == BluetoothConnectionState.connected && _rssi == null) {
        _rssi = await widget.device.readRssi();
      }

      if (state == BluetoothConnectionState.disconnected) {
        backToHome(true);
      }
    });

    _isConnectingSubscription = widget.device.isConnecting.listen((value) {
      _isConnecting = value;
      setState(() {});
    });

    _isDisconnectingSubscription =
        widget.device.isDisconnecting.listen((value) {
      _isDisconnecting = value;
      setState(() {});
    });

    onDiscoverServices();
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    _isConnectingSubscription.cancel();
    _isDisconnectingSubscription.cancel();
    _lastValueSubscription?.cancel();
    super.dispose();
  }

  bool get isConnected {
    return _connectionState == BluetoothConnectionState.connected;
  }

  void writeBLE(String command) async {
    if (!isConnected) {
      backToHome(true);
      return;
    }

    try {
      await _characteristicTX?.write(command.codeUnits, timeout: 1);
    } catch (e) {
      print("Write Error: ${e.toString()}");
    }
  }

  void prepareSendingData(double x, double y) {
    String command = 'S'; // Default: Stop

    if (y < -0.5) {
      command = 'F'; // Forward
    } else if (y > 0.5) {
      command = 'B'; // Backward
    } else if (x < -0.5) {
      command = 'L'; // Left
    } else if (x > 0.5) {
      command = 'R'; // Right
    }

    writeBLE(command);
  }

  void backToHome(bool needToReConnect) {
    onDisconnect();
    context.pop(needToReConnect);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    width: _rowWidth,
                    height: double.infinity,
                    alignment: Alignment.bottomCenter,
                    child: JoystickArea(
                      mode: JoystickMode.all,
                      listener: (details) {
                        prepareSendingData(details.x, details.y);
                      },
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0.0,
              right: 0.0,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CloseButton(
                  color: Colors.red,
                  onPressed: () => showDialog<String>(
                    context: context,
                    builder: (BuildContext context) => AlertDialog(
                      title: const Text('Do you want to close App?'),
                      content: const Text(
                          '(Automatically disconnected when the app ends.)'),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.pop(context, 'Cancel'),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => exit(0),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
