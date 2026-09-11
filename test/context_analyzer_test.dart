import 'dart:io';

import 'package:test/test.dart';

Future<ProcessResult> _analyze(File source) =>
    Process.run(Platform.resolvedExecutable, ['analyze', source.path]);

void main() {
  test('analyzer accepts all supported context value bindings', () async {
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
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    } finally {
      if (source.existsSync()) source.deleteSync();
    }
  });

  test('analyzer rejects unsupported context values and variants', () async {
    final source = File('test/context_values_invalid_temp.dart')
      ..writeAsStringSync(r'''
import 'package:mamba/mamba.dart';

enum Mode { local }

final class ApplicationValue extends MambaContextValue<String> {
  const ApplicationValue(super.value);
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
}
