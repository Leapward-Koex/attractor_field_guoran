import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum GuoranTimeField { alarm1, alarm2, boot, off }

enum SafetyKeyResult { accepted, incorrect, changed, cancelled, unknown }

class GuoranSnapshot {
  const GuoranSnapshot({
    required this.colorSliderValue,
    required this.lightSwitches,
    required this.acquisitionSystemTimeEnabled,
    required this.alarm1Enabled,
    required this.alarm2Enabled,
    required this.timingEnabled,
    required this.luxAutoEnabled,
    required this.onTimeAlarmEnabled,
    required this.timeFormat12Enabled,
    required this.usingEnglishEnabled,
    required this.ambientLightInductionEnabled,
    required this.inductiveSwitchEnabled,
    required this.alarm1,
    required this.alarm2,
    required this.bootTime,
    required this.offTime,
    required this.rawPayload,
  });

  final int colorSliderValue;
  final List<bool> lightSwitches;
  final bool acquisitionSystemTimeEnabled;
  final bool alarm1Enabled;
  final bool alarm2Enabled;
  final bool timingEnabled;
  final bool luxAutoEnabled;
  final bool onTimeAlarmEnabled;
  final bool timeFormat12Enabled;
  final bool usingEnglishEnabled;
  final bool ambientLightInductionEnabled;
  final bool inductiveSwitchEnabled;
  final String alarm1;
  final String alarm2;
  final String bootTime;
  final String offTime;
  final String rawPayload;
}

class GuoranProtocol {
  const GuoranProtocol._();

  static const List<String> scanServices = <String>['ffb0', 'fff0'];
  static const int lightSwitchCount = 6;
  static const int maxColorSliderValue = 1530;
  static const int defaultColorSliderValue = 765;

  static final List<Guid> scanServiceGuids = scanServices
      .map<Guid>((String uuid) => Guid('0000$uuid-0000-1000-8000-00805f9b34fb'))
      .toList(growable: false);

  static const String readServiceShort = 'ffe0';
  static const String writeServiceShort = 'ffe5';
  static const String gpioServiceShort = 'fff0';
  static const String safetyKeyServiceShort = 'ffc0';

  static const String readCharacteristicShort = 'ffe4';
  static const String writeCharacteristicShort = 'ffe9';
  static const String safetyKeyCharacteristicShort = 'ffc1';
  static const String safetyKeyNotifyCharacteristicShort = 'ffc2';

  static const String enableSystemTimeSync = 'S71';
  static const String disableSystemTimeSync = 'S70';
  static const String enableAlarm1 = 'S81';
  static const String disableAlarm1 = 'S80';
  static const String enableAlarm2 = 'S91';
  static const String disableAlarm2 = 'S90';
  static const String enableTiming = 'S01';
  static const String disableTiming = 'S00';
  static const List<String> enableLightSwitchCommands = <String>['S11', 'S21', 'S31', 'S41', 'S51', 'S61'];
  static const List<String> disableLightSwitchCommands = <String>['S10', 'S20', 'S30', 'S40', 'S50', 'S60'];
  static const String enableLuxAuto = 'SA1';
  static const String disableLuxAuto = 'SA0';
  static const String enableTimeFormat12 = 'SB1';
  static const String disableTimeFormat12 = 'SB0';
  static const String enableAmbientLightInduction = 'SC1';
  static const String disableAmbientLightInduction = 'SC0';
  static const String enableOnTimeAlarm = 'SD1';
  static const String disableOnTimeAlarm = 'SD0';
  static const String enableUsingEnglish = 'SE1';
  static const String disableUsingEnglish = 'SE0';
  static const String enableInductiveSwitch = 'SF1';
  static const String disableInductiveSwitch = 'SF0';
  static const String colorActionPrevious = 'K01';
  static const String colorActionMode = 'K02';
  static const String colorActionNext = 'K03';
  static const String operatingActionPower = 'K04';
  static const String operatingActionBack = 'K05';
  static const String operatingActionPlus = 'K06';
  static const String operatingActionSet = 'K07';
  static const String operatingActionOk = 'K08';
  static const String operatingActionMinus = 'K09';

  static const String configuredSafetyKey = '210709';
  static const String initialSafetyKeyPayload = '000000210709';
  static const String storedSafetyKeyPayload = '210709210709';
  static const String snapshotCommand = 'OSC';

  static List<int> encodeAscii(String value) => ascii.encode(value);

  static String decodeAscii(List<int> bytes) {
    return ascii.decode(bytes, allowInvalid: true).replaceAll('\u0000', '');
  }

  static bool matchesShortUuid(String fullUuid, String expectedShortUuid) {
    return extractShortUuid(fullUuid) == expectedShortUuid.toLowerCase();
  }

  static String? extractShortUuid(String fullUuid) {
    final String normalized = fullUuid.toLowerCase().trim();
    if (normalized.isEmpty) {
      return null;
    }

    final String firstSegment = normalized.split('-').first;
    if (firstSegment.length == 4) {
      return firstSegment;
    }
    if (firstSegment.length == 8 && firstSegment.startsWith('0000')) {
      return firstSegment.substring(4, 8);
    }

    return null;
  }

  static SafetyKeyResult parseSafetyKeyResponse(List<int> bytes) {
    if (bytes.isEmpty) {
      return SafetyKeyResult.unknown;
    }

    switch (bytes.first) {
      case 0:
        return SafetyKeyResult.accepted;
      case 1:
        return SafetyKeyResult.incorrect;
      case 2:
        return SafetyKeyResult.changed;
      case 3:
        return SafetyKeyResult.cancelled;
      default:
        return SafetyKeyResult.unknown;
    }
  }

  static String buildSystemTimePayload(DateTime now) {
    final int jsWeekday = now.weekday % 7;
    return '\$${now.year}-${_two(now.month)}-${_two(now.day)};${_two(now.hour)}:${_two(now.minute)}:${_two(now.second)};0$jsWeekday';
  }

  static String buildTimeCommand(GuoranTimeField field, TimeOfDay time) {
    final String hh = _two(time.hour);
    final String mm = _two(time.minute);
    switch (field) {
      case GuoranTimeField.alarm1:
        return 'A$hh:${mm}A';
      case GuoranTimeField.alarm2:
        return 'A$hh:${mm}B';
      case GuoranTimeField.boot:
        return 'T$hh:${mm}O';
      case GuoranTimeField.off:
        return 'T$hh:${mm}C';
    }
  }

  static String formatTimeOfDay(TimeOfDay time) {
    return '${_two(time.hour)}:${_two(time.minute)}';
  }

  static String buildColorCommand(int sliderValue) {
    final List<int> rgb = _rgbForSliderValue(sliderValue);
    return 'R${_three(rgb[0])}-G${_three(rgb[1])}-B${_three(rgb[2])}';
  }

  static Color colorFromSliderValue(int sliderValue) {
    final List<int> rgb = _rgbForSliderValue(sliderValue);
    return Color.fromARGB(0xFF, rgb[0], rgb[1], rgb[2]);
  }

  static int colorSliderValueFromRgb(int red, int green, int blue) {
    final int normalizedRed = red.clamp(0, 255);
    final int normalizedGreen = green.clamp(0, 255);
    final int normalizedBlue = blue.clamp(0, 255);

    if (normalizedRed == 255 && normalizedGreen <= 255 && normalizedBlue == 0) {
      return normalizedGreen;
    }
    if (normalizedRed <= 255 && normalizedGreen == 255 && normalizedBlue == 0) {
      return 510 - normalizedRed;
    }
    if (normalizedRed == 0 && normalizedGreen == 255 && normalizedBlue <= 255) {
      return 510 + normalizedBlue;
    }
    if (normalizedRed == 0 && normalizedGreen <= 255 && normalizedBlue == 255) {
      return 1020 - normalizedGreen;
    }
    if (normalizedRed <= 255 && normalizedGreen == 0 && normalizedBlue == 255) {
      return 1020 + normalizedRed;
    }
    if (normalizedRed == 255 && normalizedGreen == 0 && normalizedBlue <= 255) {
      return 1530 - normalizedBlue;
    }

    return defaultColorSliderValue;
  }

  static String lightSwitchCommand(int index, bool enabled) {
    if (index < 0 || index >= lightSwitchCount) {
      throw RangeError.index(index, enableLightSwitchCommands, 'index');
    }

    return enabled ? enableLightSwitchCommands[index] : disableLightSwitchCommands[index];
  }

  static TimeOfDay parseTimeOfDay(String value) {
    final List<String> parts = value.split(':');
    if (parts.length != 2) {
      return const TimeOfDay(hour: 0, minute: 0);
    }
    return TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
  }

  static GuoranSnapshot? tryParseSnapshot(String data) {
    if (data.length != 93 || !data.startsWith('R') || !data.endsWith('CSS')) {
      return null;
    }

    final List<String> segments = <String>[];
    for (int index = 0; index < 21; index++) {
      if (index == 0) {
        segments.add(data.substring(0, 14));
      } else if (index > 0 && index < 17) {
        segments.add(data.substring(3 * index + 11, 3 * index + 14));
      } else {
        final int start = 7 * index - 57;
        segments.add(data.substring(start, start + 7));
      }
    }

    return GuoranSnapshot(
      colorSliderValue: _parseColorSliderValue(segments[0]),
      lightSwitches: List<bool>.generate(lightSwitchCount, (int index) => _isSwitchEnabled(segments[index + 1]), growable: false),
      acquisitionSystemTimeEnabled: _isSwitchEnabled(segments[7]),
      alarm1Enabled: _isSwitchEnabled(segments[8]),
      alarm2Enabled: _isSwitchEnabled(segments[9]),
      timingEnabled: _isSwitchEnabled(segments[10]),
      luxAutoEnabled: _isSwitchEnabled(segments[11]),
      onTimeAlarmEnabled: _isSwitchEnabled(segments[14]),
      timeFormat12Enabled: _isSwitchEnabled(segments[12]),
      usingEnglishEnabled: _isSwitchEnabled(segments[15]),
      ambientLightInductionEnabled: _isSwitchEnabled(segments[13]),
      inductiveSwitchEnabled: _isSwitchEnabled(segments[16]),
      alarm1: segments[17].substring(1, 6),
      alarm2: segments[18].substring(1, 6),
      bootTime: segments[19].substring(1, 6),
      offTime: segments[20].substring(1, 6),
      rawPayload: data,
    );
  }

  static bool _isSwitchEnabled(String value) {
    return value.length >= 3 && value[2] != '0';
  }

  static int _parseColorSliderValue(String value) {
    final RegExpMatch? match = RegExp(r'^R(\d{3})-G(\d{3})-B(\d{3})$').firstMatch(value);
    if (match == null) {
      return defaultColorSliderValue;
    }

    return colorSliderValueFromRgb(
      int.tryParse(match.group(1) ?? '') ?? 0,
      int.tryParse(match.group(2) ?? '') ?? 0,
      int.tryParse(match.group(3) ?? '') ?? 0,
    );
  }

  static List<int> _rgbForSliderValue(int sliderValue) {
    final int value = sliderValue.clamp(0, maxColorSliderValue);
    if (value <= 255) {
      return <int>[255, value, 0];
    }
    if (value <= 510) {
      return <int>[510 - value, 255, 0];
    }
    if (value <= 765) {
      return <int>[0, 255, value - 510];
    }
    if (value <= 1020) {
      return <int>[0, 1020 - value, 255];
    }
    if (value <= 1275) {
      return <int>[value - 1020, 0, 255];
    }
    return <int>[255, 0, 1530 - value];
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
  static String _three(int value) => value.toString().padLeft(3, '0');
}
