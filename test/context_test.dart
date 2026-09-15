import 'dart:io';

import 'package:mamba/mamba.dart';
import 'package:test/test.dart';

Future<ProcessResult> _analyze(File source) =>
    Process.run(Platform.resolvedExecutable, ['analyze', source.path]);

void main() {
  group('Runtime values', () {
    test('stores and retrieves supported scalar values', () {
      final stringKey = MambaContextKey<String>();
      final boolKey = MambaContextKey<bool>();
      final intKey = MambaContextKey<int>();
      final doubleKey = MambaContextKey<double>();
      final context = MambaContext();

      context.set(stringKey, const MambaContextString(''));
      context.set(boolKey, const MambaContextBool(true));
      context.set(intKey, const MambaContextInt(-12));
      context.set(doubleKey, const MambaContextDouble(3.5));

      expect(context.get(stringKey), '');
      context.set(stringKey, const MambaContextString('workspace'));
      expect(context.get(stringKey), 'workspace');
      expect(context.get(boolKey), isTrue);
      expect(context.get(intKey), -12);
      expect(context.get(doubleKey), 3.5);
    });

    test('supports false, zero, and non-finite doubles', () {
      final boolKey = MambaContextKey<bool>();
      final intKey = MambaContextKey<int>();
      final doubleKey = MambaContextKey<double>();
      final context = MambaContext();

      context.set(boolKey, const MambaContextBool(false));
      context.set(intKey, const MambaContextInt(0));
      context.set(doubleKey, const MambaContextDouble(double.nan));
      expect(context.get(boolKey), isFalse);
      expect(context.get(intKey), 0);
      expect(context.get(doubleKey)!.isNaN, isTrue);

      context.set(intKey, const MambaContextInt(42));
      expect(context.get(intKey), 42);
      context.set(doubleKey, const MambaContextDouble(double.infinity));
      expect(context.get(doubleKey), double.infinity);
      context.set(doubleKey, const MambaContextDouble(double.negativeInfinity));
      expect(context.get(doubleKey), double.negativeInfinity);
    });

    test('replaces values and keeps same-typed keys separate by identity', () {
      final firstKey = MambaContextKey<String>();
      final secondKey = MambaContextKey<String>();
      final context = MambaContext();

      context.set(firstKey, const MambaContextString('first'));
      context.set(secondKey, const MambaContextString('second'));
      context.set(firstKey, const MambaContextString('replaced'));

      expect(context.get(firstKey), 'replaced');
      expect(context.get(secondKey), 'second');
      expect(context.get(MambaContextKey<String>()), isNull);
    });

    test('returns null for an unset supported key', () {
      expect(MambaContext().get(MambaContextKey<String>()), isNull);
    });

    test('rejects unsupported dynamic writes without mutating state', () {
      final key = MambaContextKey<String>();
      final context = MambaContext();
      context.set(key, const MambaContextString('before'));
      final dynamic dynamicContext = context;

      expect(
        () => dynamicContext.set(key, Object()),
        throwsA(isA<TypeError>()),
      );
      expect(context.get(key), 'before');
    });

    test('rejects mismatched wrappers supplied with a dynamic raw key', () {
      final key = MambaContextKey<String>();
      final context = MambaContext();
      context.set(key, const MambaContextString('before'));
      final dynamic dynamicContext = context;
      final dynamic rawKey = key;

      expect(
        () => dynamicContext.set(rawKey, const MambaContextBool(true)),
        throwsArgumentError,
      );
      expect(context.get(key), 'before');
    });
  });

  group('Analyzer contracts', () {
    test('accepts all supported context value bindings', () async {
      final source = File('test/context_values_valid_temp.dart')
        ..writeAsStringSync(r'''
import 'package:mamba/mamba.dart';

void main() {
  final context = MambaContext();
  final stringKey = MambaContextKey<String>();
  final boolKey = MambaContextKey<bool>();
  final intKey = MambaContextKey<int>();
  final doubleKey = MambaContextKey<double>();
  context.set(stringKey, const MambaContextString('workspace'));
  context.set(boolKey, const MambaContextBool(true));
  context.set(intKey, const MambaContextInt(1));
  context.set(doubleKey, const MambaContextDouble(1.5));
  final String? stringValue = context.get(stringKey);
  final bool? boolValue = context.get(boolKey);
  final int? intValue = context.get(intKey);
  final double? doubleValue = context.get(doubleKey);
  final readContext = MambaReadContext(context);
  final String? readString = readContext.get(stringKey);
  print('$stringValue $boolValue $intValue $doubleValue $readString');
}
''');

      try {
        final result = await _analyze(source);
        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
      } finally {
        if (source.existsSync()) source.deleteSync();
      }
    });

    test('rejects unsupported context values and variants', () async {
      final source = File('test/context_values_invalid_temp.dart')
        ..writeAsStringSync(r'''
import 'package:mamba/mamba.dart';

enum Mode { local }

final class ApplicationValue extends MambaContextValue<String> {
  const new(super.value);
}

void invalid() {
  final context = MambaContext();
  final stringKey = MambaContextKey<String>();
  final intKey = MambaContextKey<int>();
  final dateKey = MambaContextKey<DateTime>();
  context.set(stringKey, const MambaContextBool(true));
  context.set(intKey, const MambaContextDouble(1.0));
  context.set(stringKey, 'text');
  context.set(stringKey, Mode.local);
  context.set(stringKey, (1, 'record'));
  context.set(stringKey, <int>[1]);
  context.set(stringKey, <String, int>{'one': 1});
  context.set(stringKey, Object());
  context.set(stringKey, null);
  context.set(dateKey, const MambaContextString('date'));
  const MambaContextValue<DateTime>(DateTime(2020));
}
''');

      try {
        final result = await _analyze(source);
        final diagnostics = '${result.stdout}\n${result.stderr}';
        expect(result.exitCode, isNot(0));
        expect(diagnostics, contains('invalid_use_of_type_outside_library'));
        expect(diagnostics, contains('argument_type_not_assignable'));
      } finally {
        if (source.existsSync()) source.deleteSync();
      }
    });
  });
}
