import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'guoran_protocol.dart';

class GuoranBleController extends ChangeNotifier {
  GuoranBleController() {
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      _adapterState = state;
      notifyListeners();
    });

    _scanResultsSubscription = FlutterBluePlus.scanResults.listen(
      _handleScanResults,
      onError: (Object error, StackTrace stackTrace) {
        _setError('Scan failed: $error');
      },
    );

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((value) {
      _isScanning = value;
      notifyListeners();
    });
  }

  static const _safetyKeyPreference = 'guoran_safety_key';
  static const Duration _connectSettleDelay = Duration(milliseconds: 350);
  static const int _maxConnectFlowAttempts = 2;

  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  List<ScanResult> _scanResults = const <ScanResult>[];
  bool _isScanning = false;
  bool _isBusy = false;
  String _statusMessage = 'Ready to scan';
  String? _errorMessage;
  List<String> _serviceDiagnostics = const <String>[];
  final List<String> _debugLogLines = <String>[];

  BluetoothDevice? _connectedDevice;
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  StreamSubscription<BluetoothConnectionState>? _deviceStateSubscription;
  StreamSubscription<List<int>>? _readValueSubscription;
  StreamSubscription<List<int>>? _safetyKeyValueSubscription;

  BluetoothCharacteristic? _readCharacteristic;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _safetyKeyCharacteristic;
  BluetoothCharacteristic? _safetyKeyNotifyCharacteristic;

  SharedPreferences? _preferences;
  String? _storedSafetyKey;
  bool _sentFallbackSafetyKey = false;
  bool _safetyKeyAccepted = false;
  String _incomingSnapshotBuffer = '';
  DateTime? _lastSnapshotRequestAt;

  GuoranSnapshot? _snapshot;
  bool _acquisitionSystemTimeEnabled = false;
  bool _alarm1Enabled = false;
  bool _alarm2Enabled = false;
  bool _timingEnabled = false;
  String _alarm1 = '00:00';
  String _alarm2 = '00:00';
  String _bootTime = '00:00';
  String _offTime = '00:00';
  Timer? _systemTimeTimer;
  bool _connectFlowInProgress = false;
  bool _hasObservedConnectedState = false;

  late final StreamSubscription<BluetoothAdapterState> _adapterStateSubscription;
  late final StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late final StreamSubscription<bool> _isScanningSubscription;

  BluetoothAdapterState get adapterState => _adapterState;
  List<ScanResult> get scanResults => List<ScanResult>.unmodifiable(_scanResults);
  bool get isScanning => _isScanning;
  bool get isBusy => _isBusy;
  String get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  List<String> get serviceDiagnostics => List<String>.unmodifiable(_serviceDiagnostics);
  List<String> get debugLogLines => List<String>.unmodifiable(_debugLogLines);
  BluetoothDevice? get connectedDevice => _connectedDevice;
  BluetoothConnectionState get connectionState => _connectionState;
  bool get isConnected => _connectionState == BluetoothConnectionState.connected;
  bool get hasSnapshot => _snapshot != null;
  bool get acquisitionSystemTimeEnabled => _acquisitionSystemTimeEnabled;
  bool get alarm1Enabled => _alarm1Enabled;
  bool get alarm2Enabled => _alarm2Enabled;
  bool get timingEnabled => _timingEnabled;
  String get alarm1 => _alarm1;
  String get alarm2 => _alarm2;
  String get bootTime => _bootTime;
  String get offTime => _offTime;
  String get debugReport {
    final List<String> lines = <String>[
      '[State]',
      'status: $_statusMessage',
      'error: ${_errorMessage ?? '(none)'}',
      'adapterState: ${_adapterState.name}',
      'connectionState: ${_connectionState.name}',
      'deviceId: ${_connectedDevice?.remoteId.str ?? '(none)'}',
      'deviceName: ${_connectedDevice?.platformName.isNotEmpty == true ? _connectedDevice!.platformName : '(none)'}',
      'storedSafetyKeyPresent: ${_storedSafetyKey != null}',
      'safetyKeyAccepted: $_safetyKeyAccepted',
      'sentFallbackSafetyKey: $_sentFallbackSafetyKey',
      'snapshotPresent: ${_snapshot != null}',
      'incomingSnapshotBufferLength: ${_incomingSnapshotBuffer.length}',
      'lastSnapshotRequestAt: ${_lastSnapshotRequestAt?.toIso8601String() ?? '(none)'}',
      'readService: ${_readCharacteristic?.serviceUuid.str ?? '(unresolved)'}',
      'readCharacteristic: ${_readCharacteristic?.uuid.str ?? '(unresolved)'}',
      'writeService: ${_writeCharacteristic?.serviceUuid.str ?? '(unresolved)'}',
      'writeCharacteristic: ${_writeCharacteristic?.uuid.str ?? '(unresolved)'}',
      'safetyKeyService: ${_safetyKeyCharacteristic?.serviceUuid.str ?? '(unresolved)'}',
      'safetyKeyCharacteristic: ${_safetyKeyCharacteristic?.uuid.str ?? '(unresolved)'}',
      'safetyKeyNotifyCharacteristic: ${_safetyKeyNotifyCharacteristic?.uuid.str ?? '(unresolved)'}',
    ];

    if (_serviceDiagnostics.isNotEmpty) {
      lines.add('');
      lines.add('[Services]');
      lines.addAll(_serviceDiagnostics);
    }

    if (_debugLogLines.isNotEmpty) {
      lines.add('');
      lines.add('[Recent Log]');
      lines.addAll(_debugLogLines);
    }

    return lines.join('\n');
  }

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    _storedSafetyKey = _preferences?.getString(_safetyKeyPreference);
    _log('Initialized controller. Cached safety key present: ${_storedSafetyKey != null}.');
    notifyListeners();
  }

  void clearDebugLog() {
    _debugLogLines.clear();
    notifyListeners();
  }

  Future<void> startScan() async {
    _clearError();
    _log('Requested scan. Adapter state: ${_adapterState.name}.');
    if (_adapterState != BluetoothAdapterState.on) {
      _setError('Turn on Bluetooth before scanning.');
      return;
    }

    final bool granted = await _ensurePermissions();
    if (!granted) {
      return;
    }

    _setStatus('Scanning for XGGF devices...');

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        withServices: GuoranProtocol.scanServiceGuids,
      );
      _log('Scan started with service filters: ${GuoranProtocol.scanServices.join(', ')}.');
    } catch (error) {
      _setError('Unable to start scan: $error');
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      _log('Scan stopped.');
    } catch (error) {
      _setError('Unable to stop scan: $error');
    }
  }

  Future<void> connectToResult(ScanResult result) async {
    _clearError();
    _serviceDiagnostics = const <String>[];
    _debugLogLines.clear();
    _isBusy = true;
    _connectFlowInProgress = true;
    _hasObservedConnectedState = false;
    _log(
      'Connecting to ${_deviceLabel(result)} | id=${result.device.remoteId.str} | rssi=${result.rssi} | advertisedServices=${result.advertisementData.serviceUuids.join(', ')}',
      notify: false,
    );
    _setStatus('Connecting to ${_deviceLabel(result)}...');

    try {
      await stopScan();
      await _disconnectCurrentDevice();

      _connectedDevice = result.device;
      await _attachDeviceStateSubscription(result.device);
      await _connectAndPrepareDevice(result.device);
    } catch (error) {
      _setError('Connection failed: $error');
      await _disconnectCurrentDevice();
      _clearSession(keepDevice: false, keepStatus: true);
    } finally {
      _connectFlowInProgress = false;
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _clearError();
    _isBusy = true;
    notifyListeners();

    try {
      await _disconnectCurrentDevice();
      _clearSession(keepDevice: false, keepStatus: false);
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> refreshSnapshot() async {
    _clearError();
    _log('Manual snapshot refresh requested.');
    await _requestSnapshot(force: true);
  }

  Future<void> setAcquisitionSystemTimeEnabled(bool enabled) async {
    _acquisitionSystemTimeEnabled = enabled;
    notifyListeners();

    await _sendTimeToggleCommand(
      enabled ? GuoranProtocol.enableSystemTimeSync : GuoranProtocol.disableSystemTimeSync,
    );

    if (enabled) {
      _startSystemTimeUpdates();
    } else {
      _stopSystemTimeUpdates();
    }
  }

  Future<void> syncCurrentSystemTimeNow() async {
    await _sendCommand(GuoranProtocol.buildSystemTimePayload(DateTime.now()));
  }

  Future<void> setAlarm1Enabled(bool enabled) async {
    _alarm1Enabled = enabled;
    notifyListeners();
    await _sendTimeToggleCommand(enabled ? GuoranProtocol.enableAlarm1 : GuoranProtocol.disableAlarm1);
  }

  Future<void> setAlarm2Enabled(bool enabled) async {
    _alarm2Enabled = enabled;
    notifyListeners();
    await _sendTimeToggleCommand(enabled ? GuoranProtocol.enableAlarm2 : GuoranProtocol.disableAlarm2);
  }

  Future<void> setTimingEnabled(bool enabled) async {
    _timingEnabled = enabled;
    notifyListeners();
    await _sendTimeToggleCommand(enabled ? GuoranProtocol.enableTiming : GuoranProtocol.disableTiming);
  }

  Future<void> updateAlarm1(TimeOfDay value) async {
    _alarm1 = GuoranProtocol.formatTimeOfDay(value);
    notifyListeners();
    await _sendCommand(GuoranProtocol.buildTimeCommand(GuoranTimeField.alarm1, value));
  }

  Future<void> updateAlarm2(TimeOfDay value) async {
    _alarm2 = GuoranProtocol.formatTimeOfDay(value);
    notifyListeners();
    await _sendCommand(GuoranProtocol.buildTimeCommand(GuoranTimeField.alarm2, value));
  }

  Future<void> updateBootTime(TimeOfDay value) async {
    _bootTime = GuoranProtocol.formatTimeOfDay(value);
    notifyListeners();
    await _sendCommand(GuoranProtocol.buildTimeCommand(GuoranTimeField.boot, value));
  }

  Future<void> updateOffTime(TimeOfDay value) async {
    _offTime = GuoranProtocol.formatTimeOfDay(value);
    notifyListeners();
    await _sendCommand(GuoranProtocol.buildTimeCommand(GuoranTimeField.off, value));
  }

  @override
  void dispose() {
    _stopSystemTimeUpdates();
    _adapterStateSubscription.cancel();
    _scanResultsSubscription.cancel();
    _isScanningSubscription.cancel();
    _deviceStateSubscription?.cancel();
    _readValueSubscription?.cancel();
    _safetyKeyValueSubscription?.cancel();
    super.dispose();
  }

  Future<void> _discoverCharacteristics(BluetoothDevice device) async {
    final List<BluetoothService> services = await device.discoverServices();
    _log('Discovered ${services.length} services.', notify: false);
    _serviceDiagnostics = _describeServices(services);
    _logServiceDiagnostics();
    notifyListeners();

    final BluetoothService readService = _requireService(services, GuoranProtocol.readServiceShort);
    final BluetoothService writeService = _requireService(services, GuoranProtocol.writeServiceShort);
    final BluetoothService safetyKeyService = _requireService(services, GuoranProtocol.safetyKeyServiceShort);

    _readCharacteristic = _requireCharacteristic(readService, GuoranProtocol.readCharacteristicShort);
    _writeCharacteristic = _requireCharacteristic(writeService, GuoranProtocol.writeCharacteristicShort);
    _safetyKeyCharacteristic = _requireCharacteristic(safetyKeyService, GuoranProtocol.safetyKeyCharacteristicShort);
    _safetyKeyNotifyCharacteristic =
        _requireCharacteristic(safetyKeyService, GuoranProtocol.safetyKeyNotifyCharacteristicShort);

    _log(
      'Resolved transport: read=${readService.uuid.str}/${_readCharacteristic?.uuid.str}, '
      'write=${writeService.uuid.str}/${_writeCharacteristic?.uuid.str}, '
      'safety=${safetyKeyService.uuid.str}/${_safetyKeyCharacteristic?.uuid.str}, '
      'safetyNotify=${_safetyKeyNotifyCharacteristic?.uuid.str}',
      notify: false,
    );
  }

  Future<void> _attachDeviceStateSubscription(BluetoothDevice device) async {
    await _deviceStateSubscription?.cancel();
    _deviceStateSubscription = device.connectionState.listen((state) {
      _connectionState = state;
      if (state == BluetoothConnectionState.connected) {
        _hasObservedConnectedState = true;
      }

      _log('Connection state -> ${state.name}.', notify: false);
      if (state == BluetoothConnectionState.disconnected) {
        _stopSystemTimeUpdates();

        if (_connectFlowInProgress && !_hasObservedConnectedState) {
          _log('Ignoring initial disconnected state while the connect attempt is still starting.', notify: false);
        } else if (_connectFlowInProgress) {
          _log('Device disconnected during connect flow. Retaining state so the controller can retry once.', notify: false);
        } else {
          _clearSession(keepDevice: false, keepStatus: false);
        }
      }

      notifyListeners();
    });
  }

  Future<void> _connectAndPrepareDevice(BluetoothDevice device) async {
    Object? lastError;

    for (int attempt = 1; attempt <= _maxConnectFlowAttempts; attempt++) {
      try {
        _log('Connect flow attempt $attempt of $_maxConnectFlowAttempts.', notify: false);
        await _connectWithSettle(device);
        _setStatus('Discovering services...');
        await _discoverCharacteristics(device);
        await _beginHandshake();
        return;
      } catch (error) {
        lastError = error;
        _log('Connect flow attempt $attempt failed: $error', notify: false);

        if (!_shouldRetryConnectFlow(error, attempt, device)) {
          rethrow;
        }

        _setStatus('Connection dropped. Retrying once...');
        await _disconnectCurrentDevice();
        await Future<void>.delayed(_connectSettleDelay);
      }
    }

    throw lastError ?? StateError('Unable to complete BLE connect flow.');
  }

  Future<void> _connectWithSettle(BluetoothDevice device) async {
    await device.connect(license: License.free, mtu: null);
    await _waitForConnectedState(device);
    _log(
      'BLE connect succeeded. Waiting ${_connectSettleDelay.inMilliseconds} ms for the link to settle before discovery.',
      notify: false,
    );
    await Future<void>.delayed(_connectSettleDelay);

    if (device.isDisconnected || _connectionState == BluetoothConnectionState.disconnected) {
      throw StateError('Device disconnected before service discovery.');
    }

    _connectionState = BluetoothConnectionState.connected;
    _log('BLE link remained connected through settle window.', notify: false);
  }

  Future<void> _waitForConnectedState(BluetoothDevice device) async {
    if (device.isConnected || _connectionState == BluetoothConnectionState.connected) {
      return;
    }

    await device.connectionState
        .where((state) => state == BluetoothConnectionState.connected)
        .first
        .timeout(const Duration(seconds: 5));
  }

  bool _shouldRetryConnectFlow(Object error, int attempt, BluetoothDevice device) {
    if (attempt >= _maxConnectFlowAttempts) {
      return false;
    }

    if (device.isDisconnected || _connectionState == BluetoothConnectionState.disconnected) {
      return true;
    }

    final String message = error.toString().toLowerCase();
    return message.contains('device is not connected') ||
        message.contains('not connected') ||
        message.contains('fbp-code: 6') ||
        message.contains('connection canceled');
  }

  Future<void> _beginHandshake() async {
    final BluetoothCharacteristic? readCharacteristic = _readCharacteristic;
    final BluetoothCharacteristic? safetyKeyNotifyCharacteristic = _safetyKeyNotifyCharacteristic;
    if (readCharacteristic == null || safetyKeyNotifyCharacteristic == null) {
      throw StateError('Required characteristics were not discovered.');
    }

    await _readValueSubscription?.cancel();
    await _safetyKeyValueSubscription?.cancel();

    _readValueSubscription = readCharacteristic.lastValueStream.listen(_handleReadValue);
    _safetyKeyValueSubscription =
        safetyKeyNotifyCharacteristic.lastValueStream.listen(_handleSafetyKeyValue);

    _log('Enabling notifications on ${safetyKeyNotifyCharacteristic.uuid.str} and ${readCharacteristic.uuid.str}.', notify: false);
    await safetyKeyNotifyCharacteristic.setNotifyValue(true);
    await readCharacteristic.setNotifyValue(true);

    _setStatus('Performing device handshake...');
    _incomingSnapshotBuffer = '';
    _sentFallbackSafetyKey = false;
    _safetyKeyAccepted = false;

    await _writeSafetyKey(_storedSafetyKey ?? GuoranProtocol.initialSafetyKeyPayload);
  }

  void _handleReadValue(List<int> value) {
    if (value.isEmpty) {
      _log('Read notify received empty payload.', notify: false);
      return;
    }

    final String chunk = GuoranProtocol.decodeAscii(value);
    _log('Read notify hex=${_formatHex(value)} ascii="${_sanitizeForLog(chunk)}"', notify: false);
    if (chunk.isEmpty) {
      return;
    }

    final GuoranSnapshot? exactSnapshot = GuoranProtocol.tryParseSnapshot(chunk);
    if (exactSnapshot != null) {
      _log('Parsed snapshot directly from notify chunk.', notify: false);
      _applySnapshot(exactSnapshot);
      return;
    }

    _incomingSnapshotBuffer += chunk;
    _log('Snapshot buffer length is now ${_incomingSnapshotBuffer.length}.', notify: false);
    final int start = _incomingSnapshotBuffer.indexOf('R');
    final int end = _incomingSnapshotBuffer.indexOf('CSS', start >= 0 ? start : 0);
    if (start != -1 && end != -1) {
      final String candidate = _incomingSnapshotBuffer.substring(start, end + 3);
      final GuoranSnapshot? bufferedSnapshot = GuoranProtocol.tryParseSnapshot(candidate);
      if (bufferedSnapshot != null) {
        _incomingSnapshotBuffer = _incomingSnapshotBuffer.substring(end + 3);
        _log('Parsed snapshot from buffered data.', notify: false);
        _applySnapshot(bufferedSnapshot);
        return;
      }
    }

    if (_incomingSnapshotBuffer.length > 256) {
      _incomingSnapshotBuffer = _incomingSnapshotBuffer.substring(_incomingSnapshotBuffer.length - 128);
      _log('Trimmed snapshot buffer to ${_incomingSnapshotBuffer.length} characters.', notify: false);
    }

    if (_safetyKeyAccepted) {
      _log('Handshake succeeded but snapshot is incomplete. Requesting OSC again.', notify: false);
      unawaited(_requestSnapshot());
    }
  }

  void _handleSafetyKeyValue(List<int> value) {
    if (value.isEmpty) {
      _log('Safety-key notify received empty payload.', notify: false);
      return;
    }

    final SafetyKeyResult result = GuoranProtocol.parseSafetyKeyResponse(value);
    _log('Safety-key notify hex=${_formatHex(value)} parsed=${result.name}.', notify: false);

    switch (result) {
      case SafetyKeyResult.accepted:
      case SafetyKeyResult.changed:
        _safetyKeyAccepted = true;
        _storedSafetyKey = GuoranProtocol.storedSafetyKeyPayload;
        unawaited(_preferences?.setString(_safetyKeyPreference, GuoranProtocol.storedSafetyKeyPayload));
        _setStatus('Handshake complete, syncing device state...');
        unawaited(_requestSnapshot(force: true));
        break;
      case SafetyKeyResult.incorrect:
        if (_sentFallbackSafetyKey) {
          _setError('Device rejected the stored safety key.');
          return;
        }
        _sentFallbackSafetyKey = true;
        _setStatus('Retrying with fallback safety key...');
        unawaited(_writeSafetyKey(GuoranProtocol.storedSafetyKeyPayload));
        break;
      case SafetyKeyResult.cancelled:
        _setError('Device cancelled the safety-key handshake.');
        break;
      case SafetyKeyResult.unknown:
        _setError('Received an unknown safety-key response.');
        break;
    }
  }

  void _applySnapshot(GuoranSnapshot snapshot) {
    _snapshot = snapshot;
    _acquisitionSystemTimeEnabled = snapshot.acquisitionSystemTimeEnabled;
    _alarm1Enabled = snapshot.alarm1Enabled;
    _alarm2Enabled = snapshot.alarm2Enabled;
    _timingEnabled = snapshot.timingEnabled;
    _alarm1 = snapshot.alarm1;
    _alarm2 = snapshot.alarm2;
    _bootTime = snapshot.bootTime;
    _offTime = snapshot.offTime;
    _setStatus('Connected and synchronized.', notify: false);
    _log(
      'Snapshot applied: alarm1=$_alarm1 alarm2=$_alarm2 boot=$_bootTime off=$_offTime '
      'sync=$_acquisitionSystemTimeEnabled timing=$_timingEnabled',
      notify: false,
    );

    if (_acquisitionSystemTimeEnabled) {
      _startSystemTimeUpdates();
    } else {
      _stopSystemTimeUpdates();
    }

    notifyListeners();
  }

  Future<void> _sendTimeToggleCommand(String command) async {
    await _sendCommand(command);
  }

  Future<void> _requestSnapshot({bool force = false}) async {
    if (_writeCharacteristic == null) {
      _log('Snapshot request skipped because write characteristic is unresolved.', notify: false);
      return;
    }

    if (!force && _lastSnapshotRequestAt != null) {
      final Duration elapsed = DateTime.now().difference(_lastSnapshotRequestAt!);
      if (elapsed < const Duration(milliseconds: 800)) {
        _log('Snapshot request throttled after ${elapsed.inMilliseconds} ms.', notify: false);
        return;
      }
    }

    _lastSnapshotRequestAt = DateTime.now();
    _log('Requesting snapshot with OSC.', notify: false);
    await _sendCommand(GuoranProtocol.snapshotCommand);
  }

  Future<void> _writeSafetyKey(String payload) async {
    final BluetoothCharacteristic? characteristic = _safetyKeyCharacteristic;
    if (characteristic == null) {
      throw StateError('Safety-key characteristic is not available.');
    }

    _log('Writing safety-key payload "$payload" to ${characteristic.uuid.str}.', notify: false);
    await _writeCharacteristicValue(characteristic, GuoranProtocol.encodeAscii(payload));
  }

  Future<void> _sendCommand(String command) async {
    final BluetoothCharacteristic? characteristic = _writeCharacteristic;
    if (characteristic == null) {
      throw StateError('Write characteristic is not available.');
    }

    _log('Sending command "$command" via ${characteristic.uuid.str}.', notify: false);
    await _writeCharacteristicValue(characteristic, GuoranProtocol.encodeAscii(command));
  }

  Future<void> _writeCharacteristicValue(
    BluetoothCharacteristic characteristic,
    List<int> payload,
  ) async {
    final bool withoutResponse = characteristic.properties.writeWithoutResponse && !characteristic.properties.write;
    _log(
      'Write ${characteristic.uuid.str} hex=${_formatHex(payload)} withoutResponse=$withoutResponse.',
      notify: false,
    );
    await characteristic.write(payload, withoutResponse: withoutResponse);
  }

  Future<void> _disconnectCurrentDevice() async {
    _stopSystemTimeUpdates();
    await _readValueSubscription?.cancel();
    _readValueSubscription = null;
    await _safetyKeyValueSubscription?.cancel();
    _safetyKeyValueSubscription = null;

    final BluetoothDevice? device = _connectedDevice;
    if (device == null) {
      return;
    }

    _log('Disconnecting from ${device.remoteId.str}.', notify: false);
    try {
      await device.disconnect(queue: false);
    } catch (_) {
      try {
        await device.disconnect();
      } catch (_) {}
    }
  }

  void _handleScanResults(List<ScanResult> results) {
    final List<ScanResult> filtered = results.where(_isGuoranDevice).toList()
      ..sort((ScanResult left, ScanResult right) => right.rssi.compareTo(left.rssi));
    _scanResults = filtered;
    if (_isScanning) {
      _statusMessage = filtered.isEmpty ? 'Scanning for XGGF devices...' : 'Select a clock to connect.';
    }
    notifyListeners();
  }

  bool _isGuoranDevice(ScanResult result) {
    final String normalizedName = _deviceLabel(result).toUpperCase();
    if (normalizedName.startsWith('XGGF')) {
      return true;
    }

    return result.advertisementData.serviceUuids.any(
      (Guid guid) => GuoranProtocol.matchesShortUuid(guid.str, GuoranProtocol.scanServices.first) ||
          GuoranProtocol.matchesShortUuid(guid.str, GuoranProtocol.scanServices.last),
    );
  }

  String _deviceLabel(ScanResult result) {
    final String platformName = result.device.platformName.trim();
    if (platformName.isNotEmpty) {
      return platformName;
    }
    final String advertisementName = result.advertisementData.advName.trim();
    if (advertisementName.isNotEmpty) {
      return advertisementName;
    }
    return result.device.remoteId.str;
  }

  BluetoothService _requireService(List<BluetoothService> services, String shortUuid) {
    for (final BluetoothService service in services) {
      if (GuoranProtocol.matchesShortUuid(service.uuid.str, shortUuid)) {
        return service;
      }
    }
    throw StateError('Missing required service $shortUuid.');
  }

  BluetoothCharacteristic _requireCharacteristic(BluetoothService service, String shortUuid) {
    for (final BluetoothCharacteristic characteristic in service.characteristics) {
      if (GuoranProtocol.matchesShortUuid(characteristic.uuid.str, shortUuid)) {
        return characteristic;
      }
    }
    throw StateError('Missing required characteristic $shortUuid in ${service.uuid.str}.');
  }

  List<String> _describeServices(List<BluetoothService> services) {
    if (services.isEmpty) {
      return const <String>['No services discovered.'];
    }

    return services.map<String>((BluetoothService service) {
      final Iterable<String> characteristicDescriptions = service.characteristics.map<String>(
        (BluetoothCharacteristic characteristic) =>
            '  - ${characteristic.uuid.str} ${_describeCharacteristicProperties(characteristic)}',
      );

      return <String>[
        'Service ${service.uuid.str}',
        ...characteristicDescriptions,
      ].join('\n');
    }).toList(growable: false);
  }

  String _describeCharacteristicProperties(BluetoothCharacteristic characteristic) {
    final CharacteristicProperties properties = characteristic.properties;
    final List<String> flags = <String>[];

    if (properties.read) {
      flags.add('read');
    }
    if (properties.write) {
      flags.add('write');
    }
    if (properties.writeWithoutResponse) {
      flags.add('writeWithoutResponse');
    }
    if (properties.notify) {
      flags.add('notify');
    }
    if (properties.indicate) {
      flags.add('indicate');
    }

    return flags.isEmpty ? '(no common properties exposed)' : '(${flags.join(', ')})';
  }

  void _logServiceDiagnostics() {
    for (final String entry in _serviceDiagnostics) {
      _log(entry, notify: false);
    }
  }

  Future<bool> _ensurePermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
      return true;
    }

    if (Platform.isAndroid) {
      final Map<Permission, PermissionStatus> statuses = await <Permission>[
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();

      final bool canScan =
          (statuses[Permission.bluetoothScan]?.isGranted ?? false) || (statuses[Permission.locationWhenInUse]?.isGranted ?? false);
      final bool canConnect =
          (statuses[Permission.bluetoothConnect]?.isGranted ?? false) || (statuses[Permission.locationWhenInUse]?.isGranted ?? false);

      _log(
        'Android permissions: scan=${statuses[Permission.bluetoothScan]?.name} '
        'connect=${statuses[Permission.bluetoothConnect]?.name} '
        'location=${statuses[Permission.locationWhenInUse]?.name}',
        notify: false,
      );

      if (canScan && canConnect) {
        return true;
      }

      _setError('Bluetooth scan/connect permissions are required on Android.');
      return false;
    }

    return true;
  }

  void _startSystemTimeUpdates() {
    _systemTimeTimer?.cancel();
    _log('Started system time updates.', notify: false);
    _systemTimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(syncCurrentSystemTimeNow());
    });
    unawaited(syncCurrentSystemTimeNow());
  }

  void _stopSystemTimeUpdates() {
    if (_systemTimeTimer != null) {
      _log('Stopped system time updates.', notify: false);
    }
    _systemTimeTimer?.cancel();
    _systemTimeTimer = null;
  }

  void _clearSession({required bool keepDevice, required bool keepStatus}) {
    _snapshot = null;
    _readCharacteristic = null;
    _writeCharacteristic = null;
    _safetyKeyCharacteristic = null;
    _safetyKeyNotifyCharacteristic = null;
    _safetyKeyAccepted = false;
    _sentFallbackSafetyKey = false;
    _hasObservedConnectedState = false;
    _connectFlowInProgress = false;
    _incomingSnapshotBuffer = '';
    _lastSnapshotRequestAt = null;
    _acquisitionSystemTimeEnabled = false;
    _alarm1Enabled = false;
    _alarm2Enabled = false;
    _timingEnabled = false;
    _alarm1 = '00:00';
    _alarm2 = '00:00';
    _bootTime = '00:00';
    _offTime = '00:00';
    if (!keepDevice) {
      _connectedDevice = null;
      _connectionState = BluetoothConnectionState.disconnected;
      _deviceStateSubscription?.cancel();
      _deviceStateSubscription = null;
    }
    if (!keepStatus) {
      _statusMessage = 'Ready to scan';
      _log('Status -> Ready to scan.', notify: false);
    }
  }

  void _clearError() {
    _errorMessage = null;
  }

  void _setStatus(String message, {bool notify = true}) {
    _statusMessage = message;
    _log('Status -> $message', notify: false);
    if (notify) {
      notifyListeners();
    }
  }

  void _setError(String message) {
    _errorMessage = message;
    _statusMessage = message;
    _log('Error -> $message', notify: false);
    notifyListeners();
  }

  void _log(String message, {bool notify = false}) {
    final DateTime now = DateTime.now();
    final String timestamp =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${(now.millisecond ~/ 10).toString().padLeft(2, '0')}';
    final String line = '[$timestamp] $message';
    _debugLogLines.add(line);
    if (_debugLogLines.length > 250) {
      _debugLogLines.removeRange(0, _debugLogLines.length - 250);
    }
    debugPrint(line);
    notifyListeners();
  }

  String _formatHex(List<int> bytes) {
    return bytes.map((int value) => value.toRadixString(16).padLeft(2, '0')).join(' ');
  }

  String _sanitizeForLog(String value) {
    return value.replaceAll('\n', r'\n').replaceAll('\r', r'\r');
  }
}
