import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'src/guoran_ble_controller.dart';
import 'src/guoran_protocol.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GuoranApp());
}

class GuoranApp extends StatelessWidget {
  const GuoranApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFE85A24),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF7F0E7),
    );

    return MaterialApp(
      title: 'Attractor Field Guoran',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
      ),
      home: const GuoranHomePage(),
    );
  }
}

class GuoranHomePage extends StatefulWidget {
  const GuoranHomePage({super.key});

  @override
  State<GuoranHomePage> createState() => _GuoranHomePageState();
}

class _GuoranHomePageState extends State<GuoranHomePage> {
  late final GuoranBleController _controller;

  @override
  void initState() {
    super.initState();
    _controller = GuoranBleController();
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[Color(0xFFFFF4EA), Color(0xFFF3E6D9)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: <Widget>[
                  _buildHero(context),
                  const SizedBox(height: 16),
                  if (_controller.errorMessage != null) ...<Widget>[
                    _buildErrorCard(context, _controller.errorMessage!),
                    const SizedBox(height: 16),
                  ],
                  _buildBluetoothCard(context),
                  const SizedBox(height: 16),
                  _buildDeviceSection(context),
                  if (_controller.serviceDiagnostics.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    _buildServiceDiagnosticsCard(context),
                  ],
                  if (_controller.debugLogLines.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    _buildDebugReportCard(context),
                  ],
                  if (_controller.connectedDevice != null) ...<Widget>[
                    const SizedBox(height: 16),
                    _buildConnectionCard(context),
                  ],
                  if (_controller.isConnected && !_controller.hasSnapshot) ...<Widget>[
                    const SizedBox(height: 16),
                    _buildHandshakeCard(context),
                  ],
                  if (_controller.hasSnapshot) ...<Widget>[
                    const SizedBox(height: 16),
                    _buildTimeSection(context),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHero(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: <Color>[colors.primary, const Color(0xFFF7A246)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.access_time_filled, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Attractor Field Guoran',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Port of the original DCloud clock app. Implemented so far: scan, connect, safety-key handshake, snapshot sync, and time settings.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _buildPill('Adapter ${_adapterLabel(_controller.adapterState)}'),
              _buildPill(_controller.statusMessage),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECE8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1B8AA)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline, color: Color(0xFF9E3A22)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF7E2A19)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothCard(BuildContext context) {
    return _buildSectionCard(
      context: context,
      title: 'Bluetooth',
      subtitle: 'Scan for nearby clocks that match the original app filters.',
      trailing: FilledButton.icon(
        onPressed: _controller.isBusy
            ? null
            : (_controller.isScanning ? _controller.stopScan : _controller.startScan),
        icon: _controller.isScanning
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.radar),
        label: Text(_controller.isScanning ? 'Stop' : 'Scan'),
      ),
      child: Text(
        _controller.adapterState == BluetoothAdapterState.on
            ? 'The current filter is the same clock family as the DCloud app: XGGF devices or clocks advertising FFB0 / FFF0.'
            : 'Turn Bluetooth on before scanning. Android requires scan and connect permissions the first time you use the app.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.35),
      ),
    );
  }

  Widget _buildDeviceSection(BuildContext context) {
    final List<ScanResult> devices = _controller.scanResults;
    return _buildSectionCard(
      context: context,
      title: 'Nearby Devices',
      subtitle: 'Select one device to connect and run the same handshake as the original app.',
      child: devices.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                _controller.isScanning
                    ? 'Scanning for devices...'
                    : 'No matching devices yet. Start a scan to look for clocks.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : Column(
              children: <Widget>[
                for (int index = 0; index < devices.length; index++) ...<Widget>[
                  _buildDeviceTile(context, devices[index]),
                  if (index < devices.length - 1) const Divider(height: 1),
                ],
              ],
            ),
    );
  }

  Widget _buildDeviceTile(BuildContext context, ScanResult result) {
    final BluetoothDevice? connected = _controller.connectedDevice;
    final bool isSelected = connected != null && connected.remoteId == result.device.remoteId;
    final String name = result.device.platformName.trim().isNotEmpty
        ? result.device.platformName.trim()
        : (result.advertisementData.advName.trim().isNotEmpty
            ? result.advertisementData.advName.trim()
            : result.device.remoteId.str);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: isSelected
            ? Colors.white
            : Theme.of(context).colorScheme.onPrimaryContainer,
        child: const Icon(Icons.watch_later_outlined),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${result.device.remoteId.str}\nRSSI ${result.rssi} dBm'),
      isThreeLine: true,
      trailing: FilledButton(
        onPressed: _controller.isBusy || !result.advertisementData.connectable
            ? null
            : () => _controller.connectToResult(result),
        child: Text(isSelected ? 'Connected' : 'Connect'),
      ),
    );
  }

  Widget _buildConnectionCard(BuildContext context) {
    final BluetoothDevice device = _controller.connectedDevice!;
    return _buildSectionCard(
      context: context,
      title: 'Connected Clock',
      subtitle: _connectionLabel(_controller.connectionState),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          OutlinedButton.icon(
            onPressed: _controller.isBusy ? null : _controller.refreshSnapshot,
            icon: const Icon(Icons.sync),
            label: const Text('Refresh'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: _controller.isBusy ? null : _controller.disconnect,
            icon: const Icon(Icons.bluetooth_disabled),
            label: const Text('Disconnect'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(device.platformName.isNotEmpty ? device.platformName : device.remoteId.str),
          const SizedBox(height: 6),
          Text(
            device.remoteId.str,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildServiceDiagnosticsCard(BuildContext context) {
    return _buildSectionCard(
      context: context,
      title: 'Discovered Services',
      subtitle: 'Full GATT dump from the connected device. Use this to compare against the original app\'s expected FFE0 / FFE5 / FFF0 / FFC0 services.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int index = 0; index < _controller.serviceDiagnostics.length; index++) ...<Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F2EA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE3D5C6)),
              ),
              child: SelectableText(
                _controller.serviceDiagnostics[index],
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      height: 1.45,
                    ),
              ),
            ),
            if (index < _controller.serviceDiagnostics.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildDebugReportCard(BuildContext context) {
    return _buildSectionCard(
      context: context,
      title: 'Debug Report',
      subtitle: 'Copy this block into chat. It includes the current BLE state, resolved UUIDs, service dump, and recent event log.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: _copyDebugReport,
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text('Copy Report'),
              ),
              OutlinedButton.icon(
                onPressed: _controller.clearDebugLog,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear Log'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 360),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F2EA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE3D5C6)),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                _controller.debugReport,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      height: 1.45,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandshakeCard(BuildContext context) {
    return _buildSectionCard(
      context: context,
      title: 'Handshake',
      subtitle: 'Waiting for the same safety-key and OSC snapshot flow used by the DCloud app.',
      child: Row(
        children: <Widget>[
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(_controller.statusMessage)),
        ],
      ),
    );
  }

  Widget _buildTimeSection(BuildContext context) {
    return Column(
      children: <Widget>[
        _buildSectionCard(
          context: context,
          title: 'Device Time Sync',
            subtitle: 'Matches the original app\'s S71/S70 toggle and \$ timestamp payload.',
          child: Column(
            children: <Widget>[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Continuously sync current system time'),
                value: _controller.acquisitionSystemTimeEnabled,
                onChanged: _controller.isBusy ? null : _controller.setAcquisitionSystemTimeEnabled,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: _controller.isBusy ? null : _controller.syncCurrentSystemTimeNow,
                  icon: const Icon(Icons.schedule_send),
                  label: const Text('Send current time now'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildTimeToggleCard(
          context: context,
          title: 'Alarm 1',
          subtitle: 'Uses S81 / S80 and AHH:MMA.',
          enabled: _controller.alarm1Enabled,
          currentValue: _controller.alarm1,
          onToggle: _controller.setAlarm1Enabled,
          onPick: (TimeOfDay value) => _controller.updateAlarm1(value),
        ),
        const SizedBox(height: 16),
        _buildTimeToggleCard(
          context: context,
          title: 'Alarm 2',
          subtitle: 'Uses S91 / S90 and AHH:MMB.',
          enabled: _controller.alarm2Enabled,
          currentValue: _controller.alarm2,
          onToggle: _controller.setAlarm2Enabled,
          onPick: (TimeOfDay value) => _controller.updateAlarm2(value),
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          context: context,
          title: 'Scheduled Power',
          subtitle: 'Uses S01 / S00 plus THH:MMO and THH:MMC.',
          child: Column(
            children: <Widget>[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable boot/off schedule'),
                value: _controller.timingEnabled,
                onChanged: _controller.isBusy ? null : _controller.setTimingEnabled,
              ),
              const SizedBox(height: 8),
              _buildTimePickerRow(
                context: context,
                label: 'Boot time',
                value: _controller.bootTime,
                enabled: _controller.timingEnabled,
                onTap: () => _pickTime('Boot time', _controller.bootTime, _controller.updateBootTime),
              ),
              const SizedBox(height: 12),
              _buildTimePickerRow(
                context: context,
                label: 'Off time',
                value: _controller.offTime,
                enabled: _controller.timingEnabled,
                onTap: () => _pickTime('Off time', _controller.offTime, _controller.updateOffTime),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeToggleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool enabled,
    required String currentValue,
    required ValueChanged<bool> onToggle,
    required Future<void> Function(TimeOfDay value) onPick,
  }) {
    return _buildSectionCard(
      context: context,
      title: title,
      subtitle: subtitle,
      child: Column(
        children: <Widget>[
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enabled'),
            value: enabled,
            onChanged: _controller.isBusy ? null : onToggle,
          ),
          const SizedBox(height: 8),
          _buildTimePickerRow(
            context: context,
            label: 'Time',
            value: currentValue,
            enabled: enabled,
            onTap: () => _pickTime(title, currentValue, onPick),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickerRow({
    required BuildContext context,
    required String label,
    required String value,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled && !_controller.isBusy ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : const Color(0xFFF1E6DA),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE3D5C6)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(value, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            const Icon(Icons.edit_calendar_outlined),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7D8C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: 12),
                trailing,
              ],
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Future<void> _pickTime(
    String title,
    String currentValue,
    Future<void> Function(TimeOfDay value) onConfirm,
  ) async {
    final TimeOfDay initialTime = GuoranProtocol.parseTimeOfDay(currentValue);
    final TimeOfDay? selected = await showTimePicker(
      context: context,
      helpText: title,
      initialTime: initialTime,
    );
    if (selected == null || !context.mounted) {
      return;
    }

    await onConfirm(selected);
  }

  Future<void> _copyDebugReport() async {
    await Clipboard.setData(ClipboardData(text: _controller.debugReport));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Debug report copied to clipboard.')),
    );
  }

  String _adapterLabel(BluetoothAdapterState state) {
    switch (state) {
      case BluetoothAdapterState.on:
        return 'On';
      case BluetoothAdapterState.off:
        return 'Off';
      case BluetoothAdapterState.turningOn:
        return 'Turning On';
      case BluetoothAdapterState.turningOff:
        return 'Turning Off';
      case BluetoothAdapterState.unavailable:
        return 'Unavailable';
      case BluetoothAdapterState.unauthorized:
        return 'Unauthorized';
      case BluetoothAdapterState.unknown:
        return 'Unknown';
    }
  }

  String _connectionLabel(BluetoothConnectionState state) {
    if (state == BluetoothConnectionState.connected) {
      return 'Connected';
    }
    if (state == BluetoothConnectionState.disconnected) {
      return 'Disconnected';
    }
    return '${state.name[0].toUpperCase()}${state.name.substring(1)}';
  }
}
