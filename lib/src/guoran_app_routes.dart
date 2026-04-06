import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'guoran_ble_controller.dart';
import 'guoran_protocol.dart';

class GuoranRouteNames {
  const GuoranRouteNames._();

  static const String discovery = '/';
  static const String device = '/device';
  static const String timeSync = '/settings/time-sync';
  static const String colorConsole = '/settings/color-console';
  static const String operatingButtons = '/settings/operating-buttons';
  static const String alarm = '/settings/alarm';
  static const String scheduledPower = '/settings/scheduled-power';
  static const String otherSettings = '/settings/other-settings';
  static const String debug = '/debug';
}

class GuoranAlarmPageArguments {
  const GuoranAlarmPageArguments({required this.field});

  final GuoranTimeField field;
}

Route<dynamic> buildGuoranRoute(RouteSettings settings, GuoranBleController controller) {
  Widget page;

  switch (settings.name) {
    case GuoranRouteNames.discovery:
      page = GuoranDiscoveryRoutePage(controller: controller);
      break;
    case GuoranRouteNames.device:
      page = GuoranDeviceRoutePage(controller: controller);
      break;
    case GuoranRouteNames.timeSync:
      page = GuoranTimeSyncRoutePage(controller: controller);
      break;
    case GuoranRouteNames.colorConsole:
      page = GuoranColorConsoleRoutePage(controller: controller);
      break;
    case GuoranRouteNames.operatingButtons:
      page = GuoranOperatingButtonsRoutePage(controller: controller);
      break;
    case GuoranRouteNames.alarm:
      final Object? arguments = settings.arguments;
      if (arguments is! GuoranAlarmPageArguments) {
        page = GuoranDiscoveryRoutePage(controller: controller);
      } else {
        page = GuoranAlarmSettingsRoutePage(controller: controller, field: arguments.field);
      }
      break;
    case GuoranRouteNames.scheduledPower:
      page = GuoranScheduledPowerRoutePage(controller: controller);
      break;
    case GuoranRouteNames.otherSettings:
      page = GuoranOtherSettingsRoutePage(controller: controller);
      break;
    case GuoranRouteNames.debug:
      page = GuoranDebugRoutePage(controller: controller);
      break;
    default:
      page = GuoranDiscoveryRoutePage(controller: controller);
      break;
  }

  return MaterialPageRoute<void>(builder: (BuildContext context) => page, settings: settings);
}

class GuoranDiscoveryRoutePage extends StatelessWidget {
  const GuoranDiscoveryRoutePage({super.key, required this.controller});

  final GuoranBleController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final List<ScanResult> devices = controller.scanResults;
        return Scaffold(
          body: GuoranGradientPage(
            topSafeArea: true,
            children: <Widget>[
              _buildHero(context),
              const SizedBox(height: 16),
              if (controller.errorMessage != null) ...<Widget>[
                GuoranMessageCard(
                  icon: Icons.error_outline,
                  title: 'Bluetooth Error',
                  message: controller.errorMessage!,
                  backgroundColor: const Color(0xFFFFECE8),
                  borderColor: const Color(0xFFF1B8AA),
                  foregroundColor: const Color(0xFF7E2A19),
                ),
                const SizedBox(height: 16),
              ],
              GuoranSectionCard(
                title: 'Service Discovery',
                subtitle: 'Scanning starts automatically when Bluetooth becomes available. You can also control it manually here.',
                trailing: FilledButton.icon(
                  onPressed: controller.isBusy ? null : (controller.isScanning ? controller.stopScan : controller.startScan),
                  icon: controller.isScanning
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.radar),
                  label: Text(controller.isScanning ? 'Stop' : 'Scan'),
                ),
                child: Text(
                  controller.adapterState == BluetoothAdapterState.on
                      ? 'The scan filter matches the original app: XGGF devices or clocks advertising FFB0 / FFF0.'
                      : 'Turn Bluetooth on and the app will start scanning immediately after the adapter becomes ready.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.35),
                ),
              ),
              const SizedBox(height: 16),
              GuoranSectionCard(
                title: 'Nearby Devices',
                subtitle: 'Connect to a discovered clock to open its device page and setting routes.',
                child: devices.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          controller.isScanning
                              ? 'Scanning for matching devices...'
                              : 'No matching devices yet. The app will scan automatically when Bluetooth is ready.',
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
              ),
            ],
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
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.bluetooth_searching, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Attractor Field Guoran',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Start on service discovery, connect to a device, then move through dedicated pages to save each setting back to the clock.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.92), height: 1.35),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[_buildPill('Adapter ${_adapterLabel(controller.adapterState)}'), _buildPill(controller.statusMessage)],
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildDeviceTile(BuildContext context, ScanResult result) {
    final BluetoothDevice? connected = controller.connectedDevice;
    final bool isSelected = connected != null && connected.remoteId == result.device.remoteId;
    final bool canOpen = isSelected && controller.isConnected;
    final String name = _scanResultLabel(result);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: isSelected ? Colors.white : Theme.of(context).colorScheme.onPrimaryContainer,
        child: const Icon(Icons.watch_later_outlined),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${result.device.remoteId.str}\nRSSI ${result.rssi} dBm'),
      isThreeLine: true,
      trailing: FilledButton(
        onPressed: canOpen
            ? () => Navigator.of(context).pushReplacementNamed(GuoranRouteNames.device)
            : (controller.isBusy || !result.advertisementData.connectable ? null : () => _connectToDevice(context, result)),
        child: Text(canOpen ? 'Open' : 'Connect'),
      ),
    );
  }

  Future<void> _connectToDevice(BuildContext context, ScanResult result) async {
    await controller.connectToResult(result);
    if (!context.mounted) {
      return;
    }

    if (controller.connectedDevice?.remoteId == result.device.remoteId) {
      Navigator.of(context).pushReplacementNamed(GuoranRouteNames.device);
      return;
    }

    _showResultSnackBar(context, success: false, message: controller.errorMessage ?? 'Unable to connect to the selected device.');
  }
}

class GuoranDeviceRoutePage extends StatelessWidget {
  const GuoranDeviceRoutePage({super.key, required this.controller});

  final GuoranBleController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final BluetoothDevice? device = controller.connectedDevice;
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(device == null ? 'Device' : _deviceLabel(device)),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          body: GuoranGradientPage(
            children: device == null
                ? <Widget>[
                    GuoranSectionCard(
                      title: 'No Connected Device',
                      subtitle: 'The active connection is no longer available.',
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(context).pushReplacementNamed(GuoranRouteNames.discovery),
                          icon: const Icon(Icons.radar),
                          label: const Text('Back to discovery'),
                        ),
                      ),
                    ),
                  ]
                : <Widget>[
                    _buildDeviceSummary(context, device),
                    const SizedBox(height: 16),
                    if (controller.errorMessage != null) ...<Widget>[
                      GuoranMessageCard(
                        icon: Icons.error_outline,
                        title: 'Device Error',
                        message: controller.errorMessage!,
                        backgroundColor: const Color(0xFFFFECE8),
                        borderColor: const Color(0xFFF1B8AA),
                        foregroundColor: const Color(0xFF7E2A19),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (controller.isSnapshotPending) ...<Widget>[
                      GuoranSectionCard(
                        title: 'Waiting for device snapshot',
                        subtitle:
                            'The OSC snapshot is still loading. Device Time Sync, Color Console, Operating Buttons, and Other Settings are available now. Alarm and scheduled power stay disabled until the snapshot is ready.',
                        child: Row(
                          children: <Widget>[
                            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)),
                            const SizedBox(width: 12),
                            Expanded(child: Text(controller.statusMessage)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    GuoranNavigationCard(
                      title: 'Device Time Sync',
                      subtitle: controller.hasSnapshot
                          ? (controller.acquisitionSystemTimeEnabled
                                ? 'Currently following the current time from the phone.'
                                : 'Send a manual time or switch back to current time.')
                          : controller.canSendCommandsWithoutSnapshot
                          ? 'Available now. You can send current or manual time while the snapshot is still loading.'
                          : 'Waiting for the device handshake before time controls can be edited.',
                      icon: Icons.schedule,
                      enabled: controller.canSendTimeWithoutSnapshot,
                      onTap: () => Navigator.of(context).pushNamed(GuoranRouteNames.timeSync),
                    ),
                    const SizedBox(height: 12),
                    GuoranNavigationCard(
                      title: 'Color Console',
                      subtitle: controller.hasSnapshot
                          ? _colorConsoleSummary(controller)
                          : controller.canSendCommandsWithoutSnapshot
                          ? 'Send RGB color, light-channel toggles, and K01-K03 commands now.'
                          : 'Waiting for the device handshake before color commands can be sent.',
                      icon: Icons.palette_outlined,
                      enabled: controller.canSendCommandsWithoutSnapshot,
                      onTap: () => Navigator.of(context).pushNamed(GuoranRouteNames.colorConsole),
                    ),
                    const SizedBox(height: 12),
                    GuoranNavigationCard(
                      title: 'Operating Buttons',
                      subtitle: controller.canSendCommandsWithoutSnapshot
                          ? 'Send K04-K09 button presses immediately, without waiting for the OSC snapshot.'
                          : 'Waiting for the device handshake before operating buttons can be sent.',
                      icon: Icons.tune,
                      enabled: controller.canSendCommandsWithoutSnapshot,
                      onTap: () => Navigator.of(context).pushNamed(GuoranRouteNames.operatingButtons),
                    ),
                    const SizedBox(height: 12),
                    GuoranNavigationCard(
                      title: 'Alarm 1',
                      subtitle: controller.hasSnapshot
                          ? _alarmSummary(enabled: controller.alarm1Enabled, value: controller.alarm1)
                          : 'Waiting for snapshot before alarm settings can be edited.',
                      icon: Icons.alarm,
                      enabled: controller.hasSnapshot,
                      onTap: () => Navigator.of(
                        context,
                      ).pushNamed(GuoranRouteNames.alarm, arguments: const GuoranAlarmPageArguments(field: GuoranTimeField.alarm1)),
                    ),
                    const SizedBox(height: 12),
                    GuoranNavigationCard(
                      title: 'Alarm 2',
                      subtitle: controller.hasSnapshot
                          ? _alarmSummary(enabled: controller.alarm2Enabled, value: controller.alarm2)
                          : 'Waiting for snapshot before alarm settings can be edited.',
                      icon: Icons.alarm_add_outlined,
                      enabled: controller.hasSnapshot,
                      onTap: () => Navigator.of(
                        context,
                      ).pushNamed(GuoranRouteNames.alarm, arguments: const GuoranAlarmPageArguments(field: GuoranTimeField.alarm2)),
                    ),
                    const SizedBox(height: 12),
                    GuoranNavigationCard(
                      title: 'Scheduled Power',
                      subtitle: controller.hasSnapshot
                          ? '${controller.timingEnabled ? 'Enabled' : 'Disabled'} · Boot ${controller.bootTime} · Off ${controller.offTime}'
                          : 'Waiting for snapshot before scheduled power can be edited.',
                      icon: Icons.power_settings_new,
                      enabled: controller.hasSnapshot,
                      onTap: () => Navigator.of(context).pushNamed(GuoranRouteNames.scheduledPower),
                    ),
                    const SizedBox(height: 12),
                    GuoranNavigationCard(
                      title: 'Other Settings',
                      subtitle: controller.hasSnapshot
                          ? _otherSettingsSummary(controller)
                          : controller.canSendCommandsWithoutSnapshot
                          ? 'Toggle the SA-SF options now. Snapshot data will still load in the background.'
                          : 'Waiting for the device handshake before other settings can be changed.',
                      icon: Icons.settings_suggest_outlined,
                      enabled: controller.canSendCommandsWithoutSnapshot,
                      onTap: () => Navigator.of(context).pushNamed(GuoranRouteNames.otherSettings),
                    ),
                    const SizedBox(height: 12),
                    GuoranNavigationCard(
                      title: 'Debug',
                      subtitle:
                          'Open the debug card with the recent report and ${controller.serviceDiagnostics.length} discovered service block(s).',
                      icon: Icons.bug_report_outlined,
                      enabled: true,
                      onTap: () => Navigator.of(context).pushNamed(GuoranRouteNames.debug),
                    ),
                  ],
          ),
        );
      },
    );
  }

  Widget _buildDeviceSummary(BuildContext context, BluetoothDevice device) {
    return GuoranSectionCard(
      title: 'Connected Device',
      subtitle: _connectionLabel(controller.connectionState),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(device.remoteId.str, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _buildSummaryPill(context, controller.hasSnapshot ? 'Snapshot ready' : 'Snapshot pending'),
              _buildSummaryPill(context, controller.statusMessage),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: controller.isBusy ? null : controller.refreshSnapshot,
                icon: const Icon(Icons.sync),
                label: const Text('Retry snapshot'),
              ),
              FilledButton.tonalIcon(
                onPressed: controller.isBusy ? null : () => _disconnectAndReturn(context),
                icon: const Icon(Icons.bluetooth_disabled),
                label: const Text('Disconnect'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPill(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _disconnectAndReturn(BuildContext context) async {
    await controller.disconnect();
    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pushReplacementNamed(GuoranRouteNames.discovery);
    unawaited(controller.startScan());
  }
}

class GuoranTimeSyncRoutePage extends StatefulWidget {
  const GuoranTimeSyncRoutePage({super.key, required this.controller});

  final GuoranBleController controller;

  @override
  State<GuoranTimeSyncRoutePage> createState() => _GuoranTimeSyncRoutePageState();
}

class _GuoranTimeSyncRoutePageState extends State<GuoranTimeSyncRoutePage> {
  late bool _useCurrentTime;
  late TimeOfDay _manualTime;

  @override
  void initState() {
    super.initState();
    _useCurrentTime = widget.controller.acquisitionSystemTimeEnabled;
    _manualTime = TimeOfDay.fromDateTime(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final bool enabled = widget.controller.canSendTimeWithoutSnapshot && widget.controller.connectedDevice != null;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Device Time Sync'),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          body: GuoranGradientPage(
            children: <Widget>[
              if (!enabled) ...<Widget>[
                GuoranMessageCard(
                  icon: Icons.hourglass_bottom,
                  title: 'Handshake Required',
                  message: 'Wait for the device handshake to finish before changing time settings.',
                  backgroundColor: const Color(0xFFF7F1DF),
                  borderColor: const Color(0xFFE7D59D),
                  foregroundColor: const Color(0xFF6A5720),
                ),
                const SizedBox(height: 16),
              ],
              if (enabled && !widget.controller.hasSnapshot) ...<Widget>[
                const GuoranMessageCard(
                  icon: Icons.schedule_send,
                  title: 'Snapshot Still Loading',
                  message: 'Device time sync does not need the OSC snapshot. You can send the current time or a manual time now.',
                  backgroundColor: Color(0xFFE8F3EC),
                  borderColor: Color(0xFFB6D8C2),
                  foregroundColor: Color(0xFF1F5A34),
                ),
                const SizedBox(height: 16),
              ],
              if (widget.controller.errorMessage != null) ...<Widget>[
                GuoranMessageCard(
                  icon: Icons.error_outline,
                  title: 'Save Error',
                  message: widget.controller.errorMessage!,
                  backgroundColor: const Color(0xFFFFECE8),
                  borderColor: const Color(0xFFF1B8AA),
                  foregroundColor: const Color(0xFF7E2A19),
                ),
                const SizedBox(height: 16),
              ],
              GuoranSectionCard(
                title: 'Time Source',
                subtitle: 'Use the Material time picker for a manual send, or switch to the current time from the phone and save it.',
                enabled: enabled,
                child: Column(
                  children: <Widget>[
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Use current time'),
                      subtitle: const Text('When enabled, the device keeps following the phone time.'),
                      value: _useCurrentTime,
                      onChanged: widget.controller.isBusy || !enabled
                          ? null
                          : (bool value) {
                              setState(() {
                                _useCurrentTime = value;
                              });
                            },
                    ),
                    const SizedBox(height: 8),
                    GuoranTimeValueTile(
                      label: 'Manual time',
                      value: GuoranProtocol.formatTimeOfDay(_manualTime),
                      enabled: !_useCurrentTime && enabled,
                      onTap: widget.controller.isBusy || _useCurrentTime || !enabled ? null : () => _pickManualTime(context),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _useCurrentTime
                            ? 'Save will send the current date and time, then keep the clock in sync.'
                            : 'Save sends today\'s date with the selected manual time.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.controller.isBusy || !enabled ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(widget.controller.isBusy ? 'Saving...' : 'Save to device'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickManualTime(BuildContext context) async {
    final TimeOfDay? selected = await showTimePicker(context: context, helpText: 'Manual device time', initialTime: _manualTime);
    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _manualTime = selected;
    });
  }

  Future<void> _save() async {
    try {
      await widget.controller.saveDeviceTimeSettings(useCurrentTime: _useCurrentTime, manualTime: _manualTime);
      if (!mounted) {
        return;
      }
      _showResultSnackBar(
        context,
        success: true,
        message: _useCurrentTime ? 'Device time is now following the current time.' : 'Manual device time sent.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showResultSnackBar(context, success: false, message: widget.controller.errorMessage ?? 'Unable to save the device time.');
    }
  }
}

class GuoranAlarmSettingsRoutePage extends StatefulWidget {
  const GuoranAlarmSettingsRoutePage({super.key, required this.controller, required this.field});

  final GuoranBleController controller;
  final GuoranTimeField field;

  @override
  State<GuoranAlarmSettingsRoutePage> createState() => _GuoranAlarmSettingsRoutePageState();
}

class _GuoranAlarmSettingsRoutePageState extends State<GuoranAlarmSettingsRoutePage> {
  late bool _enabled;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _enabled = _alarmEnabled(widget.controller, widget.field);
    _selectedTime = GuoranProtocol.parseTimeOfDay(_alarmValue(widget.controller, widget.field));
  }

  @override
  Widget build(BuildContext context) {
    final String title = _alarmTitle(widget.field);
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final bool pageEnabled = widget.controller.hasSnapshot && widget.controller.connectedDevice != null;
        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          body: GuoranGradientPage(
            children: <Widget>[
              if (!pageEnabled) ...<Widget>[
                GuoranMessageCard(
                  icon: Icons.hourglass_bottom,
                  title: 'Snapshot Required',
                  message: 'Wait for the device snapshot before changing this alarm.',
                  backgroundColor: const Color(0xFFF7F1DF),
                  borderColor: const Color(0xFFE7D59D),
                  foregroundColor: const Color(0xFF6A5720),
                ),
                const SizedBox(height: 16),
              ],
              if (widget.controller.errorMessage != null) ...<Widget>[
                GuoranMessageCard(
                  icon: Icons.error_outline,
                  title: 'Save Error',
                  message: widget.controller.errorMessage!,
                  backgroundColor: const Color(0xFFFFECE8),
                  borderColor: const Color(0xFFF1B8AA),
                  foregroundColor: const Color(0xFF7E2A19),
                ),
                const SizedBox(height: 16),
              ],
              GuoranSectionCard(
                title: title,
                subtitle: _alarmRouteSubtitle(widget.field),
                enabled: pageEnabled,
                child: Column(
                  children: <Widget>[
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enabled'),
                      value: _enabled,
                      onChanged: widget.controller.isBusy || !pageEnabled
                          ? null
                          : (bool value) {
                              setState(() {
                                _enabled = value;
                              });
                            },
                    ),
                    const SizedBox(height: 8),
                    GuoranTimeValueTile(
                      label: 'Alarm time',
                      value: GuoranProtocol.formatTimeOfDay(_selectedTime),
                      enabled: _enabled && pageEnabled,
                      onTap: widget.controller.isBusy || !_enabled || !pageEnabled ? null : () => _pickAlarmTime(context, title),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.controller.isBusy || !pageEnabled ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(widget.controller.isBusy ? 'Saving...' : 'Save to device'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAlarmTime(BuildContext context, String title) async {
    final TimeOfDay? selected = await showTimePicker(context: context, helpText: title, initialTime: _selectedTime);
    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _selectedTime = selected;
    });
  }

  Future<void> _save() async {
    try {
      await widget.controller.saveAlarmSettings(field: widget.field, enabled: _enabled, time: _selectedTime);
      if (!mounted) {
        return;
      }
      _showResultSnackBar(context, success: true, message: '${_alarmTitle(widget.field)} saved to the device.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showResultSnackBar(
        context,
        success: false,
        message: widget.controller.errorMessage ?? 'Unable to save ${_alarmTitle(widget.field).toLowerCase()}.',
      );
    }
  }
}

class GuoranScheduledPowerRoutePage extends StatefulWidget {
  const GuoranScheduledPowerRoutePage({super.key, required this.controller});

  final GuoranBleController controller;

  @override
  State<GuoranScheduledPowerRoutePage> createState() => _GuoranScheduledPowerRoutePageState();
}

class _GuoranScheduledPowerRoutePageState extends State<GuoranScheduledPowerRoutePage> {
  late bool _enabled;
  late TimeOfDay _bootTime;
  late TimeOfDay _offTime;

  @override
  void initState() {
    super.initState();
    _enabled = widget.controller.timingEnabled;
    _bootTime = GuoranProtocol.parseTimeOfDay(widget.controller.bootTime);
    _offTime = GuoranProtocol.parseTimeOfDay(widget.controller.offTime);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final bool pageEnabled = widget.controller.hasSnapshot && widget.controller.connectedDevice != null;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Scheduled Power'),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          body: GuoranGradientPage(
            children: <Widget>[
              if (!pageEnabled) ...<Widget>[
                GuoranMessageCard(
                  icon: Icons.hourglass_bottom,
                  title: 'Snapshot Required',
                  message: 'Wait for the device snapshot before changing the boot and off schedule.',
                  backgroundColor: const Color(0xFFF7F1DF),
                  borderColor: const Color(0xFFE7D59D),
                  foregroundColor: const Color(0xFF6A5720),
                ),
                const SizedBox(height: 16),
              ],
              if (widget.controller.errorMessage != null) ...<Widget>[
                GuoranMessageCard(
                  icon: Icons.error_outline,
                  title: 'Save Error',
                  message: widget.controller.errorMessage!,
                  backgroundColor: const Color(0xFFFFECE8),
                  borderColor: const Color(0xFFF1B8AA),
                  foregroundColor: const Color(0xFF7E2A19),
                ),
                const SizedBox(height: 16),
              ],
              GuoranSectionCard(
                title: 'Boot and Off Schedule',
                subtitle: 'Choose whether the schedule is active, then save both boot and off times together.',
                enabled: pageEnabled,
                child: Column(
                  children: <Widget>[
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable scheduled power'),
                      value: _enabled,
                      onChanged: widget.controller.isBusy || !pageEnabled
                          ? null
                          : (bool value) {
                              setState(() {
                                _enabled = value;
                              });
                            },
                    ),
                    const SizedBox(height: 8),
                    GuoranTimeValueTile(
                      label: 'Boot time',
                      value: GuoranProtocol.formatTimeOfDay(_bootTime),
                      enabled: _enabled && pageEnabled,
                      onTap: widget.controller.isBusy || !_enabled || !pageEnabled
                          ? null
                          : () => _pickTime(context, 'Boot time', _bootTime, (TimeOfDay value) {
                              setState(() {
                                _bootTime = value;
                              });
                            }),
                    ),
                    const SizedBox(height: 12),
                    GuoranTimeValueTile(
                      label: 'Off time',
                      value: GuoranProtocol.formatTimeOfDay(_offTime),
                      enabled: _enabled && pageEnabled,
                      onTap: widget.controller.isBusy || !_enabled || !pageEnabled
                          ? null
                          : () => _pickTime(context, 'Off time', _offTime, (TimeOfDay value) {
                              setState(() {
                                _offTime = value;
                              });
                            }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.controller.isBusy || !pageEnabled ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(widget.controller.isBusy ? 'Saving...' : 'Save to device'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickTime(BuildContext context, String helpText, TimeOfDay currentValue, ValueChanged<TimeOfDay> onSelected) async {
    final TimeOfDay? selected = await showTimePicker(context: context, helpText: helpText, initialTime: currentValue);
    if (selected == null || !mounted) {
      return;
    }

    onSelected(selected);
  }

  Future<void> _save() async {
    try {
      await widget.controller.saveScheduledPowerSettings(enabled: _enabled, bootTime: _bootTime, offTime: _offTime);
      if (!mounted) {
        return;
      }
      _showResultSnackBar(context, success: true, message: 'Scheduled power saved to the device.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showResultSnackBar(
        context,
        success: false,
        message: widget.controller.errorMessage ?? 'Unable to save the scheduled power settings.',
      );
    }
  }
}

class GuoranColorConsoleRoutePage extends StatefulWidget {
  const GuoranColorConsoleRoutePage({super.key, required this.controller});

  final GuoranBleController controller;

  @override
  State<GuoranColorConsoleRoutePage> createState() => _GuoranColorConsoleRoutePageState();
}

class _GuoranColorConsoleRoutePageState extends State<GuoranColorConsoleRoutePage> {
  late double _colorSliderValue;
  late List<bool> _lightSwitches;

  @override
  void initState() {
    super.initState();
    _colorSliderValue = widget.controller.colorSliderValue.toDouble();
    _lightSwitches = _normalizedLightSwitches(widget.controller.lightSwitches);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final bool pageEnabled = widget.controller.canSendCommandsWithoutSnapshot && widget.controller.connectedDevice != null;
        final int sliderValue = _colorSliderValue.round();
        final Color previewColor = GuoranProtocol.colorFromSliderValue(sliderValue);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Color Console'),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          body: GuoranGradientPage(
            children: <Widget>[
              if (!pageEnabled) ...<Widget>[
                GuoranMessageCard(
                  icon: Icons.hourglass_bottom,
                  title: 'Handshake Required',
                  message: 'Wait for the device handshake to finish before sending color or light commands.',
                  backgroundColor: const Color(0xFFF7F1DF),
                  borderColor: const Color(0xFFE7D59D),
                  foregroundColor: const Color(0xFF6A5720),
                ),
                const SizedBox(height: 16),
              ],
              if (pageEnabled && !widget.controller.hasSnapshot) ...<Widget>[
                const GuoranMessageCard(
                  icon: Icons.palette_outlined,
                  title: 'Snapshot Still Loading',
                  message:
                      'Color commands do not need the OSC snapshot. The current values may update after sync finishes, but you can send new ones now.',
                  backgroundColor: Color(0xFFE8F3EC),
                  borderColor: Color(0xFFB6D8C2),
                  foregroundColor: Color(0xFF1F5A34),
                ),
                const SizedBox(height: 16),
              ],
              if (widget.controller.errorMessage != null) ...<Widget>[
                GuoranMessageCard(
                  icon: Icons.error_outline,
                  title: 'Send Error',
                  message: widget.controller.errorMessage!,
                  backgroundColor: const Color(0xFFFFECE8),
                  borderColor: const Color(0xFFF1B8AA),
                  foregroundColor: const Color(0xFF7E2A19),
                ),
                const SizedBox(height: 16),
              ],
              GuoranSectionCard(
                title: 'RGB Color',
                subtitle: 'This matches the source app\'s 0-1530 rainbow slider. Save sends one Rxxx-Gxxx-Bxxx command.',
                enabled: pageEnabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: previewColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: previewColor.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(color: previewColor, borderRadius: BorderRadius.circular(18)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text('Preview ${_colorHexLabel(sliderValue)}', style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 4),
                                Text(
                                  GuoranProtocol.buildColorCommand(sliderValue),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Slider(
                      min: 0,
                      max: GuoranProtocol.maxColorSliderValue.toDouble(),
                      value: _colorSliderValue.clamp(0, GuoranProtocol.maxColorSliderValue.toDouble()),
                      onChanged: widget.controller.isBusy || !pageEnabled
                          ? null
                          : (double value) {
                              setState(() {
                                _colorSliderValue = value;
                              });
                            },
                    ),
                    Text(
                      'Slider value $sliderValue of ${GuoranProtocol.maxColorSliderValue}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GuoranSectionCard(
                title: 'Color Actions',
                subtitle: 'These match K01, K02, and K03 in the source app and send immediately.',
                enabled: pageEnabled,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    for (final _GuoranActionDescriptor action in _colorConsoleActions)
                      SizedBox(
                        width: 108,
                        child: OutlinedButton.icon(
                          onPressed: widget.controller.isBusy || !pageEnabled ? null : () => _sendAction(action),
                          icon: Icon(action.icon),
                          label: Text(action.label),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GuoranSectionCard(
                title: 'Light Switches',
                subtitle: 'Set the six S11-S61 channels here, then save them together with the selected RGB value.',
                enabled: pageEnabled,
                child: Column(
                  children: <Widget>[
                    for (int index = 0; index < _lightSwitches.length; index++) ...<Widget>[
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_lightSwitchLabels[index]),
                        subtitle: Text(_lightSwitches[index] ? 'Enabled' : 'Disabled'),
                        value: _lightSwitches[index],
                        onChanged: widget.controller.isBusy || !pageEnabled
                            ? null
                            : (bool value) {
                                setState(() {
                                  _lightSwitches[index] = value;
                                });
                              },
                      ),
                      if (index < _lightSwitches.length - 1) const Divider(height: 1),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.controller.isBusy || !pageEnabled ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(widget.controller.isBusy ? 'Saving...' : 'Save to device'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<bool> _normalizedLightSwitches(List<bool> source) {
    final List<bool> normalized = List<bool>.filled(GuoranProtocol.lightSwitchCount, false, growable: false);
    for (int index = 0; index < normalized.length && index < source.length; index++) {
      normalized[index] = source[index];
    }
    return normalized;
  }

  Future<void> _sendAction(_GuoranActionDescriptor action) async {
    try {
      await widget.controller.sendColorConsoleAction(action.command, successMessage: action.successMessage);
      if (!mounted) {
        return;
      }
      _showResultSnackBar(context, success: true, message: action.successMessage);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showResultSnackBar(context, success: false, message: widget.controller.errorMessage ?? 'Unable to send ${action.label}.');
    }
  }

  Future<void> _save() async {
    try {
      await widget.controller.saveColorConsoleSettings(
        colorSliderValue: _colorSliderValue.round(),
        lightSwitches: List<bool>.from(_lightSwitches, growable: false),
      );
      if (!mounted) {
        return;
      }
      _showResultSnackBar(context, success: true, message: 'Color console saved to the device.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showResultSnackBar(context, success: false, message: widget.controller.errorMessage ?? 'Unable to save the color console.');
    }
  }
}

class GuoranOperatingButtonsRoutePage extends StatelessWidget {
  const GuoranOperatingButtonsRoutePage({super.key, required this.controller});

  final GuoranBleController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final bool pageEnabled = controller.canSendCommandsWithoutSnapshot && controller.connectedDevice != null;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Operating Buttons'),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          body: GuoranGradientPage(
            children: <Widget>[
              if (!pageEnabled) ...<Widget>[
                GuoranMessageCard(
                  icon: Icons.hourglass_bottom,
                  title: 'Handshake Required',
                  message: 'Wait for the device handshake to finish before sending operating button presses.',
                  backgroundColor: const Color(0xFFF7F1DF),
                  borderColor: const Color(0xFFE7D59D),
                  foregroundColor: const Color(0xFF6A5720),
                ),
                const SizedBox(height: 16),
              ],
              if (pageEnabled && !controller.hasSnapshot) ...<Widget>[
                const GuoranMessageCard(
                  icon: Icons.touch_app_outlined,
                  title: 'Immediate Commands',
                  message: 'These buttons map to K04-K09 and do not require the OSC snapshot. Each press sends immediately.',
                  backgroundColor: Color(0xFFE8F3EC),
                  borderColor: Color(0xFFB6D8C2),
                  foregroundColor: Color(0xFF1F5A34),
                ),
                const SizedBox(height: 16),
              ],
              if (controller.errorMessage != null) ...<Widget>[
                GuoranMessageCard(
                  icon: Icons.error_outline,
                  title: 'Send Error',
                  message: controller.errorMessage!,
                  backgroundColor: const Color(0xFFFFECE8),
                  borderColor: const Color(0xFFF1B8AA),
                  foregroundColor: const Color(0xFF7E2A19),
                ),
                const SizedBox(height: 16),
              ],
              GuoranSectionCard(
                title: 'Operating Buttons',
                subtitle: 'These match the source app\'s K04-K09 actions. Each tile sends a command as soon as you tap it.',
                enabled: pageEnabled,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _operatingButtonActions.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.9,
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    final _GuoranActionDescriptor action = _operatingButtonActions[index];
                    return FilledButton.tonalIcon(
                      onPressed: controller.isBusy || !pageEnabled ? null : () => _sendAction(context, action),
                      icon: Icon(action.icon),
                      label: Text(action.label),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendAction(BuildContext context, _GuoranActionDescriptor action) async {
    try {
      await controller.sendOperatingButtonCommand(action.command, successMessage: action.successMessage);
      if (!context.mounted) {
        return;
      }
      _showResultSnackBar(context, success: true, message: action.successMessage);
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      _showResultSnackBar(context, success: false, message: controller.errorMessage ?? 'Unable to send ${action.label}.');
    }
  }
}

class GuoranOtherSettingsRoutePage extends StatefulWidget {
  const GuoranOtherSettingsRoutePage({super.key, required this.controller});

  final GuoranBleController controller;

  @override
  State<GuoranOtherSettingsRoutePage> createState() => _GuoranOtherSettingsRoutePageState();
}

class _GuoranOtherSettingsRoutePageState extends State<GuoranOtherSettingsRoutePage> {
  late bool _luxAutoEnabled;
  late bool _onTimeAlarmEnabled;
  late bool _timeFormat12Enabled;
  late bool _usingEnglishEnabled;
  late bool _ambientLightInductionEnabled;
  late bool _inductiveSwitchEnabled;

  @override
  void initState() {
    super.initState();
    _luxAutoEnabled = widget.controller.luxAutoEnabled;
    _onTimeAlarmEnabled = widget.controller.onTimeAlarmEnabled;
    _timeFormat12Enabled = widget.controller.timeFormat12Enabled;
    _usingEnglishEnabled = widget.controller.usingEnglishEnabled;
    _ambientLightInductionEnabled = widget.controller.ambientLightInductionEnabled;
    _inductiveSwitchEnabled = widget.controller.inductiveSwitchEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final bool pageEnabled = widget.controller.canSendCommandsWithoutSnapshot && widget.controller.connectedDevice != null;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Other Settings'),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          body: GuoranGradientPage(
            children: <Widget>[
              if (!pageEnabled) ...<Widget>[
                GuoranMessageCard(
                  icon: Icons.hourglass_bottom,
                  title: 'Handshake Required',
                  message: 'Wait for the device handshake to finish before changing these source-app options.',
                  backgroundColor: const Color(0xFFF7F1DF),
                  borderColor: const Color(0xFFE7D59D),
                  foregroundColor: const Color(0xFF6A5720),
                ),
                const SizedBox(height: 16),
              ],
              if (pageEnabled && !widget.controller.hasSnapshot) ...<Widget>[
                const GuoranMessageCard(
                  icon: Icons.settings_suggest_outlined,
                  title: 'Snapshot Still Loading',
                  message:
                      'These SA-SF toggles can be sent before the OSC snapshot finishes. The current values may refresh when the snapshot arrives.',
                  backgroundColor: Color(0xFFE8F3EC),
                  borderColor: Color(0xFFB6D8C2),
                  foregroundColor: Color(0xFF1F5A34),
                ),
                const SizedBox(height: 16),
              ],
              if (widget.controller.errorMessage != null) ...<Widget>[
                GuoranMessageCard(
                  icon: Icons.error_outline,
                  title: 'Save Error',
                  message: widget.controller.errorMessage!,
                  backgroundColor: const Color(0xFFFFECE8),
                  borderColor: const Color(0xFFF1B8AA),
                  foregroundColor: const Color(0xFF7E2A19),
                ),
                const SizedBox(height: 16),
              ],
              GuoranSectionCard(
                title: 'Source-App Toggles',
                subtitle: 'These correspond to SA, SB, SC, SD, SE, and SF in the original app. Stage any changes, then save them together.',
                enabled: pageEnabled,
                child: Column(
                  children: <Widget>[
                    _buildToggle(
                      title: 'LUX Auto',
                      subtitle: 'SA · Enable automatic brightness behavior.',
                      value: _luxAutoEnabled,
                      enabled: pageEnabled,
                      onChanged: (bool value) {
                        setState(() {
                          _luxAutoEnabled = value;
                        });
                      },
                    ),
                    const Divider(height: 1),
                    _buildToggle(
                      title: 'On-Time Alarm',
                      subtitle: 'SD · Enable the source app\'s on-time alarm option.',
                      value: _onTimeAlarmEnabled,
                      enabled: pageEnabled,
                      onChanged: (bool value) {
                        setState(() {
                          _onTimeAlarmEnabled = value;
                        });
                      },
                    ),
                    const Divider(height: 1),
                    _buildToggle(
                      title: '12-Hour Format',
                      subtitle: 'SB · Switch the time display format.',
                      value: _timeFormat12Enabled,
                      enabled: pageEnabled,
                      onChanged: (bool value) {
                        setState(() {
                          _timeFormat12Enabled = value;
                        });
                      },
                    ),
                    const Divider(height: 1),
                    _buildToggle(
                      title: 'Use English',
                      subtitle: 'SE · Toggle the device\'s English mode.',
                      value: _usingEnglishEnabled,
                      enabled: pageEnabled,
                      onChanged: (bool value) {
                        setState(() {
                          _usingEnglishEnabled = value;
                        });
                      },
                    ),
                    const Divider(height: 1),
                    _buildToggle(
                      title: 'Ambient Light Induction',
                      subtitle: 'SC · Toggle ambient light sensing behavior.',
                      value: _ambientLightInductionEnabled,
                      enabled: pageEnabled,
                      onChanged: (bool value) {
                        setState(() {
                          _ambientLightInductionEnabled = value;
                        });
                      },
                    ),
                    const Divider(height: 1),
                    _buildToggle(
                      title: 'Inductive Switch',
                      subtitle: 'SF · Toggle the inductive switch option.',
                      value: _inductiveSwitchEnabled,
                      enabled: pageEnabled,
                      onChanged: (bool value) {
                        setState(() {
                          _inductiveSwitchEnabled = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.controller.isBusy || !pageEnabled ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(widget.controller.isBusy ? 'Saving...' : 'Save to device'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToggle({
    required String title,
    required String subtitle,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: widget.controller.isBusy || !enabled ? null : onChanged,
    );
  }

  Future<void> _save() async {
    try {
      await widget.controller.saveOtherSettings(
        luxAutoEnabled: _luxAutoEnabled,
        onTimeAlarmEnabled: _onTimeAlarmEnabled,
        timeFormat12Enabled: _timeFormat12Enabled,
        usingEnglishEnabled: _usingEnglishEnabled,
        ambientLightInductionEnabled: _ambientLightInductionEnabled,
        inductiveSwitchEnabled: _inductiveSwitchEnabled,
      );
      if (!mounted) {
        return;
      }
      _showResultSnackBar(context, success: true, message: 'Other settings saved to the device.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showResultSnackBar(context, success: false, message: widget.controller.errorMessage ?? 'Unable to save the other settings.');
    }
  }
}

class GuoranDebugRoutePage extends StatelessWidget {
  const GuoranDebugRoutePage({super.key, required this.controller});

  final GuoranBleController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Debug'),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          body: GuoranGradientPage(
            children: <Widget>[
              if (controller.errorMessage != null) ...<Widget>[
                GuoranMessageCard(
                  icon: Icons.error_outline,
                  title: 'Device Error',
                  message: controller.errorMessage!,
                  backgroundColor: const Color(0xFFFFECE8),
                  borderColor: const Color(0xFFF1B8AA),
                  foregroundColor: const Color(0xFF7E2A19),
                ),
                const SizedBox(height: 16),
              ],
              GuoranSectionCard(
                title: 'Debug Card',
                subtitle: 'This combines the debug report with the discovered services so everything diagnostic lives in one place.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        FilledButton.tonalIcon(
                          onPressed: () => _copyDebugReport(context),
                          icon: const Icon(Icons.copy_all_outlined),
                          label: const Text('Copy report'),
                        ),
                        OutlinedButton.icon(
                          onPressed: controller.clearDebugLog,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Clear log'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        _DebugCountPill(label: '${controller.serviceDiagnostics.length} service block(s)'),
                        _DebugCountPill(label: '${controller.debugLogLines.length} log line(s)'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 480),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F2EA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE3D5C6)),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          controller.debugReport.isEmpty ? 'No debug data yet.' : controller.debugReport,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace', height: 1.45),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _copyDebugReport(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: controller.debugReport));
    if (!context.mounted) {
      return;
    }

    _showResultSnackBar(context, success: true, message: 'Debug report copied to the clipboard.');
  }
}

class GuoranGradientPage extends StatelessWidget {
  const GuoranGradientPage({super.key, required this.children, this.topSafeArea = false});

  final List<Widget> children;
  final bool topSafeArea;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFFFFF4EA), Color(0xFFF3E6D9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        top: topSafeArea,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: children),
      ),
    );
  }
}

class GuoranSectionCard extends StatelessWidget {
  const GuoranSectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final Widget content = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: enabled ? 0.92 : 0.72),
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
                    Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35)),
                  ],
                ),
              ),
              if (trailing != null) ...<Widget>[const SizedBox(width: 12), Flexible(child: trailing!)],
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );

    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(opacity: enabled ? 1 : 0.58, child: content),
    );
  }
}

class GuoranNavigationCard extends StatelessWidget {
  const GuoranNavigationCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Ink(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE7D8C8)),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: enabled ? colors.primaryContainer : const Color(0xFFE6DED4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: enabled ? colors.onPrimaryContainer : const Color(0xFF8D857E)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(enabled ? Icons.chevron_right : Icons.lock_outline),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GuoranTimeValueTile extends StatelessWidget {
  const GuoranTimeValueTile({super.key, required this.label, required this.value, required this.enabled, required this.onTap});

  final String label;
  final String value;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
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
}

class GuoranMessageCard extends StatelessWidget {
  const GuoranMessageCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.backgroundColor,
    required this.borderColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color backgroundColor;
  final Color borderColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: foregroundColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: foregroundColor, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: foregroundColor, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuoranActionDescriptor {
  const _GuoranActionDescriptor({required this.command, required this.label, required this.icon, required this.successMessage});

  final String command;
  final String label;
  final IconData icon;
  final String successMessage;
}

const List<String> _lightSwitchLabels = <String>[
  'Light Switch 1',
  'Light Switch 2',
  'Light Switch 3',
  'Light Switch 4',
  'Light Switch 5',
  'Light Switch 6',
];

const List<_GuoranActionDescriptor> _colorConsoleActions = <_GuoranActionDescriptor>[
  _GuoranActionDescriptor(
    command: GuoranProtocol.colorActionPrevious,
    label: 'K01 <',
    icon: Icons.skip_previous_rounded,
    successMessage: 'K01 sent to the device.',
  ),
  _GuoranActionDescriptor(
    command: GuoranProtocol.colorActionMode,
    label: 'K02 M',
    icon: Icons.brightness_medium_outlined,
    successMessage: 'K02 sent to the device.',
  ),
  _GuoranActionDescriptor(
    command: GuoranProtocol.colorActionNext,
    label: 'K03 >',
    icon: Icons.skip_next_rounded,
    successMessage: 'K03 sent to the device.',
  ),
];

const List<_GuoranActionDescriptor> _operatingButtonActions = <_GuoranActionDescriptor>[
  _GuoranActionDescriptor(
    command: GuoranProtocol.operatingActionPower,
    label: 'Power',
    icon: Icons.power_settings_new,
    successMessage: 'K04 sent to the device.',
  ),
  _GuoranActionDescriptor(
    command: GuoranProtocol.operatingActionBack,
    label: 'Back',
    icon: Icons.arrow_back_rounded,
    successMessage: 'K05 sent to the device.',
  ),
  _GuoranActionDescriptor(
    command: GuoranProtocol.operatingActionPlus,
    label: 'Plus',
    icon: Icons.add,
    successMessage: 'K06 sent to the device.',
  ),
  _GuoranActionDescriptor(
    command: GuoranProtocol.operatingActionSet,
    label: 'Set',
    icon: Icons.tune,
    successMessage: 'K07 sent to the device.',
  ),
  _GuoranActionDescriptor(
    command: GuoranProtocol.operatingActionOk,
    label: 'OK',
    icon: Icons.check_circle_outline,
    successMessage: 'K08 sent to the device.',
  ),
  _GuoranActionDescriptor(
    command: GuoranProtocol.operatingActionMinus,
    label: 'Minus',
    icon: Icons.remove,
    successMessage: 'K09 sent to the device.',
  ),
];

class _DebugCountPill extends StatelessWidget {
  const _DebugCountPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F2EA),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE3D5C6)),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

void _showResultSnackBar(BuildContext context, {required bool success, required String message}) {
  final Color backgroundColor = success ? const Color(0xFF284E36) : const Color(0xFF8F2E1F);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), backgroundColor: backgroundColor));
}

String _scanResultLabel(ScanResult result) {
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

String _deviceLabel(BluetoothDevice device) {
  final String name = device.platformName.trim();
  return name.isNotEmpty ? name : device.remoteId.str;
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

String _alarmSummary({required bool enabled, required String value}) {
  return '${enabled ? 'Enabled' : 'Disabled'} · $value';
}

String _colorConsoleSummary(GuoranBleController controller) {
  final int enabledLights = controller.lightSwitches.where((bool value) => value).length;
  return '${_colorHexLabel(controller.colorSliderValue)} · $enabledLights of ${GuoranProtocol.lightSwitchCount} light channels enabled.';
}

String _otherSettingsSummary(GuoranBleController controller) {
  final int enabledCount = <bool>[
    controller.luxAutoEnabled,
    controller.onTimeAlarmEnabled,
    controller.timeFormat12Enabled,
    controller.usingEnglishEnabled,
    controller.ambientLightInductionEnabled,
    controller.inductiveSwitchEnabled,
  ].where((bool value) => value).length;
  return '$enabledCount of 6 source-app toggles enabled.';
}

String _colorHexLabel(int sliderValue) {
  final Color color = GuoranProtocol.colorFromSliderValue(sliderValue);
  final int argb = color.toARGB32();
  final String red = ((argb >> 16) & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase();
  final String green = ((argb >> 8) & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase();
  final String blue = (argb & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase();
  return '#$red$green$blue';
}

String _alarmTitle(GuoranTimeField field) {
  switch (field) {
    case GuoranTimeField.alarm1:
      return 'Alarm 1';
    case GuoranTimeField.alarm2:
      return 'Alarm 2';
    case GuoranTimeField.boot:
      return 'Boot time';
    case GuoranTimeField.off:
      return 'Off time';
  }
}

String _alarmRouteSubtitle(GuoranTimeField field) {
  switch (field) {
    case GuoranTimeField.alarm1:
      return 'Enable Alarm 1 and choose the saved time before sending it to the device.';
    case GuoranTimeField.alarm2:
      return 'Enable Alarm 2 and choose the saved time before sending it to the device.';
    case GuoranTimeField.boot:
      return 'Boot time is edited from the scheduled power page.';
    case GuoranTimeField.off:
      return 'Off time is edited from the scheduled power page.';
  }
}

bool _alarmEnabled(GuoranBleController controller, GuoranTimeField field) {
  switch (field) {
    case GuoranTimeField.alarm1:
      return controller.alarm1Enabled;
    case GuoranTimeField.alarm2:
      return controller.alarm2Enabled;
    case GuoranTimeField.boot:
    case GuoranTimeField.off:
      throw ArgumentError.value(field, 'field', 'Alarm routes only support alarm1 or alarm2.');
  }
}

String _alarmValue(GuoranBleController controller, GuoranTimeField field) {
  switch (field) {
    case GuoranTimeField.alarm1:
      return controller.alarm1;
    case GuoranTimeField.alarm2:
      return controller.alarm2;
    case GuoranTimeField.boot:
    case GuoranTimeField.off:
      throw ArgumentError.value(field, 'field', 'Alarm routes only support alarm1 or alarm2.');
  }
}
