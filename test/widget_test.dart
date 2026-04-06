import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attractor_field_guoran/src/guoran_protocol.dart';

void main() {
  test('matchesShortUuid accepts short and canonical BLE UUID forms', () {
    expect(GuoranProtocol.matchesShortUuid('ffe0', 'ffe0'), isTrue);
    expect(GuoranProtocol.matchesShortUuid('ffc2', 'ffc2'), isTrue);
    expect(
      GuoranProtocol.matchesShortUuid(
        '0000ffe5-0000-1000-8000-00805f9b34fb',
        'ffe5',
      ),
      isTrue,
    );
    expect(
      GuoranProtocol.matchesShortUuid(
        '0000fff0-0000-1000-8000-00805f9b34fb',
        'fff0',
      ),
      isTrue,
    );
    expect(GuoranProtocol.matchesShortUuid('ff90', 'ffe0'), isFalse);
  });

  test('buildTimeCommand matches original clock protocol', () {
    expect(
      GuoranProtocol.buildTimeCommand(
        GuoranTimeField.alarm1,
        const TimeOfDay(hour: 7, minute: 5),
      ),
      'A07:05A',
    );
    expect(
      GuoranProtocol.buildTimeCommand(
        GuoranTimeField.alarm2,
        const TimeOfDay(hour: 22, minute: 45),
      ),
      'A22:45B',
    );
    expect(
      GuoranProtocol.buildTimeCommand(
        GuoranTimeField.boot,
        const TimeOfDay(hour: 6, minute: 30),
      ),
      'T06:30O',
    );
    expect(
      GuoranProtocol.buildTimeCommand(
        GuoranTimeField.off,
        const TimeOfDay(hour: 23, minute: 0),
      ),
      'T23:00C',
    );
  });

  test('buildSystemTimePayload matches original js format', () {
    final DateTime timestamp = DateTime(2025, 1, 6, 9, 4, 8);
    expect(
      GuoranProtocol.buildSystemTimePayload(timestamp),
        r'$2025-01-06;09:04:08;01',
    );
  });
}
