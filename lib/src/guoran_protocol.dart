import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum GuoranTimeField {
	alarm1,
	alarm2,
	boot,
	off,
}

enum SafetyKeyResult {
	accepted,
	incorrect,
	changed,
	cancelled,
	unknown,
}

class GuoranSnapshot {
	const GuoranSnapshot({
		required this.acquisitionSystemTimeEnabled,
		required this.alarm1Enabled,
		required this.alarm2Enabled,
		required this.timingEnabled,
		required this.alarm1,
		required this.alarm2,
		required this.bootTime,
		required this.offTime,
		required this.rawPayload,
	});

	final bool acquisitionSystemTimeEnabled;
	final bool alarm1Enabled;
	final bool alarm2Enabled;
	final bool timingEnabled;
	final String alarm1;
	final String alarm2;
	final String bootTime;
	final String offTime;
	final String rawPayload;
}

class GuoranProtocol {
	const GuoranProtocol._();

	static const List<String> scanServices = <String>['ffb0', 'fff0'];

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

	static TimeOfDay parseTimeOfDay(String value) {
		final List<String> parts = value.split(':');
		if (parts.length != 2) {
			return const TimeOfDay(hour: 0, minute: 0);
		}
		return TimeOfDay(
			hour: int.tryParse(parts[0]) ?? 0,
			minute: int.tryParse(parts[1]) ?? 0,
		);
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
			acquisitionSystemTimeEnabled: _isSwitchEnabled(segments[7]),
			alarm1Enabled: _isSwitchEnabled(segments[8]),
			alarm2Enabled: _isSwitchEnabled(segments[9]),
			timingEnabled: _isSwitchEnabled(segments[10]),
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

	static String _two(int value) => value.toString().padLeft(2, '0');
}

