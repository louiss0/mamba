import 'dart:convert';

import 'package:mamba/executor.dart';
import 'package:test/test.dart';

import '../fixtures/rig/rig.dart' as rig;

void main() {
  group('rig mock CLI', () {
    test('activates the completion generator command', () async {
      final result = await rig.createRigExecutor().fake().execute([
        'completion',
        '--shell',
        'carapace',
      ]);

      expect(result, isA<MambaSuccessResult>());
      final output = (result as MambaSuccessResult).output!;
      expect(output, contains('name: "rig"'));
      expect(output, contains('description:'));
    });

    test('shows the root help without executing an operation', () async {
      final result = await rig.createRigExecutor().fake().execute([]);

      expect(result, isA<MambaSuccessResult>());
      final output = (result as MambaSuccessResult).output!;
      expect(output, contains('mock workstation-control CLI'));
      expect(output, contains('volume'));
      expect(output, contains('network'));
      expect(output, contains('profile'));
    });

    test(
      'supports canonical commands, aliases, and structured output',
      () async {
        final result = await rig.createRigExecutor().fake().execute([
          'vol',
          'output',
          '--level',
          '70',
          '--format',
          'json',
        ]);

        expect(result, isA<MambaSuccessResult>());
        final output = jsonDecode((result as MambaSuccessResult).output!);
        expect(output['mock'], isTrue);
        expect(output['changes_made'], isFalse);
        expect(output['parameters']['level'], 70);
      },
    );

    test(
      'supports global dry-run shorthand and process name shorthand',
      () async {
        final dryRun = await rig.createRigExecutor().fake().execute([
          '-n',
          'volume',
          'output',
        ]);
        final process = await rig.createRigExecutor().fake().execute([
          'process',
          'inspect',
          '-n',
          'worker-1',
        ]);

        expect((dryRun as MambaSuccessResult).output, contains('Dry run'));
        expect((process as MambaSuccessResult).output, contains('worker-1'));
      },
    );

    test('preserves repeatable channel and gain order', () async {
      final result = await rig.createRigExecutor().fake().execute([
        'volume',
        'output',
        '--channel',
        'left',
        '--channel',
        'right',
        '--channel-gain',
        '0.85',
        '--channel-gain',
        '1.0',
      ]);

      expect(result, isA<MambaSuccessResult>());
      final output = (result as MambaSuccessResult).output!;
      expect(output, contains('left=0.85'));
      expect(output, contains('right=1.0'));
    });

    test('never prints a Wi-Fi password', () async {
      final result = await rig.createRigExecutor().fake().execute([
        'network',
        'wifi',
        'connect',
        '--ssid',
        'ExampleNet',
        '--password',
        'secret-value',
        '-vvv',
      ]);

      expect(result, isA<MambaSuccessResult>());
      final output = (result as MambaSuccessResult).output!;
      expect(output, contains('ExampleNet'));
      expect(output, isNot(contains('secret-value')));
      expect(output, isNot(contains('password=')));
    });

    test('rejects values outside a documented range', () async {
      final result = await rig.createRigExecutor().fake().execute([
        'brightness',
        '--level',
        '101',
      ]);

      expect(result, isA<MambaFailureResult>());
      expect(
        (result as MambaFailureResult).exception.toString(),
        contains('at most 100'),
      );
    });

    test('group commands display their own help', () async {
      final result = await rig.createRigExecutor().fake().execute(['net']);

      expect(result, isA<MambaSuccessResult>());
      final output = (result as MambaSuccessResult).output!;
      expect(output, contains('rig network'));
      expect(output, contains('wifi'));
      expect(output, contains('ping'));
    });

    test('accepts multiple cleanup targets and dry-run output', () async {
      final result = await rig.createRigExecutor().fake().execute([
        'clean',
        'cache',
        'logs',
        'temp',
        '--older-than',
        '30',
        '--dry-run',
      ]);

      expect(result, isA<MambaSuccessResult>());
      final output = (result as MambaSuccessResult).output!;
      expect(output, contains('cache, logs, and temp'));
      expect(output, contains('30 days'));
      expect(output, contains('Dry run'));
      expect(output, contains('No files were changed'));
    });
  });
}
