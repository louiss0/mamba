import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'analyzer rejects nullable output and positional presence mismatches',
    () async {
      final source = File('test/invalid_input_types_temp.dart');
      source.writeAsStringSync(r'''
import 'package:mamba/mamba.dart';

void invalid(ParsedInputs inputs) {
  final optional = StringOption('name');
  final String value = inputs.valueOf(optional);
  CommandRegistry.create(
    'tool',
    'Tool.',
    mandatoryPositionals: [NormalPositional.optional('path')],
  );
  print(value);
}
''');

      try {
        final result = await Process.run(Platform.resolvedExecutable, [
          'analyze',
          source.path,
        ]);
        final diagnostics = '${result.stdout}\n${result.stderr}';

        expect(result.exitCode, isNot(0));
        expect(diagnostics, contains('argument_type_not_assignable'));
        expect(diagnostics, contains('list_element_type_not_assignable'));
      } finally {
        if (source.existsSync()) source.deleteSync();
      }
    },
  );
}
