import 'package:mamba/mamba.dart';
import 'package:test/test.dart';

import 'fixtures.dart' show expectAnalysis;

enum _Format { text, json }

final class _ReaderCommand(final List<ValueOf> readers)
    extends Command
    with HookRunner {
  static final label = StringOption.required('label');

  @override
  String get name => 'read';

  @override
  String get shortDescription => 'Read typed values.';

  @override
  void preRun(
    ValueOf valueOf,
    MambaReadContext context,
    ProcessedStandardInput? input,
  ) {
    readers.add(valueOf);
  }

  @override
  String run(ValueOf valueOf, List<String> args) {
    readers.add(valueOf);
    final String labelValue = valueOf(label);
    return labelValue;
  }

  @override
  void postRun(ValueOf valueOf, MambaReadContext context) {
    readers.add(valueOf);
  }
}

final class _ReaderGroup(final List<ValueOf> readers)
    extends GroupCommand
    with PersistentHookRunner {
  this : super([_ReaderCommand(readers)]);

  @override
  String get name => 'group';

  @override
  String get shortDescription => 'Share the invocation reader with hooks.';

  @override
  void prePersistentRun(ValueOf valueOf, MambaContext context) {
    readers.add(valueOf);
  }

  @override
  void postPersistentRun(ValueOf valueOf, MambaContext context) {
    readers.add(valueOf);
  }
}

void main() {
  group('ValueOf', () {
    test('reads nullable, required, defaulted, and collection types', () {
      final optional = StringOption('optional');
      final required = IntOption.required('count');
      final format = ChoiceOption.withDefault(
        'format',
        choices: _Format.values,
        defaultValue: _Format.text,
      );
      final tags = RepeatableStringOption('tag');
      final registry = CommandRegistry.create(
        'tool',
        'Tool.',
        options: [optional, required, format, tags],
      );
      final ValueOf valueOf = Parser(registry)
          .parse(['--count', '2', '--tag', 'a', '--tag', 'b'])
          .$2;

      final String? optionalValue = valueOf(optional);
      final int countValue = valueOf(required);
      final _Format formatValue = valueOf(format);
      final List<String>? tagValues = valueOf(tags);
      expect(optionalValue, isNull);
      expect(countValue, 2);
      expect(formatValue, _Format.text);
      expect(tagValues, ['a', 'b']);
      expect(() => tagValues!.add('c'), throwsUnsupportedError);
    });

    test('rejects an unregistered handle even when its name matches', () {
      final registered = StringOption('label');
      final valueOf = Parser(
        CommandRegistry.create('tool', 'Tool.', options: [registered]),
      ).parse(['--label', 'value']).$2;

      expect(valueOf(registered), 'value');
      expect(() => valueOf(StringOption('label')), throwsStateError);
    });

    test('rejects a missing non-null read on a help-only parse', () {
      final required = StringOption.required('label');
      final valueOf = Parser(
        CommandRegistry.create('tool', 'Tool.', options: [required]),
      ).parse(['--help']).$2;

      expect(valueOf(MambaBuiltInFlags.help), isTrue);
      expect(() => valueOf(required), throwsStateError);
    });

    test('retained readers remain bound to their original parse', () {
      final label = StringOption('label');
      final parser = Parser(
        CommandRegistry.create('tool', 'Tool.', options: [label]),
      );
      final first = parser.parse(['--label', 'first']).$2;
      final second = parser.parse(['--label', 'second']).$2;

      expect(first(label), 'first');
      expect(second(label), 'second');
      expect(first(label), 'first');
    });

    test('commands and all hooks share one invocation-bound reader', () async {
      final readers = <ValueOf>[];
      final executor = Executor(
        'tool',
        'Tool.',
        '1.0.0',
        [_ReaderGroup(readers)],
        options: [_ReaderCommand.label],
      ).fake();

      final result = await executor.execute([
        'group',
        'read',
        '--label',
        'first',
      ]);
      expect((result as MambaSuccessResult).output, 'first');
      expect(readers, hasLength(5));
      for (final valueOf in readers) {
        expect(valueOf, same(readers.first));
        expect(valueOf(_ReaderCommand.label), 'first');
      }

      final first = readers.first;
      readers.clear();
      await executor.execute(['group', 'read', '--label', 'second']);
      expect(first(_ReaderCommand.label), 'first');
      expect(readers.first(_ReaderCommand.label), 'second');
    });

    test('the public reader has no contains API', () async {
      await expectAnalysis(
        "import 'package:mamba/mamba.dart';\n"
        'bool invalid(ValueOf valueOf, ParsedValue<String> handle) =>\n'
        '    valueOf.contains(handle);\n',
        expectedDiagnostics: ['undefined_method'],
        fileName: 'invalid_value_of_contains_temp.dart',
      );
    });
  });
}
