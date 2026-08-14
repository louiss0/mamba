import 'package:arg_parser/help_formatter.dart';
import 'package:arg_parser/parser.dart';
import 'package:arg_parser/registry.dart';
import 'package:test/test.dart';

enum ConfigMode { auto, always }

class DefaultAccessors extends AccessorOptionSchema<({String mode, int port})> {
  @override
  final schema = <AccessorOption>[
    AccessorListOption(
      name: 'server',
      options: [
        AccessorListOption(
          name: 'database',
          options: [
            AccessorChoiceOption<ConfigMode>(
              name: 'mode',
              choices: ConfigMode.values,
              defaultValue: ConfigMode.auto,
            ),
            AccessorIntOption(name: 'port'),
          ],
        ),
      ],
    ),
  ];

  @override
  ({String mode, int port}) toRecord(Map<String, dynamic> args) {
    final database =
        ((args['server'] as Map<String, Object>)['database']
            as Map<String, Object>);
    return (
      mode: database['mode'] as String,
      port: int.parse(database['port'] as String),
    );
  }
}

class RemoteAccessors
    extends AccessorOptionSchema<({String fetch, String push})> {
  @override
  final schema = <AccessorOption>[
    AccessorListOption(
      name: 'remote',
      options: [
        AccessorListOption(
          name: 'origin',
          options: [
            AccessorListOption(
              name: 'urls',
              options: [
                AccessorStringOption(name: 'fetch'),
                AccessorStringOption(name: 'push'),
              ],
            ),
          ],
        ),
      ],
    ),
  ];

  @override
  ({String fetch, String push}) toRecord(Map<String, dynamic> args) {
    final urls =
        (((args['remote'] as Map<String, Object>)['origin']
                as Map<String, Object>)['urls']
            as Map<String, Object>);
    return (fetch: urls['fetch'] as String, push: urls['push'] as String);
  }
}

class NestedConfigAccessors extends AccessorOptionSchema<({String value})> {
  NestedConfigAccessors(this.levels)
    : names = [
        for (var level = 1; level < levels; level++) 'level$level',
        'value',
      ];

  final int levels;
  final List<String> names;

  @override
  List<AccessorOption> get schema => [_accessorAt(0)];

  AccessorOption _accessorAt(int index) {
    final name = names[index];
    if (index == names.length - 1) return AccessorStringOption(name: name);
    return AccessorListOption(name: name, options: [_accessorAt(index + 1)]);
  }

  @override
  ({String value}) toRecord(Map<String, dynamic> args) {
    Object value = args;
    for (final name in names) {
      value = (value as Map<String, Object>)[name]!;
    }
    return (value: value as String);
  }

  String get path => names.join('.');
}

void main() {
  group('Recursive Git-config-style accessors', () {
    for (final levels in [2, 3, 4, 5]) {
      test('parses an accessor with $levels levels', () {
        final accessors = NestedConfigAccessors(levels);
        final parser = Parser(
          CommandRegistry.create(
            'config',
            'Read configuration.',
            accessorSchema: accessors,
          ),
        );

        final inputs = parser.parse(['--${accessors.path}', 'configured']).$2;

        expect(inputs.acessors, (value: 'configured'));
      });
    }

    test('merges nested choice defaults with parsed accessor values', () {
      final parser = Parser(
        CommandRegistry.create(
          'config',
          'Read configuration.',
          accessorSchema: DefaultAccessors(),
        ),
      );

      final inputs = parser.parse(['--server.database.port', '5432']).$2;

      expect(inputs.acessors, (mode: 'auto', port: 5432));
    });

    test('merges sibling values at four accessor levels', () {
      final parser = Parser(
        CommandRegistry.create(
          'config',
          'Read configuration.',
          accessorSchema: RemoteAccessors(),
        ),
      );

      final inputs = parser.parse([
        '--remote.origin.urls.fetch',
        'https://fetch.example',
        '--remote.origin.urls.push',
        'https://push.example',
      ]).$2;

      expect(inputs.acessors, (
        fetch: 'https://fetch.example',
        push: 'https://push.example',
      ));
    });

    test('parses an accessor with 10 levels', () {
      final accessors = NestedConfigAccessors(10);
      final parser = Parser(
        CommandRegistry.create(
          'config',
          'Read configuration.',
          accessorSchema: accessors,
        ),
      );

      final inputs = parser.parse(['--${accessors.path}', 'configured']).$2;

      expect(inputs.acessors, (value: 'configured'));
    });

    test('renders the complete path for nested accessor help', () {
      final accessors = NestedConfigAccessors(5);
      final registry = CommandRegistry.create(
        'config',
        'Read configuration.',
        accessorSchema: accessors,
      );

      expect(HelpFormatter().formatHelp(registry), contains(accessors.path));
    });
  });
}
