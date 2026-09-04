import 'dart:async';

import 'package:mamba/command.dart';
import 'package:mamba/errors.dart';
import 'package:mamba/registry.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class TestGroupCommand extends GroupCommand {
  @override
  final String name;

  @override
  String get shortDescription => "This is a test command";

  new(this.name, super.commands, {super.defaultSubCommandPath, super.variadic})
    : super(
        longDescription: '',
        mandatoryPositionals: null,
        discretionaryPositionals: null,
        flags: null,
        options: null,
        pairedOptions: null,
        accessors: null,
      );

  FutureOr<String> runWithNothingBasedOnCommandPathWithNothing(
    List<String> commandPath,
  ) {
    return runChildCommand(
      commandPath,
      (singles: null, repeated: null, variadic: null),
      (
        accessors: null,
        boolFlags: null,
        countFlags: null,
        doubleOptions: null,
        intOptions: null,
        repeatedDoubleOptions: null,
        repeatedIntOptions: null,
        repeatedStringOptions: null,
        stringOptions: null,
      ),
      [],
    );
  }
}

class TestCommand extends Mock implements Command {
  @override
  final String name;

  new(this.name);
}

enum OutputFormat { yaml, json }

final class _VariadicCommand extends Command {
  new({super.variadic});

  @override
  String get name => 'tool';

  @override
  String get shortDescription => 'A test command.';

  @override
  FutureOr<String> run(
    ParsedPositionals positionals,
    ParsedNamedInputs input,
    List<String> trailingArguments,
  ) => '';
}

class TestChildGroupCommand extends Mock implements GroupCommand {
  @override
  final String name;

  @override
  final List<Command> commands;

  new(this.name, this.commands);
}

void main() {
  final ParsedNamedInputs emptyInputs = (
    accessors: null,
    boolFlags: null,
    countFlags: null,
    doubleOptions: null,
    intOptions: null,
    repeatedDoubleOptions: null,
    repeatedIntOptions: null,
    repeatedStringOptions: null,
    stringOptions: null,
  );
  registerFallbackValue(emptyInputs);
  registerFallbackValue((singles: null, repeated: null, variadic: null));

  group("GroupCommand", () {
    final stashPush = TestCommand("push");
    final stashPop = TestCommand("pop");
    final stashCommand = TestChildGroupCommand('stash', [stashPush, stashPop]);

    when(() => stashPush.run(any(), any(), any())).thenAnswer((_) => '');

    when(() => stashPop.run(any(), any(), any())).thenAnswer((_) => '');

    when(() => stashCommand.run(any(), any(), any()))
        .thenAnswer((_) => Future.value(''));

    final groupCommand = TestGroupCommand('git', [stashCommand]);

    test("calls the run child command", () {
      groupCommand.runWithNothingBasedOnCommandPathWithNothing(['stash']);

      verifyNever(() => stashPush.run(any(), any(), any()));
      verifyNever(() => stashPop.run(any(), any(), any()));
      verify(() => stashCommand.run(any(), any(), any())).called(1);
    });

    test("calls the child's child command when path points to it", () {
      groupCommand.runWithNothingBasedOnCommandPathWithNothing([
        'stash',
        'pop',
      ]);

      verifyNever(() => stashPush.run(any(), any(), any()));
      verify(() => stashPop.run(any(), any(), any())).called(1);
      verifyNever(() => stashCommand.run(any(), any(), any()));
    });

    test('resolves aliases in direct child command paths', () async {
      when(() => stashCommand.aliases).thenReturn(['st']);

      await groupCommand.runWithNothingBasedOnCommandPathWithNothing(['st']);

      verify(() => stashCommand.run(any(), any(), any())).called(1);
    });

    test('runs a relative default subcommand path', () async {
      final git = TestGroupCommand(
        'git',
        [stashCommand],
        defaultSubCommandPath: ['stash', 'pop'],
      );

      await git.run(
        (singles: null, repeated: null, variadic: null),
        emptyInputs,
        [],
      );

      verify(() => stashPop.run(any(), any(), any())).called(1);
    });

    test('rejects empty and parent-qualified default paths', () {
      expect(
        () =>
            TestGroupCommand('git', [stashCommand], defaultSubCommandPath: []),
        throwsA(isA<MambaRegistryError>()),
      );
      expect(
        () => TestGroupCommand(
          'git',
          [stashCommand],
          defaultSubCommandPath: ['git'],
        ),
        throwsA(isA<MambaRegistryError>()),
      );
    });

    test('requires child paths to be relative to the group', () {
      expect(
        () => groupCommand.runWithNothingBasedOnCommandPathWithNothing(['git']),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects empty runtime paths and unknown child commands', () {
      expect(
        () => groupCommand.runWithNothingBasedOnCommandPathWithNothing([]),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => groupCommand.runWithNothingBasedOnCommandPathWithNothing([
          'missing',
        ]),
        throwsA(isA<MambaException>()),
      );
    });

    test('returns empty output when no default child is configured', () async {
      expect(
        await groupCommand.run(
          (singles: null, repeated: null, variadic: null),
          emptyInputs,
          [],
        ),
        isEmpty,
      );
    });

    test('rejects empty segments in default paths', () {
      expect(
        () => TestGroupCommand(
          'git',
          [stashCommand],
          defaultSubCommandPath: ['stash', ''],
        ),
        throwsA(isA<MambaRegistryError>()),
      );
    });
  });

  group('Input definitions', () {
    test('accessor numeric regexes describe parser numeric syntax', () {
      final integer = AccessorIntOption('port').regex;
      final decimal = AccessorDoubleOption('ratio').regex;

      expect(integer.hasMatch('-80'), isTrue);
      expect(integer.hasMatch('+80'), isTrue);
      expect(decimal.hasMatch('-1.5'), isTrue);
      expect(decimal.hasMatch('+1'), isTrue);
    });

    test('rejects negative repeated positional counts', () {
      expect(
        () => RepeatedStringPositional('files', times: -1),
        throwsA(isA<MambaRegistryError>()),
      );
      expect(
        () => RepeatedChoicePositional<OutputFormat>(
          'formats',
          choices: OutputFormat.values,
          times: -1,
        ),
        throwsA(isA<MambaRegistryError>()),
      );
    });
  });

  group('Variadic', () {
    test('defaults the variadic field to absent', () {
      expect(_VariadicCommand().variadic, isNull);
    });

    test('registers a variadic without any positionals', () {
      final extra = NormalVariadic('extra');

      final command = _VariadicCommand(variadic: extra);

      expect(command.mandatoryPositionals, isNull);
      expect(command.discretionaryPositionals, isNull);
      expect(command.variadic, same(extra));
    });

    test('registers a NormalVariadic under variadic', () {
      final extra = NormalVariadic('extra');

      expect(_VariadicCommand(variadic: extra).variadic, same(extra));
    });

    test('registers a ChoiceVariadic under variadic', () {
      final formats = ChoiceVariadic<OutputFormat>(
        'formats',
        choices: OutputFormat.values,
        defaultValue: OutputFormat.yaml,
      );

      final command = _VariadicCommand(variadic: formats);

      expect(command.variadic, same(formats));
    });

    test('forwards the variadic through group commands', () {
      final formats = ChoiceVariadic<OutputFormat>(
        'formats',
        choices: OutputFormat.values,
      );

      final group = TestGroupCommand('git', [
        TestCommand('stash'),
      ], variadic: formats);

      expect(group.variadic, same(formats));
    });
  });

  group('ProcessedStandardInput', () {
    test('exposes character, UTF-8, and JSON representations', () {
      final text = ProcessedStandardInput('hé'.codeUnits);
      final utf8Input = ProcessedStandardInput([104, 195, 169]);
      final json = ProcessedStandardInput('{"enabled":true}'.codeUnits);

      expect(text.text, 'hé');
      expect(utf8Input.utf8Text, 'hé');
      expect(json.json, {'enabled': true});
    });

    test('reports malformed JSON', () {
      expect(
        () => ProcessedStandardInput('not-json'.codeUnits).json,
        throwsFormatException,
      );
    });
  });

  group('RegistryMap', () {
    Map<String, dynamic> registryMap([Map<String, dynamic>? properties]) => {
      'name': 'tool',
      'description': 'A test command.',
      ...?properties,
    };

    Map<String, dynamic> booleanFlag() => {
      'short': null,
      'default': false,
      'negatable': false,
      'hidden': false,
      'description': null,
    };

    Map<String, dynamic> countFlag() => {
      'short': 'v',
      'hidden': false,
      'description': null,
    };

    Map<String, dynamic> option() => {
      'short': null,
      'required': false,
      'hidden': false,
      'description': null,
      'valueType': 'string',
    };

    Map<String, dynamic> positional() => {
      'required': true,
      'description': null,
    };

    Matcher hasInvalidProperty(String path, Object? value) => throwsA(
      isA<MambaIntegrationException>()
          .having((error) => error.message, 'message', contains(path))
          .having((error) => error.message, 'value', contains('$value')),
    );

    ({Map<String, dynamic> root, Map<String, dynamic> leaf, List<String> names})
    nestedCommandMap(int depth) {
      final root = registryMap();
      var leaf = root;
      final names = <String>[];
      for (var index = 1; index <= depth; index++) {
        final name = 'command$index';
        final child = registryMap();
        leaf['commands'] = {name: child};
        leaf = child;
        names.add(name);
      }
      return (root: root, leaf: leaf, names: names);
    }

    String nestedPath(List<String> names, String suffix) => [
      for (final name in names) ...['commands', name],
      suffix,
    ].join('.');

    final invalidDescendantProperties =
        <
          ({
            String description,
            Object? invalidValue,
            String suffix,
            void Function(Map<String, dynamic> map) write,
          })
        >[
          (
            description: 'a non-string flag short alias',
            invalidValue: 1,
            suffix: 'flags.verbose.short',
            write: (map) =>
                map['flags'] = {'verbose': booleanFlag()..['short'] = 1},
          ),
          (
            description: 'a non-boolean flag default',
            invalidValue: 'false',
            suffix: 'flags.verbose.default',
            write: (map) => map['flags'] = {
              'verbose': booleanFlag()..['default'] = 'false',
            },
          ),
          (
            description: 'a non-boolean flag negatable value',
            invalidValue: 1,
            suffix: 'flags.verbose.negatable',
            write: (map) =>
                map['flags'] = {'verbose': booleanFlag()..['negatable'] = 1},
          ),
          (
            description: 'a non-boolean flag hidden value',
            invalidValue: 'no',
            suffix: 'flags.verbose.hidden',
            write: (map) =>
                map['flags'] = {'verbose': booleanFlag()..['hidden'] = 'no'},
          ),
          (
            description: 'a non-string flag description',
            invalidValue: 1,
            suffix: 'flags.verbose.description',
            write: (map) =>
                map['flags'] = {'verbose': booleanFlag()..['description'] = 1},
          ),
          (
            description: 'a non-boolean persistent flag hidden value',
            invalidValue: 'no',
            suffix: 'persistentFlags.verbose.hidden',
            write: (map) => map['persistentFlags'] = {
              'verbose': countFlag()..['hidden'] = 'no',
            },
          ),
          (
            description: 'a non-string option short alias',
            invalidValue: 1,
            suffix: 'options.output.short',
            write: (map) =>
                map['options'] = {'output': option()..['short'] = 1},
          ),
          (
            description: 'a non-boolean option required value',
            invalidValue: 'yes',
            suffix: 'options.output.required',
            write: (map) =>
                map['options'] = {'output': option()..['required'] = 'yes'},
          ),
          (
            description: 'a non-boolean option hidden value',
            invalidValue: 1,
            suffix: 'options.output.hidden',
            write: (map) =>
                map['options'] = {'output': option()..['hidden'] = 1},
          ),
          (
            description: 'a non-string option description',
            invalidValue: 1,
            suffix: 'options.output.description',
            write: (map) =>
                map['options'] = {'output': option()..['description'] = 1},
          ),
          (
            description: 'a non-boolean option repeatable value',
            invalidValue: 'yes',
            suffix: 'options.output.repeatable',
            write: (map) =>
                map['options'] = {'output': option()..['repeatable'] = 'yes'},
          ),
          (
            description: 'a non-boolean option variant value',
            invalidValue: 'yes',
            suffix: 'options.output.variant',
            write: (map) =>
                map['options'] = {'output': option()..['variant'] = 'yes'},
          ),
          (
            description: 'a non-string choice option member',
            invalidValue: 1,
            suffix: 'options.output.choices.1',
            write: (map) => map['options'] = {
              'output': option()..['choices'] = ['json', 1],
            },
          ),
          (
            description: 'a non-string choice option default',
            invalidValue: 1,
            suffix: 'options.output.default',
            write: (map) =>
                map['options'] = {'output': option()..['default'] = 1},
          ),
          (
            description: 'an unsupported option value type',
            invalidValue: 'duration',
            suffix: 'options.output.valueType',
            write: (map) => map['options'] = {
              'output': option()..['valueType'] = 'duration',
            },
          ),
          (
            description: 'a non-string paired option member',
            invalidValue: 1,
            suffix: 'options.output.pairedOptions.1',
            write: (map) => map['options'] = {
              'output': option()..['pairedOptions'] = ['paired', 1],
            },
          ),
          (
            description: 'a non-boolean persistent option required value',
            invalidValue: 'yes',
            suffix: 'persistentOptions.output.required',
            write: (map) => map['persistentOptions'] = {
              'output': option()..['required'] = 'yes',
            },
          ),
          (
            description: 'a non-boolean positional required value',
            invalidValue: 'yes',
            suffix: 'positionals.path.required',
            write: (map) => map['positionals'] = {
              'path': positional()..['required'] = 'yes',
            },
          ),
          (
            description: 'a non-boolean positional repeatable value',
            invalidValue: 'yes',
            suffix: 'positionals.path.repeatable',
            write: (map) => map['positionals'] = {
              'path': positional()..['repeatable'] = 'yes',
            },
          ),
          (
            description: 'a negative positional repetition count',
            invalidValue: -1,
            suffix: 'positionals.path.times',
            write: (map) =>
                map['positionals'] = {'path': positional()..['times'] = -1},
          ),
          (
            description: 'a non-string positional description',
            invalidValue: 1,
            suffix: 'positionals.path.description',
            write: (map) => map['positionals'] = {
              'path': positional()..['description'] = 1,
            },
          ),
          (
            description: 'a non-string variadic description',
            invalidValue: 1,
            suffix: 'variadic.description',
            write: (map) => map['variadic'] = {'description': 1},
          ),
          (
            description: 'a non-string variadic choice member',
            invalidValue: 1,
            suffix: 'variadic.choices.1',
            write: (map) => map['variadic'] = {
              'description': null,
              'choices': ['json', 1],
            },
          ),
          (
            description: 'a non-boolean repeated variadic value',
            invalidValue: 'yes',
            suffix: 'variadic.repeatable',
            write: (map) => map['variadic'] = {
              'description': null,
              'choices': ['json'],
              'repeatable': 'yes',
            },
          ),
          (
            description: 'a non-string variadic default',
            invalidValue: 1,
            suffix: 'variadic.default',
            write: (map) => map['variadic'] = {
              'description': null,
              'choices': ['json'],
              'default': 1,
            },
          ),
          (
            description: 'a non-string alias',
            invalidValue: 1,
            suffix: 'aliases.1',
            write: (map) => map['aliases'] = ['t', 1],
          ),
          (
            description: 'an unsupported command property',
            invalidValue: true,
            suffix: 'unsupported',
            write: (map) => map['unsupported'] = true,
          ),
          (
            description: 'a non-string nested command name',
            invalidValue: 1,
            suffix: 'commands.broken.name',
            write: (map) => map['commands'] = {
              'broken': {'name': 1, 'description': 'A broken command.'},
            },
          ),
          (
            description: 'a non-string nested command description',
            invalidValue: 1,
            suffix: 'commands.broken.description',
            write: (map) => map['commands'] = {
              'broken': {'name': 'broken', 'description': 1},
            },
          ),
        ];

    test('deeply freezes validated nested data', () {
      final source = registryMap({
        'options': {'output': option()},
      });
      final parsed = RegistryMap(source);

      (source['options'] as Map)['output']['required'] = true;

      expect((parsed.map['options'] as Map)['output']['required'], isFalse);
      expect(
        () => (parsed.map['options'] as Map)['output']['required'] = true,
        throwsUnsupportedError,
      );
    });

    test('requires name and description', () {
      for (final property in ['name', 'description']) {
        final map = registryMap()..remove(property);
        expect(() => RegistryMap(map), hasInvalidProperty(property, map));
      }
    });

    test('validates name and description as strings', () {
      for (final property in ['name', 'description']) {
        final map = registryMap({property: 1});
        expect(() => RegistryMap(map), hasInvalidProperty(property, 1));
      }
    });

    test('rejects unsupported command properties', () {
      final map = registryMap({'unsupported': true});

      expect(() => RegistryMap(map), hasInvalidProperty('unsupported', true));
    });

    test('requires props when an input entry is present', () {
      final cases =
          <({String property, Map<String, dynamic> value, String path})>[
            (
              property: 'flags',
              value: {'verbose': {}},
              path: 'flags.verbose.hidden',
            ),
            (
              property: 'persistentFlags',
              value: {'verbose': {}},
              path: 'persistentFlags.verbose.hidden',
            ),
            (
              property: 'options',
              value: {'output': {}},
              path: 'options.output.short',
            ),
            (
              property: 'persistentOptions',
              value: {'output': {}},
              path: 'persistentOptions.output.short',
            ),
            (
              property: 'positionals',
              value: {'path': {}},
              path: 'positionals.path.required',
            ),
          ];

      for (final entry in cases) {
        final map = registryMap({entry.property: entry.value});
        expect(
          () => RegistryMap(map),
          hasInvalidProperty(entry.path, entry.value.values.single),
        );
      }
    });

    test('requires an option value type', () {
      final missingType = option()..remove('valueType');
      final map = registryMap({
        'options': {'output': missingType},
      });

      expect(
        () => RegistryMap(map),
        hasInvalidProperty('options.output.valueType', missingType),
      );
    });

    test('rejects option groups that reference unknown members', () {
      final map = registryMap({
        'options': {'username': option()},
        'optionGroups': [
          {
            'mode': 'all',
            'required': false,
            'members': ['username', 'port'],
          },
        ],
      });

      expect(
        () => RegistryMap(map),
        hasInvalidProperty('optionGroups.0.members.1', 'port'),
      );
    });

    test('rejects option groups without members', () {
      final map = registryMap({
        'optionGroups': [
          {'mode': 'all', 'required': false, 'members': <String>[]},
        ],
      });

      expect(
        () => RegistryMap(map),
        hasInvalidProperty('optionGroups.0.members', <String>[]),
      );
    });

    test('rejects options assigned to more than one group', () {
      final map = registryMap({
        'options': {'json': option(), 'yaml': option(), 'text': option()},
        'optionGroups': [
          {
            'mode': 'oneOf',
            'required': false,
            'members': ['json', 'yaml'],
          },
          {
            'mode': 'oneOf',
            'required': false,
            'members': ['yaml', 'text'],
          },
        ],
      });

      expect(
        () => RegistryMap(map),
        hasInvalidProperty('optionGroups.1.members.0', 'yaml'),
      );
    });

    test('requires typed choice accessors to declare their choices', () {
      final choice = {
        'kind': 'value',
        'valueType': 'choice',
        'description': null,
      };
      final map = registryMap({
        'accessors': {
          'server': {
            'kind': 'group',
            'hidden': false,
            'description': null,
            'options': {'mode': choice},
          },
        },
      });

      expect(
        () => RegistryMap(map),
        hasInvalidProperty('accessors.server.options.mode.choices', choice),
      );
    });

    test('rejects unregistered typed accessor choice defaults', () {
      final map = registryMap({
        'accessors': {
          'server': {
            'kind': 'group',
            'hidden': false,
            'description': null,
            'options': {
              'mode': {
                'kind': 'value',
                'valueType': 'choice',
                'description': null,
                'choices': ['safe'],
                'default': 'fast',
              },
            },
          },
        },
      });

      expect(
        () => RegistryMap(map),
        hasInvalidProperty('accessors.server.options.mode.default', 'fast'),
      );
    });

    test('requires variadic props when variadic is present', () {
      final map = registryMap({'variadic': <String, dynamic>{}});

      expect(
        () => RegistryMap(map),
        hasInvalidProperty('variadic.description', map['variadic']),
      );
    });

    test('validates the collection type for every map property', () {
      final properties = [
        'flags',
        'persistentFlags',
        'options',
        'persistentOptions',
        'positionals',
        'variadic',
        'commands',
        'accessors',
      ];
      for (final property in properties) {
        final map = registryMap({property: 'not a map'});
        expect(
          () => RegistryMap(map),
          hasInvalidProperty(property, 'not a map'),
        );
      }
    });

    test('validates aliases as a list of strings', () {
      final map = registryMap({'aliases': 'tool'});

      expect(() => RegistryMap(map), hasInvalidProperty('aliases', 'tool'));
    });

    test('requires non-empty string keys in input collections', () {
      final nonStringKeyMap = registryMap({
        'flags': {1: booleanFlag()},
      });
      final emptyKeyMap = registryMap({
        'options': {'': option()},
      });

      expect(
        () => RegistryMap(nonStringKeyMap),
        hasInvalidProperty('flags', 1),
      );
      expect(() => RegistryMap(emptyKeyMap), hasInvalidProperty('options', ''));
    });

    test('requires each nested command name and description', () {
      for (final property in ['name', 'description']) {
        final map = registryMap({
          'commands': {
            'sub': {
              if (property != 'name') 'name': 'sub',
              if (property != 'description') 'description': 'A subcommand.',
            },
          },
        });
        expect(
          () => RegistryMap(map),
          hasInvalidProperty('commands.sub.$property', map['commands']['sub']),
        );
      }
    });

    for (final depth in [1, 2, 3, 4, 5]) {
      final commandPath = List.generate(
        depth,
        (index) => 'command${index + 1}',
      ).join(' > ');
      group('nested commands at depth $depth', () {
        for (final property in invalidDescendantProperties) {
          test('reports ${property.description} below $commandPath', () {
            final nested = nestedCommandMap(depth);
            property.write(nested.leaf);
            final path = nestedPath(nested.names, property.suffix);

            expect(
              () => RegistryMap(nested.root),
              hasInvalidProperty(path, property.invalidValue),
            );
          });
        }
      });
    }
  });
}
