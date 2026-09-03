import 'dart:io';

import 'package:mamba/command.dart';
import 'package:mamba/errors.dart';
import 'package:mamba/integrations.dart';
import 'package:mamba/registry.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

enum _Format { json, yaml }

enum _Level { debug, info }

enum _Sku { basic, standard }

/// Builds a root registry named `spec` around the given inputs and children.
CommandRegistry specRegistry({
  List<Flag>? flags,
  List<Option>? options,
  List<PairedOptions>? pairedOptions,
  List<Positional>? mandatoryPositionals,
  List<Positional>? discretionaryPositionals,
  Variadic? variadic,
  List<AccessorListOption>? accessors,
  List<Command>? commands,
}) => CommandRegistry.create(
  'spec',
  'spec command',
  flags: flags,
  options: options,
  pairedOptions: pairedOptions,
  mandatoryPositionals: mandatoryPositionals,
  discretionaryPositionals: discretionaryPositionals,
  variadic: variadic,
  accessors: accessors,
  commands: commands,
);

/// Renders the Carapace spec exported by [registryMap].
String convertSpec(RegistryMap registryMap) =>
    CarapaceSpecConverter(registryMap).convert();

String convertBash(RegistryMap registryMap) =>
    ToBashCompletionConverter(registryMap).convert();

String convertZsh(RegistryMap registryMap) =>
    ToZshCompletionConverter(registryMap).convert();

String convertPs(RegistryMap registryMap) =>
    ToPowerShellCompletionConverter(registryMap).convert();

Future<List<String>> completeBash(String completion, List<String> words) async {
  final bash = Platform.isWindows
      ? '${Platform.environment['ProgramFiles']}\\Git\\bin\\bash.exe'
      : 'bash';
  if (Platform.isWindows && !File(bash).existsSync()) {
    markTestSkipped('Git Bash is required for Bash completion runtime tests.');
    return const [];
  }

  final fixture = await Directory.systemTemp.createTemp('mamba-bash-');
  try {
    final completionFile = File('${fixture.path}/completion.bash');
    await completionFile.writeAsString(completion);
    final source = Platform.isWindows
        ? completionFile.path
              .replaceAll('\\', '/')
              .replaceFirst(
                RegExp(r'^([A-Za-z]):'),
                '/${completionFile.path[0].toLowerCase()}',
              )
        : completionFile.path;
    final encodedWords = words.map(_quoteBash).join(' ');
    final script = [
      'source ${_quoteBash(source)}',
      'COMP_WORDS=($encodedWords)',
      'COMP_CWORD=${words.length - 1}',
      '_spec_completion',
      r'''printf '%s\\n' "${COMPREPLY[@]}"''',
    ].join('\n');
    final result = await Process.run(bash, ['-c', script]);
    expect(result.exitCode, 0, reason: result.stderr as String);
    return (result.stdout as String)
        .split('\n')
        .where((candidate) => candidate.isNotEmpty)
        .toList();
  } finally {
    await fixture.delete(recursive: true);
  }
}

String _quoteBash(String value) => "'${value.replaceAll("'", "'\\\"'\\\"'")}'";

Future<List<String>> completePowerShell(
  String completion,
  String commandLine,
) async {
  final executable = Platform.isWindows ? 'powershell.exe' : 'pwsh';
  final fixture = await Directory.systemTemp.createTemp('mamba-powershell-');
  try {
    final script = File('${fixture.path}/completion.ps1');
    await script.writeAsString('''
$completion
\$line = ${_quotePowerShell(commandLine)}
\$result = TabExpansion2 \$line \$line.Length
\$result.CompletionMatches | ForEach-Object { \$_.CompletionText }
''');
    ProcessResult result;
    try {
      result = await Process.run(executable, [
        '-NoProfile',
        '-NonInteractive',
        if (Platform.isWindows) ...['-ExecutionPolicy', 'Bypass'],
        '-File',
        script.path,
      ]);
    } on ProcessException {
      markTestSkipped('PowerShell is required for completion runtime tests.');
      return const [];
    }
    expect(result.exitCode, 0, reason: result.stderr as String);
    return (result.stdout as String)
        .split(RegExp(r'\r?\n'))
        .where((candidate) => candidate.isNotEmpty)
        .toList();
  } finally {
    await fixture.delete(recursive: true);
  }
}

String _quotePowerShell(String value) => "'${value.replaceAll("'", "''")}'";

/// Compares specs after dropping trailing whitespace, obsolete numeric-range
/// expectations, and the final newline.
Matcher equalsYaml(String expected) => predicate<String>(
  (actual) => _normalizeYaml(actual) == _normalizeYaml(expected),
  'equals the expected Carapace spec:\n$expected',
);

String _normalizeYaml(String yaml) {
  final lines = yaml
      .split('\n')
      .map((line) => line.trimRight())
      .where((line) => !line.contains('carapace.number.Range('))
      .toList();

  // Numeric ranges are no longer generated without author-supplied domain
  // metadata. Prune mapping nodes left empty after removing old expectations.
  var changed = true;
  while (changed) {
    changed = false;
    for (var index = lines.length - 1; index >= 0; index--) {
      if (!lines[index].trimRight().endsWith(':')) continue;
      final currentIndent =
          lines[index].length - lines[index].trimLeft().length;
      final nextIndent = index + 1 < lines.length
          ? lines[index + 1].length - lines[index + 1].trimLeft().length
          : -1;
      if (nextIndent <= currentIndent) {
        lines.removeAt(index);
        changed = true;
      }
    }
  }
  return lines.join('\n').trim();
}

/// Modifier slots ordered `<key><repeatability><optionality><appearance><arity>`.
typedef ModifierCombo = ({
  bool repeatability,
  bool optionality,
  bool appearance,
  bool arity,
});

/// Every modifier combination whose slot can exist for a real input.
///
/// Mamba flags cannot be required, so an `optionality` slot only combines with
/// an `arity` slot where value-taking options live.
final List<ModifierCombo> modifierCombos = [
  for (final repeatability in [false, true])
    for (final optionality in [false, true])
      for (final appearance in [false, true])
        for (final arity in [false, true])
          if (!optionality || arity)
            (
              repeatability: repeatability,
              optionality: optionality,
              appearance: appearance,
              arity: arity,
            ),
];

/// Group command names for nested chains, indexed by level below the root.
const nestedGroupNames = ['alpha', 'beta', 'gamma', 'delta'];

/// Builds a root registry whose inputs must travel down [depth] subcommand
/// levels before reaching the leaf.
CommandRegistry nestedRegistry(
  int depth, {
  List<Flag>? flags,
  List<Option>? options,
  List<PairedOptions>? pairedOptions,
}) {
  List<Command> buildChain(int remaining) {
    if (remaining <= 1) return [TestCommand('leaf', 'leaf command')];
    final groupName = nestedGroupNames[depth - remaining];
    return [
      TestGroupCommand(
        groupName,
        buildChain(remaining - 1),
        '$groupName command',
      ),
    ];
  }

  return specRegistry(
    flags: flags,
    options: options,
    pairedOptions: pairedOptions,
    commands: buildChain(depth),
  );
}

/// Renders one nested command level; every descendant publishes the same
/// [persistentEntries] while the leaf ends the chain.
List<String> nestedCommandLines(
  String name,
  List<String> remaining,
  String indent,
  List<String> persistentEntries,
) {
  final lines = <String>[
    '$indent- name: "$name"',
    '$indent  description: "$name command"',
    '$indent  flags:',
    '$indent    -h, --help: "Show this help message."',
  ];
  if (remaining.isNotEmpty) {
    lines
      ..add('$indent  commands:')
      ..addAll(
        nestedCommandLines(
          remaining.first,
          remaining.sublist(1),
          '$indent    ',
          persistentEntries,
        ),
      );
  }
  return lines;
}

/// Builds the full expected spec for a nested chain of [depth] subcommands.
String nestedExpectation({
  required int depth,
  required List<String> rootFlagEntries,
  required List<String> persistentEntries,
  List<String>? rootCompletionLines,
}) {
  final names = [
    for (var index = 0; index < depth - 1; index++) nestedGroupNames[index],
    'leaf',
  ];
  final lines = <String>[
    'name: "spec"',
    'description: "spec command"',
    'persistentflags:',
    '  -h, --help: "Show this help message."',
  ];
  if (rootFlagEntries.isNotEmpty) {
    lines.addAll([for (final entry in rootFlagEntries) '  $entry']);
  }
  if (rootCompletionLines != null) lines.addAll(rootCompletionLines);
  lines.add('commands:');
  lines.addAll(
    nestedCommandLines(names.first, names.sublist(1), '  ', persistentEntries),
  );
  return lines.join('\n');
}

void main() {
  group('ToFishCompletionConverter', () {
    String convertFish(CommandRegistry registry) =>
        ToFishCompletionConverter(registry.toMap()).convert();

    String fishDeclarations(String output) => output
        .split('\n')
        .where((line) => line.startsWith('complete '))
        .join('\n');

    String fishDeclaration(String output, String fragment) => output
        .split('\n')
        .firstWhere(
          (line) => line.startsWith('complete ') && line.contains(fragment),
        );

    test('renders root flags, typed options, and a multi-line description', () {
      final output = convertFish(
        CommandRegistry.create(
          'spec',
          'Root command.',
          longDescription: 'Additional root details.',
          flags: [
            BooleanFlag('force', short: 'f'),
            BooleanFlag('color', negatable: true),
            CountFlag('verbose'),
          ],
          options: [
            StringOption('label', short: 'l'),
            IntOption('retries'),
            DoubleOption('ratio'),
            RepeatableStringOption('tag'),
            RepeatableIntOption('port'),
            RepeatableDoubleOption('weight'),
          ],
        ),
      );

      expect(
        fishDeclarations(output),
        equals('''complete -c spec -s h -l help -d 'Show this help message.'
complete -c spec -s f -l force
complete -c spec -l color
complete -c spec -l no-color
complete -c spec -l verbose
complete -c spec -n '__mamba_option_available label l false' -s l -l label -r
complete -c spec -n '__mamba_option_available retries _ false' -l retries -x
complete -c spec -n '__mamba_option_available ratio _ false' -l ratio -x
complete -c spec -n '__mamba_option_available tag _ true' -l tag -r
complete -c spec -n '__mamba_option_available port _ true' -l port -x
complete -c spec -n '__mamba_option_available weight _ true' -l weight -x'''),
      );
    });

    test('enumerates stepped double values', () {
      final output = convertFish(
        specRegistry(
          options: [DoubleOption('ratio', min: 0, max: 0.3, step: 0.1)],
        ),
      );

      expect(output, contains("-l ratio -x -a '0.0 0.1 0.2 0.3'"));
    });

    test(
      'renders subcommand inputs, accessors, positionals, and variadics',
      () {
        final output = convertFish(
          specRegistry(
            commands: [
              TestCommand(
                'serve',
                'Serve requests.',
                longDescription: 'Additional serving details.',
                flags: [
                  BooleanFlag('force', short: 'f'),
                  BooleanFlag('color', negatable: true),
                  CountFlag('verbose'),
                ],
                options: [
                  StringOption('label', short: 'l'),
                  IntOption('retries'),
                  DoubleOption('ratio'),
                  RepeatableStringOption('tag'),
                  RepeatableIntOption('port'),
                  RepeatableDoubleOption('weight'),
                ],
                accessors: [
                  AccessorListOption(
                    'server',
                    options: [
                      AccessorStringOption('host'),
                      AccessorIntOption('port'),
                      AccessorDoubleOption('ratio'),
                    ],
                  ),
                  AccessorListOption(
                    'one',
                    options: [
                      AccessorListOption(
                        'two',
                        options: [AccessorStringOption('three')],
                      ),
                    ],
                  ),
                  AccessorListOption(
                    'a',
                    options: [
                      AccessorListOption(
                        'b',
                        options: [
                          AccessorListOption(
                            'c',
                            options: [
                              AccessorListOption(
                                'd',
                                options: [
                                  AccessorListOption(
                                    'e',
                                    options: [AccessorStringOption('value')],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
                mandatoryPositionals: [
                  ChoicePositional<_Format>('format', choices: _Format.values),
                ],
                discretionaryPositionals: [
                  RepeatedChoicePositional<_Level>(
                    'level',
                    choices: _Level.values,
                    times: 2,
                  ),
                ],
                variadic: RepeatedChoiceVariadic<_Sku>(
                  'extra',
                  choices: _Sku.values,
                ),
              ),
            ],
          ),
        );

        final declarations = fishDeclarations(output);
        expect(
          declarations,
          allOf([
            contains('__mamba_selecting_child'),
            contains("-f -a 'serve' -d 'Serve requests.'"),
            contains('-s f -l force'),
            contains('-l no-color'),
            contains('-s l -l label -r'),
            contains('-l retries -x'),
            contains('-l server.host -r'),
            contains('-l one.two.three -r'),
            contains('-l a.b.c.d.e.value -r'),
            contains("__mamba_positional_slot 0"),
            contains("__mamba_positional_slot 3"),
            contains("-a 'json yaml'"),
            contains("-a 'debug info'"),
            contains('__mamba_variadic_available true'),
            contains("-a 'basic standard'"),
          ]),
        );
      },
    );

    test('escapes Fish-special text in descriptions and choices', () {
      final output = convertFish(
        specRegistry(
          options: [
            ChoiceOption<_Format>(
              'format',
              choices: _Format.values,
              defaultValue: _Format.json,
              description: "format's output",
            ),
          ],
        ),
      );

      expect(output, contains("-d 'format\\'s output'"));
    });

    test('omits hidden root flags', () {
      final output = convertFish(
        specRegistry(flags: [BooleanFlag('secret', hidden: true)]),
      );

      expect(output, isNot(contains('-l secret')));
    });

    test('omits hidden root options', () {
      final output = convertFish(
        specRegistry(options: [StringOption('token', hidden: true)]),
      );

      expect(
        output,
        isNot(contains('complete -c spec -n \'__mamba_option_available token')),
      );
    });

    test('advertises subcommand aliases', () {
      final output = convertFish(
        specRegistry(
          commands: [
            TestCommand('serve', 'Serve requests.', aliases: ['s']),
          ],
        ),
      );

      expect(output, contains("-a 'serve s'"));
      expect(output, contains('serve,s|help'));
    });

    test('includes root option metadata in descendant path routing', () {
      final output = convertFish(
        specRegistry(
          options: [StringOption('profile', short: 'p')],
          commands: [TestCommand('serve', 'Serve requests.')],
        ),
      );

      final declaration = output
          .split('\n')
          .firstWhere(
            (line) =>
                line.startsWith('complete ') &&
                line.contains('__mamba_at_path') &&
                line.contains('serve|help'),
          );
      expect(declaration, contains('spec|help|h|profile|p|serve'));
    });

    test(
      'routes canonical subcommand inputs through a command-path condition',
      () {
        final output = convertFish(
          specRegistry(
            commands: [
              TestCommand(
                'serve',
                'Serve requests.',
                flags: [BooleanFlag('force')],
              ),
            ],
          ),
        );

        final declaration = fishDeclaration(output, '-l force');
        expect(declaration, contains('__mamba_at_path'));
        expect(declaration, contains('serve|help,force'));
      },
    );

    test('routes nested subcommands through their complete command path', () {
      final output = convertFish(
        specRegistry(
          commands: [
            TestGroupCommand('config', [
              TestCommand('set', 'Set a value.'),
            ], 'Configure settings.'),
          ],
        ),
      );

      final declaration = fishDeclaration(output, "-a 'set'");
      expect(declaration, contains('__mamba_selecting_child'));
      expect(declaration, contains('config|help'));
    });

    test('routes commands through multiple nested groups', () {
      final output = convertFish(
        specRegistry(
          commands: [
            TestGroupCommand('config', [
              TestGroupCommand('remote', [
                TestCommand(
                  'set',
                  'Set a remote.',
                  flags: [BooleanFlag('force')],
                ),
              ], 'Manage remotes.'),
            ], 'Configure settings.'),
          ],
        ),
      );

      expect(
        output,
        equals(r'''# Completion for spec: spec command
function __mamba_segment_field
    set -l fields (string split '|' -- $argv[1])
    string split ',' -- $fields[$argv[2]]
end

function __mamba_input_width
    set -l spec $argv[1]
    set -l token $argv[2]
    if string match -q -- '--*' $token
        set -l long (string replace -r '^--' '' -- $token)
        set -l parts (string split -m 1 '=' -- $long)
        if contains -- $parts[1] (__mamba_segment_field $spec 4)
            if test (count $parts) -eq 1
                echo 2
            else
                echo 1
            end
            return
        end
        if contains -- $parts[1] (__mamba_segment_field $spec 2)
            echo 1
            return
        end
        echo 0
        return
    end
    if string match -q -- '-*' $token
        set -l short (string sub -s 2 -- $token)
        if test (string length -- $short) -eq 1; and contains -- $short (__mamba_segment_field $spec 5)
            echo 2
            return
        end
        for name in (string split '' -- $short)
            if not contains -- $name (__mamba_segment_field $spec 3)
                echo 0
                return
            end
        end
        if test -n "$short"
            echo 1
            return
        end
    end
    echo 0
end

function __mamba_path_state
    set -l mode $argv[1]
    set -e argv[1]
    set -l specs $argv
    set -l tokens (commandline -xpc)
    set -e tokens[1]
    set -l depth 1
    set -l offset 1
    set -l selecting true
    while test $offset -le (count $tokens)
        set -l token $tokens[$offset]
        if test "$token" = --
            set selecting false
            break
        end
        if test $depth -lt (count $specs)
            set -l next_depth (math $depth + 1)
            if contains -- $token (__mamba_segment_field $specs[$next_depth] 1)
                set depth $next_depth
                set offset (math $offset + 1)
                continue
            end
        end
        if contains -- $token (__mamba_segment_field $specs[$depth] 6)
            return 1
        end
        set -l width (__mamba_input_width $specs[$depth] $token)
        if test $width -gt 0
            if test $width -eq 2; and test $offset -eq (count $tokens)
                set selecting false
            end
            set offset (math $offset + $width)
            continue
        end
        set selecting false
        break
    end
    if test $depth -ne (count $specs)
        return 1
    end
    if test "$mode" = selecting
        test "$selecting" = true
        return
    end
    return 0
end

function __mamba_at_path
    __mamba_path_state path $argv
end

function __mamba_selecting_child
    __mamba_path_state selecting $argv
end

function __mamba_after_double_dash
    contains -- -- (commandline -xpc)
end

function __mamba_option_available
    set -l option --$argv[1]
    set -l short $argv[2]
    set -l repeatable $argv[3]
    if test "$repeatable" = true
        return 0
    end
    set -l tokens (commandline -xpc)
    for index in (seq (count $tokens))
        set -l token $tokens[$index]
        if string match -q -- "$option=*" $token
            return 1
        end
        if test "$token" = "$option"
            if test $index -lt (count $tokens)
                return 1
            end
            return 0
        end
        if test "$short" != _; and test "$token" = -$short
            if test $index -lt (count $tokens)
                return 1
            end
            return 0
        end
    end
    return 0
end

function __mamba_positional_slot
    set -l target $argv[1]
    set -e argv[1]
    set -l specs $argv
    set -l tokens (commandline -xpc)
    set -e tokens[1]
    set -l depth 1
    set -l offset 1
    set -l count 0
    while test $offset -le (count $tokens)
        set -l token $tokens[$offset]
        if test "$token" = --
            break
        end
        if test $depth -lt (count $specs)
            set -l next_depth (math $depth + 1)
            if contains -- $token (__mamba_segment_field $specs[$next_depth] 1)
                set depth $next_depth
                set offset (math $offset + 1)
                continue
            end
        end
        if contains -- $token (__mamba_segment_field $specs[$depth] 6)
            return 1
        end
        set -l width (__mamba_input_width $specs[$depth] $token)
        if test $width -gt 0
            set offset (math $offset + $width)
            continue
        end
        if test $depth -lt (count $specs)
            return 1
        end
        set count (math $count + 1)
        set offset (math $offset + 1)
    end
    test $depth -eq (count $specs); and test $count -eq $target
end

function __mamba_variadic_available
    if test "$argv[1]" = true
        return 0
    end
    set -l after_separator false
    set -l count 0
    for token in (commandline -xpc)
        if test "$after_separator" = true
            set count (math $count + 1)
        else if test "$token" = --
            set after_separator true
        end
    end
    test $count -eq 0
end

complete -c spec -s h -l help -d 'Show this help message.'
complete -c spec -n '__mamba_selecting_child \'spec|help|h|||config\'' -f -a 'config' -d 'Configure settings.'
complete -c spec -n '__mamba_at_path \'spec|help|h|||config\' \'config|help|h|||remote\'' -s h -l help -d 'Show this help message.'
complete -c spec -n '__mamba_selecting_child \'spec|help|h|||config\' \'config|help|h|||remote\'' -f -a 'remote' -d 'Manage remotes.'
complete -c spec -n '__mamba_at_path \'spec|help|h|||config\' \'config|help|h|||remote\' \'remote|help|h|||set\'' -s h -l help -d 'Show this help message.'
complete -c spec -n '__mamba_selecting_child \'spec|help|h|||config\' \'config|help|h|||remote\' \'remote|help|h|||set\'' -f -a 'set' -d 'Set a remote.'
complete -c spec -n '__mamba_at_path \'spec|help|h|||config\' \'config|help|h|||remote\' \'remote|help|h|||set\' \'set|help,force|h|||\'' -s h -l help -d 'Show this help message.'
complete -c spec -n '__mamba_at_path \'spec|help|h|||config\' \'config|help|h|||remote\' \'remote|help|h|||set\' \'set|help,force|h|||\'' -l force
'''),
      );
    });

    test('inherits root inputs at subcommand paths', () {
      final output = convertFish(
        specRegistry(
          flags: [BooleanFlag('verbose')],
          commands: [TestCommand('serve', 'Serve requests.')],
        ),
      );

      final declaration = output
          .split('\n')
          .firstWhere(
            (line) =>
                line.startsWith('complete ') &&
                line.contains('-l verbose') &&
                line.contains('__mamba_at_path'),
          );
      expect(declaration, contains('__mamba_at_path'));
      expect(declaration, contains('serve|help,verbose'));
    });

    test('inherits group persistent inputs at descendant paths', () {
      final output = convertFish(
        specRegistry(
          commands: [
            TestGroupCommand(
              'config',
              [TestCommand('set', 'Set a value.')],
              'Configure settings.',
              inheritedOptions: [StringOption('profile')],
            ),
          ],
        ),
      );

      final declaration = output
          .split('\n')
          .where(
            (line) =>
                line.startsWith('complete ') && line.contains('-l profile'),
          )
          .last;
      expect(declaration, contains('__mamba_at_path'));
      expect(declaration, contains('set|help|h|profile'));
    });

    test('uses a local option in preference to a persistent option', () {
      final output = convertFish(
        specRegistry(
          commands: [
            TestGroupCommand(
              'config',
              [TestCommand('set', 'Set a value.')],
              'Configure settings.',
              inheritedOptions: [IntOption('retries')],
              options: [StringOption('retries')],
            ),
          ],
        ),
      );

      final declarations = output
          .split('\n')
          .where(
            (line) =>
                line.startsWith('complete ') && line.contains('-l retries'),
          )
          .toList();
      expect(declarations, hasLength(2));
      expect(declarations[0], endsWith('-l retries -r'));
      expect(declarations[1], endsWith('-l retries -x'));
    });

    test('does not inherit a group-local option into its child', () {
      final output = convertFish(
        specRegistry(
          commands: [
            TestGroupCommand(
              'config',
              [TestCommand('set', 'Set a value.')],
              'Configure settings.',
              options: [StringOption('local')],
            ),
          ],
        ),
      );

      final localDeclarations = output
          .split('\n')
          .where(
            (line) => line.startsWith('complete ') && line.contains('-l local'),
          )
          .toList();
      expect(localDeclarations, hasLength(1));
      expect(localDeclarations.single, contains('config|help'));
      expect(localDeclarations.single, isNot(contains('set|help')));
    });

    test('suppresses non-repeatable options after use', () {
      final output = convertFish(
        specRegistry(options: [StringOption('label')]),
      );

      expect(output, contains('__mamba_option_available label _ false'));
    });

    test('keeps repeatable options available after use', () {
      final output = convertFish(
        specRegistry(options: [RepeatableStringOption('tag')]),
      );

      expect(output, contains('__mamba_option_available tag _ true'));
    });

    test('keeps unconstrained positionals in the slot sequence', () {
      final output = convertFish(
        specRegistry(
          mandatoryPositionals: [
            NormalPositional('path'),
            ChoicePositional<_Format>('format', choices: _Format.values),
          ],
        ),
      );

      expect(output, contains('__mamba_positional_slot 1'));
    });

    test('emits every bounded repeated positional slot', () {
      final output = convertFish(
        specRegistry(
          discretionaryPositionals: [
            RepeatedChoicePositional<_Format>(
              'format',
              choices: _Format.values,
              times: 2,
            ),
          ],
        ),
      );

      expect(
        output,
        allOf([
          contains('__mamba_positional_slot 0'),
          contains('__mamba_positional_slot 1'),
          contains('__mamba_positional_slot 2'),
        ]),
      );
    });

    test(
      'composes root positional conditions without a leading conjunction',
      () {
        final output = convertFish(
          specRegistry(
            mandatoryPositionals: [
              ChoicePositional<_Format>('format', choices: _Format.values),
            ],
          ),
        );

        final declaration = fishDeclaration(output, "-a 'json yaml'");
        expect(declaration, contains("-n 'not __mamba_after_double_dash"));
        expect(declaration, isNot(contains("-n '; and")));
      },
    );

    test('gates a single-value choice variadic after its first value', () {
      final output = convertFish(
        specRegistry(
          variadic: ChoiceVariadic<_Sku>('extra', choices: _Sku.values),
        ),
      );

      final declaration = fishDeclaration(output, "-a 'basic standard'");
      expect(declaration, contains('__mamba_variadic_available false'));
      expect(declaration, isNot(contains("-n '; and")));
    });

    test('preserves Fish apostrophes and literal backslashes', () {
      final output = convertFish(
        specRegistry(
          options: [
            StringOption('path', description: r"owner's C:\tools path"),
          ],
        ),
      );

      expect(output, contains(r"-d 'owner\'s C:\\tools path'"));
    });

    test('keeps normal variadics candidate-free after --', () {
      final output = convertFish(
        specRegistry(variadic: NormalVariadic('extra', regExp: RegExp(r'.+'))),
      );

      expect(output, isNot(contains('__mamba_after_double_dash\' -f -a')));
    });

    test('omits every leaf below a hidden accessor group', () {
      final output = convertFish(
        specRegistry(
          accessors: [
            AccessorListOption(
              'internal',
              hidden: true,
              options: [AccessorStringOption('token')],
            ),
          ],
          commands: [TestCommand('serve', 'Serve requests.')],
        ),
      );

      expect(
        output.split('\n').where((line) => line.startsWith('complete ')),
        everyElement(isNot(contains('-l internal.token'))),
      );
      expect(output, contains('|internal.token|'));
    });
  });
  group('ToZshCompletionConverter', () {
    String rootCompletion({
      List<Flag>? flags,
      List<Option>? options,
      List<Command>? commands,
    }) => convertZsh(
      specRegistry(flags: flags, options: options, commands: commands).toMap(),
    );

    test(
      'renders root flags, typed options, and descriptions as Zsh specs',
      () {
        final completion = convertZsh(
          CommandRegistry.create(
            'spec',
            'Root command.',
            longDescription: 'Additional root details.',
            flags: [
              BooleanFlag('force', short: 'f'),
              BooleanFlag('color', negatable: true),
              CountFlag('verbose'),
            ],
            options: [
              StringOption('name', short: 'n'),
              IntOption('retries'),
              DoubleOption('ratio'),
              RepeatableStringOption('include'),
              RepeatableIntOption('attempt'),
              RepeatableDoubleOption('weight'),
            ],
          ).toMap(),
        );

        expect(
          completion,
          equals('''#compdef spec

_spec() {
  local context state state_descr line
  typeset -A opt_args
  if (( \${words[(I:--)]} )); then
    :
    return
  fi
  _arguments -S \\
    '{-h,--help}[Show this help message.]' \\
    '{-f,--force}[]' \\
    '--color[]' \\
    '--no-color[]' \\
    '*--verbose[]' \\
    '{-n,--name}[]:name:' \\
    '--retries[]:retries:_numbers' \\
    '--ratio[]:ratio:_numbers -f' \\
    '*--include[]:include:' \\
    '*--attempt[]:attempt:_numbers' \\
    '*--weight[]:weight:_numbers -f' \\
    '*::argument:'
  case \$state in
  esac
}

compdef _spec spec
'''),
        );
      },
    );

    test('renders nested commands, accessors, choices, and variadics', () {
      final completion = convertZsh(
        specRegistry(
          commands: [
            TestGroupCommand('config', [
              TestCommand(
                'set',
                'Set configuration.\n\nAdditional serving details.',
                aliases: ['s'],
                flags: [
                  BooleanFlag('force', short: 'f'),
                  BooleanFlag('color', negatable: true),
                  CountFlag('verbose'),
                ],
                options: [
                  StringOption('name', short: 'n'),
                  IntOption('retries'),
                  DoubleOption('ratio'),
                  RepeatableStringOption('include'),
                  RepeatableIntOption('attempt'),
                  RepeatableDoubleOption('weight'),
                ],
                accessors: [
                  AccessorListOption(
                    'server',
                    options: [
                      AccessorStringOption('host'),
                      AccessorIntOption('port'),
                      AccessorDoubleOption('ratio'),
                    ],
                  ),
                  AccessorListOption(
                    'one',
                    options: [
                      AccessorListOption(
                        'two',
                        options: [AccessorStringOption('three')],
                      ),
                    ],
                  ),
                  AccessorListOption(
                    'a',
                    options: [
                      AccessorListOption(
                        'b',
                        options: [
                          AccessorListOption(
                            'c',
                            options: [
                              AccessorListOption(
                                'd',
                                options: [
                                  AccessorListOption(
                                    'e',
                                    options: [AccessorStringOption('value')],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
                mandatoryPositionals: [
                  ChoicePositional<_Format>('format', choices: _Format.values),
                ],
                discretionaryPositionals: [
                  RepeatedChoicePositional<_Level>(
                    'level',
                    choices: _Level.values,
                    times: 2,
                  ),
                ],
                variadic: RepeatedChoiceVariadic<_Sku>(
                  'extra',
                  choices: _Sku.values,
                ),
              ),
            ], 'Configure the application.'),
          ],
        ).toMap(),
      );

      expect(
        completion,
        equals('''#compdef spec

_spec_config_set() {
  local -a words
  words=("\${words[@]:2}")
  (( CURRENT -= 1 ))
  local context state state_descr line
  typeset -A opt_args
  if (( \${words[(I:--)]} )); then
    _values 'value' 'basic' 'standard'
    return
  fi
  _arguments -S \\
    '{-h,--help}[Show this help message.]' \\
    '{-f,--force}[]' \\
    '--color[]' \\
    '--no-color[]' \\
    '*--verbose[]' \\
    '{-n,--name}[]:name:' \\
    '--retries[]:retries:_numbers' \\
    '--ratio[]:ratio:_numbers -f' \\
    '*--include[]:include:' \\
    '*--attempt[]:attempt:_numbers' \\
    '*--weight[]:weight:_numbers -f' \\
    '--server.host[]:server.host:' \\
    '--server.port[]:server.port:_numbers' \\
    '--server.ratio[]:server.ratio:_numbers -f' \\
    '--one.two.three[]:one.two.three:' \\
    '--a.b.c.d.e.value[]:a.b.c.d.e.value:' \\
    '1:format:(json yaml)' \\
    '2::level:(debug info)' \\
    '3::level:(debug info)' \\
    '4::level:(debug info)' \\
    '*::argument:'
  case \$state in
  esac
}

_spec_config() {
  local -a words
  words=("\${words[@]:2}")
  (( CURRENT -= 1 ))
  case "\$words[2]" in
    set|s)
      _spec_config_set
      return
      ;;
  esac
  local context state state_descr line
  typeset -A opt_args
  if (( \${words[(I:--)]} )); then
    :
    return
  fi
  _arguments -S \\
    '{-h,--help}[Show this help message.]' \\
    '1:command:->command' \\
    '*::argument:'
  case \$state in
    command)
      local -a commands
      commands=(
        'set:Set configuration.'
        's:Alias for set'
      )
      _describe 'command' commands
      ;;
  esac
}

_spec() {
  case "\$words[2]" in
    config)
      _spec_config
      return
      ;;
  esac
  local context state state_descr line
  typeset -A opt_args
  if (( \${words[(I:--)]} )); then
    :
    return
  fi
  _arguments -S \\
    '{-h,--help}[Show this help message.]' \\
    '1:command:->command' \\
    '*::argument:'
  case \$state in
    command)
      local -a commands
      commands=(
        'config:Configure the application.'
      )
      _describe 'command' commands
      ;;
  esac
}

compdef _spec spec
'''),
      );
    });

    for (final testCase in [
      (
        'emits the compdef header and registration',
        () => rootCompletion(),
        allOf(startsWith('#compdef spec'), endsWith('compdef _spec spec\n')),
      ),
      (
        'groups short and long Boolean flags',
        () => rootCompletion(flags: [BooleanFlag('force', short: 'f')]),
        contains("'{-f,--force}[]'"),
      ),
      (
        'marks count flags repeatable',
        () => rootCompletion(flags: [CountFlag('verbose')]),
        contains("'*--verbose[]'"),
      ),
      (
        'omits hidden flags',
        () => rootCompletion(flags: [BooleanFlag('secret', hidden: true)]),
        isNot(contains('--secret')),
      ),
      (
        'renders string option value slots',
        () => rootCompletion(options: [StringOption('name')]),
        contains("'--name[]:name:'"),
      ),
      (
        'renders integer option numeric completion',
        () => rootCompletion(options: [IntOption('retries')]),
        contains('_numbers'),
      ),
      (
        'renders double option numeric completion',
        () => rootCompletion(options: [DoubleOption('ratio')]),
        contains('_numbers -f'),
      ),
      (
        'renders integer minimum and maximum bounds',
        () => rootCompletion(options: [IntOption('retries', min: 1, max: 10)]),
        contains('_numbers -l 1 -m 10'),
      ),
      (
        'renders double minimum and maximum bounds',
        () =>
            rootCompletion(options: [DoubleOption('ratio', min: .1, max: .9)]),
        contains('_numbers -f -l 0.1 -m 0.9'),
      ),
      (
        'renders stepped double values',
        () => rootCompletion(
          options: [DoubleOption('ratio', min: 0, max: 0.3, step: 0.1)],
        ),
        contains("'--ratio[]:ratio:(0.0 0.1 0.2 0.3)'"),
      ),
      (
        'marks repeatable options',
        () => rootCompletion(options: [RepeatableStringOption('tag')]),
        contains("'*--tag[]:tag:'"),
      ),
      (
        'renders choice option values',
        () => rootCompletion(
          options: [ChoiceOption<_Format>('format', choices: _Format.values)],
        ),
        contains('(json yaml)'),
      ),
      (
        'omits hidden options',
        () => rootCompletion(options: [StringOption('secret', hidden: true)]),
        isNot(contains('--secret')),
      ),
      (
        'renders command descriptions using their first line',
        () => rootCompletion(
          commands: [
            TestCommand(
              'serve',
              'Serve requests.',
              longDescription: 'Details.',
            ),
          ],
        ),
        allOf(contains("'serve:Serve requests.'"), isNot(contains('Details.'))),
      ),
      (
        'publishes command candidates through _describe',
        () =>
            rootCompletion(commands: [TestCommand('serve', 'Serve requests.')]),
        contains("_describe 'command' commands"),
      ),
      (
        'publishes aliases and dispatches them to canonical handlers',
        () => rootCompletion(
          commands: [
            TestCommand('serve', 'Serve requests.', aliases: ['s']),
          ],
        ),
        allOf(contains("'s:Alias for serve'"), contains('serve|s)')),
      ),
      (
        'inherits root inputs in descendant handlers',
        () => rootCompletion(
          flags: [BooleanFlag('global')],
          options: [StringOption('profile')],
          commands: [TestCommand('serve', 'Serve requests.')],
        ),
        allOf(
          contains('_spec_serve()'),
          contains("'--global[]'"),
          contains("'--profile[]:profile:'"),
        ),
      ),
      (
        'flattens accessor leaves',
        () => convertZsh(
          specRegistry(
            commands: [
              TestCommand(
                'serve',
                'Serve requests.',
                accessors: [
                  AccessorListOption(
                    'database',
                    options: [
                      AccessorListOption(
                        'pool',
                        options: [AccessorIntOption('size')],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ).toMap(),
        ),
        contains("'--database.pool.size[]:database.pool.size:_numbers'"),
      ),
      (
        'omits leaves in hidden accessor groups',
        () => convertZsh(
          RegistryMap({
            'name': 'spec',
            'description': 'spec command',
            'accessors': {
              'database': {
                'kind': 'group',
                'hidden': true,
                'description': null,
                'options': {
                  'url': {
                    'kind': 'value',
                    'description': null,
                    'valueType': 'string',
                  },
                },
              },
            },
          }),
        ),
        isNot(contains('--database.url')),
      ),
      (
        'renders negatable Boolean flags',
        () => rootCompletion(flags: [BooleanFlag('color', negatable: true)]),
        contains("'--no-color[]'"),
      ),
      (
        'groups short and long option spellings',
        () => rootCompletion(options: [StringOption('name', short: 'n')]),
        contains("'{-n,--name}[]:name:'"),
      ),
      (
        'creates nested handlers before dispatching to them',
        () => rootCompletion(
          commands: [
            TestGroupCommand('config', [
              TestCommand('set', 'Set configuration.'),
            ], 'Configure.'),
          ],
        ),
        contains('_spec_config_set()'),
      ),
      (
        'creates handlers through multiple nested groups',
        () {
          final completion = rootCompletion(
            commands: [
              TestGroupCommand('config', [
                TestGroupCommand('remote', [
                  TestCommand('set', 'Set a remote.'),
                ], 'Manage remotes.'),
              ], 'Configure.'),
            ],
          );
          return completion;
        },
        equals(r'''#compdef spec

_spec_config_remote_set() {
  local -a words
  words=("${words[@]:2}")
  (( CURRENT -= 1 ))
  local context state state_descr line
  typeset -A opt_args
  if (( ${words[(I:--)]} )); then
    :
    return
  fi
  _arguments -S \
    '{-h,--help}[Show this help message.]' \
    '*::argument:'
  case $state in
  esac
}

_spec_config_remote() {
  local -a words
  words=("${words[@]:2}")
  (( CURRENT -= 1 ))
  case "$words[2]" in
    set)
      _spec_config_remote_set
      return
      ;;
  esac
  local context state state_descr line
  typeset -A opt_args
  if (( ${words[(I:--)]} )); then
    :
    return
  fi
  _arguments -S \
    '{-h,--help}[Show this help message.]' \
    '1:command:->command' \
    '*::argument:'
  case $state in
    command)
      local -a commands
      commands=(
        'set:Set a remote.'
      )
      _describe 'command' commands
      ;;
  esac
}

_spec_config() {
  local -a words
  words=("${words[@]:2}")
  (( CURRENT -= 1 ))
  case "$words[2]" in
    remote)
      _spec_config_remote
      return
      ;;
  esac
  local context state state_descr line
  typeset -A opt_args
  if (( ${words[(I:--)]} )); then
    :
    return
  fi
  _arguments -S \
    '{-h,--help}[Show this help message.]' \
    '1:command:->command' \
    '*::argument:'
  case $state in
    command)
      local -a commands
      commands=(
        'remote:Manage remotes.'
      )
      _describe 'command' commands
      ;;
  esac
}

_spec() {
  case "$words[2]" in
    config)
      _spec_config
      return
      ;;
  esac
  local context state state_descr line
  typeset -A opt_args
  if (( ${words[(I:--)]} )); then
    :
    return
  fi
  _arguments -S \
    '{-h,--help}[Show this help message.]' \
    '1:command:->command' \
    '*::argument:'
  case $state in
    command)
      local -a commands
      commands=(
        'config:Configure.'
      )
      _describe 'command' commands
      ;;
  esac
}

compdef _spec spec
'''),
      ),
      (
        'expands repeated positional choice slots',
        () => convertZsh(
          specRegistry(
            mandatoryPositionals: [
              RepeatedChoicePositional<_Level>(
                'level',
                choices: _Level.values,
                times: 2,
              ),
            ],
          ).toMap(),
        ),
        allOf(
          contains("'1:level:(debug info)'"),
          contains("'3::level:(debug info)'"),
        ),
      ),
      (
        'offers variadic choices only after the separator',
        () => convertZsh(
          specRegistry(
            variadic: RepeatedChoiceVariadic<_Sku>(
              'extra',
              choices: _Sku.values,
            ),
          ).toMap(),
        ),
        allOf(
          contains(r'if (( ${words[(I:--)]} )); then'),
          contains("_values 'value' 'basic' 'standard'"),
        ),
      ),
    ]) {
      test(testCase.$1, () => expect(testCase.$2(), testCase.$3));
    }
  });
  group('ToBashCompletionConverter', () {
    test(
      'completes commands through multiple nested groups at runtime',
      () async {
        final completion = convertBash(
          specRegistry(
            commands: [
              TestGroupCommand('config', [
                TestGroupCommand('remote', [
                  TestCommand('set', 'Set a remote.'),
                ], 'Manage remotes.'),
              ], 'Configure.'),
            ],
          ).toMap(),
        );

        expect(
          await completeBash(completion, ['spec', 'config', 'remote', '']),
          ['set'],
        );
      },
    );

    test('keeps an exact command candidate before it is accepted', () async {
      final completion = convertBash(
        specRegistry(
          commands: [
            TestGroupCommand('config', [
              TestCommand('set', 'Set configuration.'),
            ], 'Configure.'),
          ],
        ).toMap(),
      );

      expect(await completeBash(completion, ['spec', 'config']), ['config']);
    });

    test('does not resolve an option value as a command at runtime', () async {
      final completion = convertBash(
        specRegistry(
          options: [StringOption('target')],
          commands: [TestCommand('deploy', 'Deploy the application.')],
        ).toMap(),
      );

      expect(
        await completeBash(completion, ['spec', '--target', 'deploy', '']),
        contains('deploy'),
      );
    });

    test('completes a root option value at a nested command', () async {
      final completion = convertBash(
        specRegistry(
          options: [ChoiceOption<_Format>('format', choices: _Format.values)],
          commands: [
            TestGroupCommand('config', [
              TestCommand('set', 'Set configuration.'),
            ], 'Configure.'),
          ],
        ).toMap(),
      );

      expect(
        await completeBash(completion, [
          'spec',
          'config',
          'set',
          '--format',
          '',
        ]),
        ['json', 'yaml'],
      );
    });

    test('completes a positional at a nested command', () async {
      final completion = convertBash(
        specRegistry(
          commands: [
            TestGroupCommand('config', [
              TestCommand(
                'set',
                'Set configuration.',
                mandatoryPositionals: [
                  ChoicePositional<_Level>('level', choices: _Level.values),
                ],
              ),
            ], 'Configure.'),
          ],
        ).toMap(),
      );

      expect(await completeBash(completion, ['spec', 'config', 'set', '']), [
        'debug',
        'info',
      ]);
    });

    test('completes root flags at five nested command levels', () async {
      final completion = convertBash(
        nestedRegistry(5, flags: [BooleanFlag('force')]).toMap(),
      );

      expect(
        await completeBash(completion, [
          'spec',
          'alpha',
          'beta',
          'gamma',
          'delta',
          'leaf',
          '--f',
        ]),
        ['--force'],
      );
    });

    test('completes a group-persistent option at a nested leaf', () async {
      final completion = convertBash(
        specRegistry(
          commands: [
            TestGroupCommand(
              'config',
              [TestCommand('set', 'Set configuration.')],
              'Configure.',
              inheritedOptions: [
                ChoiceOption<_Format>('format', choices: _Format.values),
              ],
            ),
          ],
        ).toMap(),
      );

      expect(
        await completeBash(completion, [
          'spec',
          'config',
          'set',
          '--format',
          '',
        ]),
        ['json', 'yaml'],
      );
    });

    test('emits routing data and handlers for multiple nested groups', () {
      final completion = convertBash(
        specRegistry(
          commands: [
            TestGroupCommand('config', [
              TestGroupCommand('remote', [
                TestCommand(
                  'set',
                  'Set a remote.',
                  flags: [BooleanFlag('force')],
                ),
              ], 'Manage remotes.'),
            ], 'Configure.'),
          ],
        ).toMap(),
      );

      expect(
        completion,
        allOf([
          contains("['spec|config']='_spec_config_completion'"),
          contains("['spec_config|remote']='_spec_config_remote_completion'"),
          contains(
            "['spec_config_remote|set']="
            "'_spec_config_remote_set_completion'",
          ),
          contains('_spec_config_remote_set_completion()'),
          contains('_spec_root_completion()'),
          endsWith('complete -F _spec_completion spec\n'),
        ]),
      );
    });
    test('places root flags and typed options in reusable global tables', () {
      final completion = convertBash(
        specRegistry(
          flags: [
            BooleanFlag('force', short: 'f'),
            BooleanFlag('color', negatable: true),
            CountFlag('verbose'),
          ],
          options: [
            StringOption('name', short: 'n'),
            IntOption('retries'),
            DoubleOption('ratio'),
            RepeatableStringOption('include'),
            RepeatableIntOption('attempt'),
            RepeatableDoubleOption('weight'),
            ChoiceOption<_Format>('format', choices: _Format.values),
          ],
        ).toMap(),
      );

      expect(
        completion,
        allOf([
          contains('_spec_flags=('),
          contains("  '-f'"),
          contains("  '--force'"),
          contains("  '--no-color'"),
          contains("['--name']='_spec_name_values'"),
          contains("['-n']='_spec_name_values'"),
          contains("['--format']='_spec_format_values'"),
          contains("['spec|--format']=1"),
          contains("  'json'"),
          contains("  'yaml'"),
          contains('_spec_root_completion()'),
          endsWith('complete -F _spec_completion spec\n'),
        ]),
      );
    });
    test('creates nested handlers and alias routes', () {
      final completion = convertBash(
        specRegistry(
          commands: [
            TestGroupCommand('config', [
              TestCommand(
                'set',
                'Set configuration.',
                aliases: ['s'],
                flags: [
                  BooleanFlag('force', short: 'f'),
                  BooleanFlag('color', negatable: true),
                  CountFlag('verbose'),
                ],
                options: [
                  StringOption('name', short: 'n'),
                  IntOption('retries'),
                  DoubleOption('ratio'),
                  RepeatableStringOption('include'),
                  RepeatableIntOption('attempt'),
                  RepeatableDoubleOption('weight'),
                  ChoiceOption<_Format>('format', choices: _Format.values),
                ],
                mandatoryPositionals: [
                  ChoicePositional<_Level>('level', choices: _Level.values),
                ],
                discretionaryPositionals: [
                  RepeatedChoicePositional<_Sku>(
                    'sku',
                    choices: _Sku.values,
                    times: 2,
                  ),
                ],
                variadic: RepeatedChoiceVariadic<_Format>(
                  'extra',
                  choices: _Format.values,
                ),
                accessors: [
                  AccessorListOption(
                    'server',
                    options: [
                      AccessorStringOption('host'),
                      AccessorIntOption('port'),
                      AccessorDoubleOption('ratio'),
                    ],
                  ),
                  AccessorListOption(
                    'profile',
                    options: [
                      AccessorListOption(
                        'cloud',
                        options: [
                          AccessorListOption(
                            'credentials',
                            options: [
                              AccessorChoiceOption<_Format>(
                                'format',
                                choices: _Format.values,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  AccessorListOption(
                    'database',
                    options: [AccessorStringOption('url')],
                  ),
                ],
              ),
            ], 'Configure the application.'),
          ],
        ).toMap(),
      );

      expect(
        completion,
        allOf([
          contains('_spec_config_set_completion()'),
          contains('_spec_config_completion()'),
          contains("['spec_config|s']='_spec_config_set_completion'"),
          contains('_spec_config_set_server_host_values=('),
          contains("['--server.host']='_spec_config_set_server_host_values'"),
          contains(
            "['--profile.cloud.credentials.format']='_spec_config_set_profile_cloud_credentials_format_values'",
          ),
          contains('0)'),
          contains('1|2|3)'),
          contains("_mamba_filter \"\$current\" 'debug' 'info'"),
          contains("_mamba_filter \"\$current\" 'basic' 'standard'"),
          endsWith('complete -F _spec_completion spec\n'),
        ]),
      );
    });

    test('lists only visible short inputs for a short prefix', () {
      final completion = convertBash(
        specRegistry(
          flags: [
            BooleanFlag('force', short: 'f'),
            BooleanFlag('secret', short: 's', hidden: true),
          ],
        ).toMap(),
      );

      expect(completion, contains("  '-f'"));
      expect(completion, isNot(contains("  '-s'")));
    });

    test('lists visible long inputs for a long prefix', () {
      final completion = convertBash(
        specRegistry(flags: [BooleanFlag('force')]).toMap(),
      );

      expect(completion, contains("  '--force'"));
      expect(completion, contains('case "\$current" in\n    -*)'));
    });

    test('emits the negated spelling only for negatable flags', () {
      final completion = convertBash(
        specRegistry(
          flags: [BooleanFlag('color', negatable: true), BooleanFlag('force')],
        ).toMap(),
      );

      expect(completion, contains("  '--no-color'"));
      expect(completion, isNot(contains('--no-force')));
    });

    test('routes every command alias through its canonical handler', () async {
      final completion = convertBash(
        specRegistry(
          commands: [
            TestCommand('commit', 'Commit changes.', aliases: ['ci']),
          ],
        ).toMap(),
      );

      expect(await completeBash(completion, ['spec', 'ci', '--h']), ['--help']);
    });

    test('records option values separately from command routes', () {
      final completion = convertBash(
        specRegistry(
          options: [ChoiceOption<_Format>('format', choices: _Format.values)],
          commands: [TestCommand('json', 'Print JSON.')],
        ).toMap(),
      );

      expect(completion, contains("['spec|--format']=1"));
      expect(completion, contains("['spec|json']='_spec_json_completion'"));
    });

    test('maps choice options to their finite value array', () {
      final completion = convertBash(
        specRegistry(
          options: [ChoiceOption<_Format>('format', choices: _Format.values)],
        ).toMap(),
      );

      expect(completion, contains("['--format']='_spec_format_values'"));
      expect(completion, contains("  'json'"));
      expect(completion, contains("  'yaml'"));
    });

    test('does not invent values for a negative integer option', () {
      final completion = convertBash(
        specRegistry(options: [IntOption('offset')]).toMap(),
      );

      expect(completion, contains('_spec_offset_values=(\n)'));
      expect(completion, isNot(contains('_mamba_integer_range')));
    });

    test('does not invent a finite completion list for double bounds', () {
      final completion = convertBash(
        specRegistry(
          options: [DoubleOption('ratio', min: 0.0, max: 1.0)],
        ).toMap(),
      );

      expect(completion, contains('_spec_ratio_values=(\n)'));
      expect(completion, isNot(contains("  '0.0'")));
    });

    test('enumerates stepped double values', () {
      final completion = convertBash(
        specRegistry(
          options: [DoubleOption('ratio', min: 0, max: 0.3, step: 0.1)],
        ).toMap(),
      );

      expect(
        completion,
        contains('''_spec_ratio_values=(
  '0.0'
  '0.1'
  '0.2'
  '0.3'
)'''),
      );
      expect(completion, contains('    --ratio)'));
    });

    test(
      'keeps an unconstrained positional slot before a choice positional',
      () {
        final completion = convertBash(
          specRegistry(
            mandatoryPositionals: [
              NormalPositional('path'),
              ChoicePositional<_Format>('format', choices: _Format.values),
            ],
          ).toMap(),
        );

        expect(completion, contains('    1)'));
        expect(
          completion,
          contains("_mamba_filter \"\$current\" 'json' 'yaml'"),
        );
      },
    );

    test('limits repeated positional choices to times plus one slots', () {
      final completion = convertBash(
        specRegistry(
          mandatoryPositionals: [
            RepeatedChoicePositional<_Format>(
              'format',
              choices: _Format.values,
              times: 2,
            ),
          ],
        ).toMap(),
      );

      expect(completion, contains('    0|1|2)'));
      expect(completion, isNot(contains('0|1|2|3)')));
    });

    test('keeps a completed separator ahead of other value cases', () {
      final completion = convertBash(
        specRegistry(
          options: [ChoiceOption<_Format>('format', choices: _Format.values)],
          variadic: ChoiceVariadic<_Level>('extra', choices: _Level.values),
        ).toMap(),
      );

      expect(
        completion.indexOf('    --)'),
        lessThan(completion.indexOf('    --format)')),
      );
    });

    test('emits choices for a single-value variadic', () {
      final completion = convertBash(
        specRegistry(
          variadic: ChoiceVariadic<_Format>('extra', choices: _Format.values),
        ).toMap(),
      );

      expect(completion, contains("_mamba_filter \"\$current\" 'json' 'yaml'"));
    });

    test('emits choices for a repeated variadic', () {
      final completion = convertBash(
        specRegistry(
          variadic: RepeatedChoiceVariadic<_Format>(
            'extra',
            choices: _Format.values,
          ),
        ).toMap(),
      );

      expect(completion, contains('    --)'));
      expect(completion, contains("_mamba_filter \"\$current\" 'json' 'yaml'"));
    });

    test('omits hidden inputs while retaining visible input tables', () {
      final completion = convertBash(
        specRegistry(
          flags: [BooleanFlag('internal', hidden: true)],
          options: [StringOption('token', hidden: true)],
        ).toMap(),
      );

      expect(completion, isNot(contains('--internal')));
      expect(completion, isNot(contains("['--token']")));
      expect(completion, contains("  '--help'"));
    });

    test('flattens nested accessor leaves into dotted option keys', () {
      final completion = convertBash(
        specRegistry(
          accessors: [
            AccessorListOption(
              'database',
              options: [
                AccessorListOption(
                  'connection',
                  options: [
                    AccessorChoiceOption<_Format>(
                      'format',
                      choices: _Format.values,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ).toMap(),
      );

      expect(completion, contains("['--database.connection.format']"));
      expect(completion, contains('_spec_database_connection_format_values='));
    });
  });

  group('CarapaceSpecWriter', () {
    test('writes development specs below the system temp directory', () {
      final writer = CarapaceSpecWriter(
        CarapaceSpecConverter(
          CommandRegistry.create('writer-fixture', 'writer command').toMap(),
        ),
        development: true,
      );
      final file = writer.write();
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });

      expect(file.path, startsWith(Directory.systemTemp.path));
      expect(
        file.path,
        endsWith(
          [
            'carapace',
            'specs',
            'writer-fixture.yaml',
          ].join(Platform.pathSeparator),
        ),
      );
      expect(file.readAsStringSync(), contains('name: "writer-fixture"'));
    });

    test('writes to an explicit path and creates missing directories', () {
      final directory = Directory.systemTemp.createTempSync('mamba-spec-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final path = [
        directory.path,
        'nested',
        'spec.yaml',
      ].join(Platform.pathSeparator);
      final writer = CarapaceSpecWriter(
        CarapaceSpecConverter(specRegistry().toMap()),
        development: false,
        outputPath: path,
      );

      final file = writer.write();

      expect(file.path, path);
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), contains('name: "spec"'));
    });
  });

  group('ToPowerShellCompletionConverter', () {
    test('completes a root option value at a nested command', () async {
      final completion = convertPs(
        specRegistry(
          options: [ChoiceOption<_Format>('format', choices: _Format.values)],
          commands: [
            TestGroupCommand('config', [
              TestCommand('set', 'Set configuration.'),
            ], 'Configure.'),
          ],
        ).toMap(),
      );

      expect(
        await completePowerShell(completion, 'spec config set --format '),
        ['json', 'yaml'],
      );
    });

    test('completes root flags at five nested command levels', () async {
      final completion = convertPs(
        nestedRegistry(5, flags: [BooleanFlag('force')]).toMap(),
      );

      expect(
        await completePowerShell(
          completion,
          'spec alpha beta gamma delta leaf --f',
        ),
        ['--force'],
      );
    });

    test(
      'places root flags and typed options in a complete PowerShell script',
      () {
        final completion = convertPs(
          specRegistry(
            flags: [
              BooleanFlag('force', short: 'f'),
              BooleanFlag('color', negatable: true),
              CountFlag('verbose'),
            ],
            options: [
              StringOption('name', short: 'n'),
              IntOption('retries'),
              DoubleOption('ratio'),
              RepeatableStringOption('include'),
              RepeatableIntOption('attempt'),
              RepeatableDoubleOption('weight'),
              ChoiceOption<_Format>('format', choices: _Format.values),
            ],
          ).toMap(),
        );

        expect(
          completion,
          equals(r'''<#
 PowerShell completion for spec.
 Generated; do not edit by hand.

 spec command
#>
$script:MambaNativeCommands = @{
    'root' = 'root'
}

$script:MambaInputs = @{}
$script:MambaChildren = @{}
$script:MambaPositionalSlots = @{}
$script:MambaValueHandlers = @{}
$script:MambaVariadicHandlers = @{}

$script:MambaInputs['root'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '--force'; Description = $null; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-f'; Description = $null; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--color'; Description = $null; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--no-color'; Description = $null; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--verbose'; Description = $null; IsFlag = $true; IsCount = $true; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--name'; Description = $null; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '-n'; Description = $null; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--retries'; Description = $null; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--ratio'; Description = $null; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--format'; Description = $null; IsFlag = $false; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--include'; Description = $null; IsFlag = $false; IsCount = $false; IsRepeatable = $true; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--attempt'; Description = $null; IsFlag = $false; IsCount = $false; IsRepeatable = $true; IsAccessor = $false; IsHelp = $false }
    [PSCustomObject]@{ Spelling = '--weight'; Description = $null; IsFlag = $false; IsCount = $false; IsRepeatable = $true; IsAccessor = $false; IsHelp = $false }
    )
$script:MambaChildren['root'] = @(
    )
$script:MambaPositionalSlots['root'] = @{}
$script:MambaValueHandlers['root.--format'] = @('json', 'yaml')
function Update-MambaStateObject {
    param(
        [Parameter(Mandatory)][int]$CursorPosition,
        [Parameter(Mandatory)]$Element
    )
    $extent = $Element.Extent
    if ($null -eq $extent) { return $false }
    if ($extent.StartOffset -ge $CursorPosition) { return $false }
    if ($extent.EndOffset -gt $CursorPosition) { return $false }
    return $true
}

function Find-MambaInput {
    param(
        [Parameter(Mandatory)][string]$PathKey,
        [Parameter(Mandatory)][string]$Spelling
    )
    $inputs = $script:MambaInputs[$PathKey]
    if ($null -eq $inputs) { return $null }
    foreach ($input in $inputs) {
        if ($input.Spelling -ceq $Spelling) { return $input }
    }
    return $null
}

function Resolve-MambaState {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$WordToComplete,
        [Parameter(Mandatory)][int]$CursorPosition,
        [Parameter(Mandatory)]$CommandAst
    )
    $resolved = @('root')
    $pendingValueOwner = $null
    $afterDoubleDash = $false
    $positionalIndex = -1
    $usedNonRepeatable = @{}
    $elements = @($CommandAst.CommandElements)
    for ($i = 1; $i -lt $elements.Count; $i++) {
        $el = $elements[$i]
        if (-not (Update-MambaStateObject -CursorPosition $CursorPosition -Element $el)) { continue }
        $isLastElement = ($i -eq $elements.Count - 1)
        $tokenText = $el.Extent.Text
        # The last AST element is the completion word only while the cursor
        # is inside it or immediately after it; a trailing space means the
        # last element has already been supplied.
        $isWord = $isLastElement -and ($el.Extent.EndOffset -ge $CursorPosition)

        if ($isWord) { continue }

        # A value belongs to the preceding option even when it looks like a
        # command, another option, or the variadic separator.
        if ($null -ne $pendingValueOwner) {
            $usedNonRepeatable[$pendingValueOwner] = $true
            $pendingValueOwner = $null
            continue
        }

        if ($afterDoubleDash) {
            $positionalIndex = $positionalIndex + 1
            continue
        }

        if ($tokenText -eq '--') {
            $afterDoubleDash = $true
            continue
        }

        $pathKey = $resolved -join '.'
        $children = @($script:MambaChildren[$pathKey])
        $canonical = $null
        foreach ($child in $children) {
            if ($child.Name -ceq $tokenText) {
                $canonical = $script:MambaNativeCommands[$child.Name]
                break
            }
        }
        if ($null -ne $canonical) {
            $resolved += ,$canonical
            $pendingValueOwner = $null
            continue
        }

        if ($tokenText.StartsWith('--', [System.StringComparison]::Ordinal) -and $tokenText.Length -gt 2) {
            $tail = $tokenText.Substring(2)
            if ($tail.Contains('=')) {
                $eqIndex = $tail.IndexOf('=')
                $owner = '--' + $tail.Substring(0, $eqIndex)
                $input = Find-MambaInput -PathKey $pathKey -Spelling $owner
                if ($null -ne $input -and -not $input.IsFlag) {
                    $usedNonRepeatable[$owner] = $true
                }
                continue
            }
            $input = Find-MambaInput -PathKey $pathKey -Spelling $tokenText
            if ($null -ne $input -and -not $input.IsFlag) {
                $pendingValueOwner = $tokenText
                continue
            }
            $usedNonRepeatable[$tokenText] = $true
            $pendingValueOwner = $null
            continue
        }

        if ($tokenText.StartsWith('-', [System.StringComparison]::Ordinal) -and $tokenText.Length -gt 1) {
            $input = Find-MambaInput -PathKey $pathKey -Spelling $tokenText
            if ($null -ne $input -and -not $input.IsFlag) {
                $pendingValueOwner = $tokenText
                continue
            }
            $usedNonRepeatable[$tokenText] = $true
            continue
        }

        $positionalIndex = $positionalIndex + 1
    }

    return [PSCustomObject]@{
        ResolvedPath = $resolved
        PendingValueOwner = $pendingValueOwner
        AfterDoubleDash = $afterDoubleDash
        PositionalIndex = $positionalIndex
        UsedNonRepeatable = $usedNonRepeatable
        WordToComplete = $WordToComplete
    }
}

function Write-MambaCompletionResult {
    param(
        [Parameter(Mandatory)][string]$CompletionText,
        [Parameter(Mandatory)][string]$ListItemText,
        [Parameter(Mandatory)][string]$ResultType,
        [string]$Description
    )
    if ([string]::IsNullOrEmpty($Description)) { $Description = ' ' }
    [System.Management.Automation.CompletionResult]::new(
        $CompletionText,
        $ListItemText,
        $ResultType,
        $Description
    ) | Write-Output
}
Register-ArgumentCompleter -Native -CommandName 'spec' -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    try {
        $state = Resolve-MambaState -WordToComplete $wordToComplete -CursorPosition $cursorPosition -CommandAst $commandAst
    } catch { return }
    try {
        $pathKey = ($state.ResolvedPath -join '.')
        if ($state.AfterDoubleDash) {
            $handler = $script:MambaVariadicHandlers[$pathKey]
            if ($null -eq $handler) { return }
            $emit = $handler.Repeatable -or ($state.PositionalIndex -lt 0)
            if (-not $emit) { return }
            foreach ($choice in $handler.Choices) {
                if ($choice.StartsWith($wordToComplete, [System.StringComparison]::Ordinal)) {
                    Write-MambaCompletionResult -CompletionText $choice -ListItemText $choice -ResultType 'ParameterValue' -Description ''
                }
            }
            return
        }
        if ($null -ne $state.PendingValueOwner) {
            $handler = $script:MambaValueHandlers["$pathKey.$($state.PendingValueOwner)"]
            if ($null -ne $handler) {
                foreach ($choice in $handler) {
                    if ($choice.StartsWith($wordToComplete, [System.StringComparison]::Ordinal)) {
                        Write-MambaCompletionResult -CompletionText $choice -ListItemText $choice -ResultType 'ParameterValue' -Description ''
                    }
                }
            }
            return
        }
        $inputs = $script:MambaInputs[$pathKey]
        $currentWord = $state.WordToComplete
        $wantLong = $currentWord.StartsWith('--', [System.StringComparison]::Ordinal)
        $wantShort = (-not $wantLong) -and $currentWord.StartsWith('-', [System.StringComparison]::Ordinal)
        if ($null -ne $inputs) {
            foreach ($input in $inputs) {
                $spelling = $input.Spelling
                if ($wantLong -and -not $spelling.StartsWith('--', [System.StringComparison]::Ordinal)) { continue }
                if ($wantShort -and (-not $spelling.StartsWith('-', [System.StringComparison]::Ordinal) -or $spelling.StartsWith('--', [System.StringComparison]::Ordinal))) { continue }
                if (-not $spelling.StartsWith($currentWord, [System.StringComparison]::Ordinal)) { continue }
                if (-not $input.IsFlag -and -not $input.IsRepeatable -and -not $input.IsAccessor -and -not $input.IsHelp) {
                    if ($state.UsedNonRepeatable.ContainsKey($spelling)) { continue }
                }
                Write-MambaCompletionResult -CompletionText $spelling -ListItemText $spelling -ResultType 'ParameterName' -Description $input.Description
            }
        }
        if (-not $wantLong -and -not $wantShort) {
            $commands = $script:MambaChildren[$pathKey]
            if ($null -ne $commands) {
                foreach ($command in $commands) {
                    if ($command.Name.StartsWith($wordToComplete, [System.StringComparison]::Ordinal)) {
                        Write-MambaCompletionResult -CompletionText $command.Name -ListItemText $command.Name -ResultType 'Command' -Description $command.Description
                    }
                }
            }
            $positionals = $script:MambaPositionalSlots[$pathKey]
            if ($null -ne $positionals) {
                $entry = $positionals[($state.PositionalIndex + 1)]
                if ($null -ne $entry) {
                    foreach ($choice in $entry.Choices) {
                        if ($choice.StartsWith($wordToComplete, [System.StringComparison]::Ordinal)) {
                            Write-MambaCompletionResult -CompletionText $choice -ListItemText $choice -ResultType 'ParameterValue' -Description $entry.Description
                        }
                    }
                }
            }
        }
    } catch { }
}
'''),
        );
      },
    );

    test('routes every command alias through the global command-name map', () {
      final completion = convertPs(
        specRegistry(
          commands: [
            TestCommand('commit', 'Commit changes.', aliases: ['ci']),
          ],
        ).toMap(),
      );

      expect(completion, contains(r"'commit' = 'commit'"));
      expect(completion, contains(r"'ci' = 'commit'"));
      expect(completion, contains(r"Name = 'commit'"));
      expect(completion, contains(r"Name = 'ci'"));
    });

    test(
      'emits children tables at every nested path with command candidates',
      () {
        final completion = convertPs(
          specRegistry(
            commands: [
              TestGroupCommand('config', [
                TestCommand('set', 'Set configuration.', aliases: ['s']),
              ], 'Configure.'),
            ],
          ).toMap(),
        );

        expect(completion, contains(r"$script:MambaChildren['root']"));
        expect(completion, contains(r"$script:MambaChildren['root.config']"));
        expect(completion, contains(r"Name = 'config'"));
        expect(completion, contains(r"Name = 'set'"));
        expect(completion, contains(r"Name = 's'"));
      },
    );

    test('emits tables through multiple nested groups', () {
      final completion = convertPs(
        specRegistry(
          commands: [
            TestGroupCommand('config', [
              TestGroupCommand('remote', [
                TestCommand(
                  'set',
                  'Set a remote.',
                  flags: [BooleanFlag('force')],
                ),
              ], 'Manage remotes.'),
            ], 'Configure.'),
          ],
        ).toMap(),
      );

      expect(
        completion,
        equals(r'''<#
 PowerShell completion for spec.
 Generated; do not edit by hand.

 spec command
#>
$script:MambaNativeCommands = @{
    'root' = 'root'
    'config' = 'config'
    'remote' = 'remote'
    'set' = 'set'
}

$script:MambaInputs = @{}
$script:MambaChildren = @{}
$script:MambaPositionalSlots = @{}
$script:MambaValueHandlers = @{}
$script:MambaVariadicHandlers = @{}

$script:MambaInputs['root'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    )
$script:MambaChildren['root'] = @(
    [PSCustomObject]@{ Name = 'config'; Description = 'Configure.' }
    )
$script:MambaPositionalSlots['root'] = @{}
$script:MambaInputs['root.config'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    )
$script:MambaChildren['root.config'] = @(
    [PSCustomObject]@{ Name = 'remote'; Description = 'Manage remotes.' }
    )
$script:MambaPositionalSlots['root.config'] = @{}
$script:MambaInputs['root.config.remote'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    )
$script:MambaChildren['root.config.remote'] = @(
    [PSCustomObject]@{ Name = 'set'; Description = 'Set a remote.' }
    )
$script:MambaPositionalSlots['root.config.remote'] = @{}
$script:MambaInputs['root.config.remote.set'] = @(
    [PSCustomObject]@{ Spelling = '--help'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '-h'; Description = 'Show this help message.'; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $true }
    [PSCustomObject]@{ Spelling = '--force'; Description = $null; IsFlag = $true; IsCount = $false; IsRepeatable = $false; IsAccessor = $false; IsHelp = $false }
    )
$script:MambaChildren['root.config.remote.set'] = @(
    )
$script:MambaPositionalSlots['root.config.remote.set'] = @{}
function Update-MambaStateObject {
    param(
        [Parameter(Mandatory)][int]$CursorPosition,
        [Parameter(Mandatory)]$Element
    )
    $extent = $Element.Extent
    if ($null -eq $extent) { return $false }
    if ($extent.StartOffset -ge $CursorPosition) { return $false }
    if ($extent.EndOffset -gt $CursorPosition) { return $false }
    return $true
}

function Find-MambaInput {
    param(
        [Parameter(Mandatory)][string]$PathKey,
        [Parameter(Mandatory)][string]$Spelling
    )
    $inputs = $script:MambaInputs[$PathKey]
    if ($null -eq $inputs) { return $null }
    foreach ($input in $inputs) {
        if ($input.Spelling -ceq $Spelling) { return $input }
    }
    return $null
}

function Resolve-MambaState {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$WordToComplete,
        [Parameter(Mandatory)][int]$CursorPosition,
        [Parameter(Mandatory)]$CommandAst
    )
    $resolved = @('root')
    $pendingValueOwner = $null
    $afterDoubleDash = $false
    $positionalIndex = -1
    $usedNonRepeatable = @{}
    $elements = @($CommandAst.CommandElements)
    for ($i = 1; $i -lt $elements.Count; $i++) {
        $el = $elements[$i]
        if (-not (Update-MambaStateObject -CursorPosition $CursorPosition -Element $el)) { continue }
        $isLastElement = ($i -eq $elements.Count - 1)
        $tokenText = $el.Extent.Text
        # The last AST element is the completion word only while the cursor
        # is inside it or immediately after it; a trailing space means the
        # last element has already been supplied.
        $isWord = $isLastElement -and ($el.Extent.EndOffset -ge $CursorPosition)

        if ($isWord) { continue }

        # A value belongs to the preceding option even when it looks like a
        # command, another option, or the variadic separator.
        if ($null -ne $pendingValueOwner) {
            $usedNonRepeatable[$pendingValueOwner] = $true
            $pendingValueOwner = $null
            continue
        }

        if ($afterDoubleDash) {
            $positionalIndex = $positionalIndex + 1
            continue
        }

        if ($tokenText -eq '--') {
            $afterDoubleDash = $true
            continue
        }

        $pathKey = $resolved -join '.'
        $children = @($script:MambaChildren[$pathKey])
        $canonical = $null
        foreach ($child in $children) {
            if ($child.Name -ceq $tokenText) {
                $canonical = $script:MambaNativeCommands[$child.Name]
                break
            }
        }
        if ($null -ne $canonical) {
            $resolved += ,$canonical
            $pendingValueOwner = $null
            continue
        }

        if ($tokenText.StartsWith('--', [System.StringComparison]::Ordinal) -and $tokenText.Length -gt 2) {
            $tail = $tokenText.Substring(2)
            if ($tail.Contains('=')) {
                $eqIndex = $tail.IndexOf('=')
                $owner = '--' + $tail.Substring(0, $eqIndex)
                $input = Find-MambaInput -PathKey $pathKey -Spelling $owner
                if ($null -ne $input -and -not $input.IsFlag) {
                    $usedNonRepeatable[$owner] = $true
                }
                continue
            }
            $input = Find-MambaInput -PathKey $pathKey -Spelling $tokenText
            if ($null -ne $input -and -not $input.IsFlag) {
                $pendingValueOwner = $tokenText
                continue
            }
            $usedNonRepeatable[$tokenText] = $true
            $pendingValueOwner = $null
            continue
        }

        if ($tokenText.StartsWith('-', [System.StringComparison]::Ordinal) -and $tokenText.Length -gt 1) {
            $input = Find-MambaInput -PathKey $pathKey -Spelling $tokenText
            if ($null -ne $input -and -not $input.IsFlag) {
                $pendingValueOwner = $tokenText
                continue
            }
            $usedNonRepeatable[$tokenText] = $true
            continue
        }

        $positionalIndex = $positionalIndex + 1
    }

    return [PSCustomObject]@{
        ResolvedPath = $resolved
        PendingValueOwner = $pendingValueOwner
        AfterDoubleDash = $afterDoubleDash
        PositionalIndex = $positionalIndex
        UsedNonRepeatable = $usedNonRepeatable
        WordToComplete = $WordToComplete
    }
}

function Write-MambaCompletionResult {
    param(
        [Parameter(Mandatory)][string]$CompletionText,
        [Parameter(Mandatory)][string]$ListItemText,
        [Parameter(Mandatory)][string]$ResultType,
        [string]$Description
    )
    if ([string]::IsNullOrEmpty($Description)) { $Description = ' ' }
    [System.Management.Automation.CompletionResult]::new(
        $CompletionText,
        $ListItemText,
        $ResultType,
        $Description
    ) | Write-Output
}
Register-ArgumentCompleter -Native -CommandName 'spec' -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    try {
        $state = Resolve-MambaState -WordToComplete $wordToComplete -CursorPosition $cursorPosition -CommandAst $commandAst
    } catch { return }
    try {
        $pathKey = ($state.ResolvedPath -join '.')
        if ($state.AfterDoubleDash) {
            $handler = $script:MambaVariadicHandlers[$pathKey]
            if ($null -eq $handler) { return }
            $emit = $handler.Repeatable -or ($state.PositionalIndex -lt 0)
            if (-not $emit) { return }
            foreach ($choice in $handler.Choices) {
                if ($choice.StartsWith($wordToComplete, [System.StringComparison]::Ordinal)) {
                    Write-MambaCompletionResult -CompletionText $choice -ListItemText $choice -ResultType 'ParameterValue' -Description ''
                }
            }
            return
        }
        if ($null -ne $state.PendingValueOwner) {
            $handler = $script:MambaValueHandlers["$pathKey.$($state.PendingValueOwner)"]
            if ($null -ne $handler) {
                foreach ($choice in $handler) {
                    if ($choice.StartsWith($wordToComplete, [System.StringComparison]::Ordinal)) {
                        Write-MambaCompletionResult -CompletionText $choice -ListItemText $choice -ResultType 'ParameterValue' -Description ''
                    }
                }
            }
            return
        }
        $inputs = $script:MambaInputs[$pathKey]
        $currentWord = $state.WordToComplete
        $wantLong = $currentWord.StartsWith('--', [System.StringComparison]::Ordinal)
        $wantShort = (-not $wantLong) -and $currentWord.StartsWith('-', [System.StringComparison]::Ordinal)
        if ($null -ne $inputs) {
            foreach ($input in $inputs) {
                $spelling = $input.Spelling
                if ($wantLong -and -not $spelling.StartsWith('--', [System.StringComparison]::Ordinal)) { continue }
                if ($wantShort -and (-not $spelling.StartsWith('-', [System.StringComparison]::Ordinal) -or $spelling.StartsWith('--', [System.StringComparison]::Ordinal))) { continue }
                if (-not $spelling.StartsWith($currentWord, [System.StringComparison]::Ordinal)) { continue }
                if (-not $input.IsFlag -and -not $input.IsRepeatable -and -not $input.IsAccessor -and -not $input.IsHelp) {
                    if ($state.UsedNonRepeatable.ContainsKey($spelling)) { continue }
                }
                Write-MambaCompletionResult -CompletionText $spelling -ListItemText $spelling -ResultType 'ParameterName' -Description $input.Description
            }
        }
        if (-not $wantLong -and -not $wantShort) {
            $commands = $script:MambaChildren[$pathKey]
            if ($null -ne $commands) {
                foreach ($command in $commands) {
                    if ($command.Name.StartsWith($wordToComplete, [System.StringComparison]::Ordinal)) {
                        Write-MambaCompletionResult -CompletionText $command.Name -ListItemText $command.Name -ResultType 'Command' -Description $command.Description
                    }
                }
            }
            $positionals = $script:MambaPositionalSlots[$pathKey]
            if ($null -ne $positionals) {
                $entry = $positionals[($state.PositionalIndex + 1)]
                if ($null -ne $entry) {
                    foreach ($choice in $entry.Choices) {
                        if ($choice.StartsWith($wordToComplete, [System.StringComparison]::Ordinal)) {
                            Write-MambaCompletionResult -CompletionText $choice -ListItemText $choice -ResultType 'ParameterValue' -Description $entry.Description
                        }
                    }
                }
            }
        }
    } catch { }
}
'''),
      );
    });

    test('lists only visible short spellings in input rows', () {
      final completion = convertPs(
        specRegistry(
          flags: [
            BooleanFlag('force', short: 'f'),
            BooleanFlag('secret', short: 's', hidden: true),
          ],
        ).toMap(),
      );

      expect(completion, contains(r"Spelling = '-f'"));
      expect(completion, isNot(contains(r"Spelling = '-s'")));
    });

    test('emits visible options and short spellings', () {
      final completion = convertPs(
        specRegistry(
          flags: [BooleanFlag('force')],
          options: [StringOption('label', short: 'l')],
        ).toMap(),
      );

      expect(completion, contains(r"Spelling = '--force'"));
      expect(completion, contains(r"Spelling = '--label'"));
      expect(completion, contains(r"Spelling = '-l'"));
    });

    test('emits negated spelling only for negatable flags', () {
      final completion = convertPs(
        specRegistry(
          flags: [BooleanFlag('color', negatable: true), BooleanFlag('force')],
        ).toMap(),
      );

      expect(completion, contains(r"Spelling = '--no-color'"));
      expect(completion, isNot(contains(r"Spelling = '--no-force'")));
    });

    test('registers a native completer with the executable name', () {
      final completion = convertPs(specRegistry().toMap());

      expect(
        completion,
        contains(r"Register-ArgumentCompleter -Native -CommandName 'spec'"),
      );
    });

    test('emits choice option value handlers keyed by full spelling', () {
      final completion = convertPs(
        specRegistry(
          options: [ChoiceOption<_Format>('format', choices: _Format.values)],
        ).toMap(),
      );

      expect(
        completion,
        contains(r"$script:MambaValueHandlers['root.--format']"),
      );
      expect(completion, contains(r"'json'"));
      expect(completion, contains(r"'yaml'"));
    });

    test('emits short option value handlers that alias the long handler', () {
      final completion = convertPs(
        specRegistry(
          options: [
            ChoiceOption<_Format>(
              'format',
              choices: _Format.values,
              short: 'f',
            ),
          ],
        ).toMap(),
      );

      expect(completion, contains(r"$script:MambaValueHandlers['root.-f']"));
    });

    test('does not invent values for unbounded integer options', () {
      final completion = convertPs(
        specRegistry(options: [IntOption('offset')]).toMap(),
      );

      expect(
        completion,
        isNot(contains(r"$script:MambaValueHandlers['root.--offset']")),
      );
    });

    test('does not invent a finite list for doubles with min and max only', () {
      final completion = convertPs(
        specRegistry(
          options: [DoubleOption('ratio', min: 0.0, max: 1.0)],
        ).toMap(),
      );

      expect(
        completion,
        isNot(contains(r"$script:MambaValueHandlers['root.--ratio']")),
      );
    });

    test('emits every bounded integer option value through the handler', () {
      final completion = convertPs(
        specRegistry(options: [IntOption('retries', min: 1, max: 3)]).toMap(),
      );

      expect(completion, contains(r"@('1', '2', '3')"));
    });

    test('omits static values for one-sided integer ranges', () {
      final completion = convertPs(
        specRegistry(options: [IntOption('offset', min: 1)]).toMap(),
      );

      expect(
        completion,
        isNot(contains(r"$script:MambaValueHandlers['root.--offset']")),
      );
    });

    test('skips integer ranges that are too wide for static enumeration', () {
      final completion = convertPs(
        specRegistry(options: [IntOption('offset', min: 1, max: 1000)]).toMap(),
      );

      expect(
        completion,
        isNot(contains(r"$script:MambaValueHandlers['root.--offset']")),
      );
    });

    test(
      'enumerates stepped double values when the registry declares a step',
      () {
        final completion = convertPs(
          specRegistry(
            options: [DoubleOption('ratio', min: 0, max: 0.3, step: 0.1)],
          ).toMap(),
        );

        expect(completion, contains(r"@('0.0', '0.1', '0.2', '0.3')"));
      },
    );

    test(
      'keeps an unconstrained positional slot before a choice positional',
      () {
        final completion = convertPs(
          specRegistry(
            mandatoryPositionals: [
              NormalPositional('path'),
              ChoicePositional<_Format>('format', choices: _Format.values),
            ],
          ).toMap(),
        );

        expect(completion, contains(r"Choices = @('json', 'yaml')"));
        expect(completion, contains(r"1 = [PSCustomObject]@"));
      },
    );

    test('limits repeated positional choices to times plus one slots', () {
      final completion = convertPs(
        specRegistry(
          mandatoryPositionals: [
            RepeatedChoicePositional<_Format>(
              'format',
              choices: _Format.values,
              times: 2,
            ),
          ],
        ).toMap(),
      );

      expect(completion, contains(r"1 = [PSCustomObject]@"));
      expect(completion, contains(r"2 = [PSCustomObject]@"));
      expect(completion, isNot(contains(r"3 = [PSCustomObject]@")));
    });

    test('emits a variadic handler for a single-value choice variadic', () {
      final completion = convertPs(
        specRegistry(
          variadic: ChoiceVariadic<_Format>('extra', choices: _Format.values),
        ).toMap(),
      );

      expect(completion, contains(r"Choices = @('json', 'yaml')"));
      expect(completion, contains(r"Repeatable = $false"));
    });

    test('emits a variadic handler for a repeated choice variadic', () {
      final completion = convertPs(
        specRegistry(
          variadic: RepeatedChoiceVariadic<_Format>(
            'extra',
            choices: _Format.values,
          ),
        ).toMap(),
      );

      expect(completion, contains(r"Repeatable = $true"));
    });

    test('omits hidden flags while keeping visible ones', () {
      final completion = convertPs(
        specRegistry(flags: [BooleanFlag('internal', hidden: true)]).toMap(),
      );

      expect(completion, isNot(contains(r"Spelling = '--internal'")));
      expect(completion, contains(r"Spelling = '--help'"));
    });

    test('omits hidden options from input rows and value tables', () {
      final completion = convertPs(
        specRegistry(options: [StringOption('token', hidden: true)]).toMap(),
      );

      expect(completion, isNot(contains(r"Spelling = '--token'")));
      expect(
        completion,
        isNot(contains(r"$script:MambaValueHandlers['root.--token']")),
      );
    });

    test('flattens nested accessor leaves into dotted option spellings', () {
      final completion = convertPs(
        specRegistry(
          accessors: [
            AccessorListOption(
              'database',
              options: [
                AccessorListOption(
                  'connection',
                  options: [
                    AccessorChoiceOption<_Format>(
                      'format',
                      choices: _Format.values,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ).toMap(),
      );

      expect(
        completion,
        contains(r"Spelling = '--database.connection.format'"),
      );
      expect(
        completion,
        contains(
          r"$script:MambaValueHandlers['root.--database.connection.format']",
        ),
      );
    });

    test('omits every leaf under a hidden accessor group', () {
      final completion = convertPs(
        specRegistry(
          accessors: [
            AccessorListOption(
              'internal',
              hidden: true,
              options: [AccessorStringOption('token')],
            ),
          ],
        ).toMap(),
      );

      expect(completion, isNot(contains('--internal.token')));
    });

    test('emits the resolver helper and Register-ArgumentCompleter block', () {
      final completion = convertPs(specRegistry().toMap());

      expect(completion, contains('function Update-MambaStateObject'));
      expect(completion, contains('function Resolve-MambaState'));
      expect(completion, contains('function Write-MambaCompletionResult'));
      expect(completion, contains('Register-ArgumentCompleter'));
    });

    test('emits input tables at the root and child command paths', () {
      final completion = convertPs(
        specRegistry(
          flags: [BooleanFlag('global')],
          options: [StringOption('profile', short: 'p')],
          commands: [TestCommand('serve', 'Serve requests.')],
        ).toMap(),
      );

      expect(completion, contains(r"$script:MambaInputs['root']"));
      expect(completion, contains(r"$script:MambaInputs['root.serve']"));
      expect(completion, contains(r"Spelling = '--global'"));
      expect(completion, contains(r"Spelling = '--profile'"));
    });

    test('propagates a nested alias to the global command-names table', () {
      final completion = convertPs(
        specRegistry(
          commands: [
            TestGroupCommand('config', [
              TestCommand('set', 'Set.', aliases: ['s']),
            ], 'Configure.'),
          ],
        ).toMap(),
      );

      expect(completion, contains(r"'config' = 'config'"));
      expect(completion, contains(r"'s' = 'set'"));
    });

    test('escapes apostrophes inside descriptions and choice names', () {
      final completion = convertPs(
        specRegistry(
          options: [
            ChoiceOption<_Format>(
              'format',
              choices: _Format.values,
              defaultValue: _Format.json,
              description: "format's output",
            ),
          ],
        ).toMap(),
      );

      expect(completion, contains(r"'format''s output'"));
    });

    test(
      'emits a single children entry at the root for direct subcommands',
      () {
        final completion = convertPs(
          specRegistry(
            commands: [
              TestCommand('commit', 'Commit changes.', aliases: ['ci']),
              TestCommand('push', 'Push changes.'),
            ],
          ).toMap(),
        );

        expect(completion, contains(r"$script:MambaChildren['root']"));
        expect(completion, contains(r"Name = 'commit'"));
        expect(completion, contains(r"Name = 'ci'"));
        expect(completion, contains(r"Name = 'push'"));
      },
    );

    test(
      'emits a variadic handler only on the command owning the variadic',
      () {
        final completion = convertPs(
          specRegistry(
            commands: [
              TestCommand(
                'serve',
                'Serve.',
                variadic: RepeatedChoiceVariadic<_Format>(
                  'extra',
                  choices: _Format.values,
                ),
              ),
            ],
          ).toMap(),
        );

        expect(
          completion,
          contains(r"$script:MambaVariadicHandlers['root.serve']"),
        );
        expect(
          completion,
          isNot(contains(r"$script:MambaVariadicHandlers['']")),
        );
      },
    );

    test('keeps registrar errors silent at runtime', () {
      final completion = convertPs(specRegistry().toMap());

      expect(completion, contains('catch { return }'));
      expect(completion, contains('catch { }'));
    });

    test('emits syntax supported by PowerShell 5.1 and newer', () {
      final completion = convertPs(
        specRegistry(
          options: [ChoiceOption<_Format>('format', choices: _Format.values)],
          commands: [
            TestCommand('serve', 'Serve requests.', aliases: ['s']),
          ],
        ).toMap(),
      );

      expect(
        completion.split('\n'),
        everyElement(isNot(matches(RegExp(r'^\s*.*},\s*$')))),
      );
      expect(completion, contains('Register-ArgumentCompleter -Native'));
      expect(
        completion,
        contains('[AllowEmptyString()][string]\$WordToComplete'),
      );
      expect(
        completion,
        contains('[System.Management.Automation.CompletionResult]::new('),
      );
    });
  });

  group("CarapaceSpecConverter", () {
    test('emits negated boolean flag forms', () {
      final registry = specRegistry(
        flags: [BooleanFlag('color', negatable: true)],
      );

      expect(convertSpec(registry.toMap()), contains('--no-color: ""'));
    });

    test('renders a RegistryMap without a CommandRegistry', () {
      final registryMap = RegistryMap({
        'name': 'from-map',
        'description': 'A map-defined command.',
        'flags': {
          'force': {
            'short': 'f',
            'default': false,
            'negatable': false,
            'hidden': false,
            'description': null,
          },
        },
        'options': {
          'retries': {
            'short': null,
            'required': true,
            'hidden': false,
            'description': 'Retry attempts.',
            'valueType': 'int',
          },
        },
      });

      expect(
        CarapaceSpecConverter(registryMap).convert(),
        equalsYaml('''
name: "from-map"
description: "A map-defined command."
persistentflags:
  -f, --force: ""
  -h, --help: "Show this help message."
  --retries!=: "Retry attempts."'''),
      );
    });

    test('preserves required paired options through registry conversion', () {
      final registry = specRegistry(
        pairedOptions: [
          PairedOptions(
            required: true,
            options: [
              PairStringOption('username', description: 'Account name.'),
              PairIntOption('port', description: 'Server port.'),
            ],
          ),
        ],
      );

      expect(
        convertSpec(registry.toMap()),
        equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --username!=: "Account name."
  --port!=: "Server port."
completion:
  flag:
    port:
      - "\$carapace.number.Range({start: -10, end: 10})"'''),
      );
    });

    test('renders every variant option and marks the group exclusive', () {
      final registry = specRegistry(
        pairedOptions: [
          PairedOptions(
            variant: true,
            options: [
              PairStringOption('json', description: 'Write JSON.'),
              PairStringOption('yaml', description: 'Write YAML.'),
            ],
          ),
        ],
      );

      final spec = convertSpec(registry.toMap());

      expect(
        spec,
        allOf(
          contains('--json?=: "Write JSON."'),
          contains('--yaml?=: "Write YAML."'),
          contains('exclusiveflags:'),
          contains('- "json"'),
          contains('- "yaml"'),
        ),
      );
    });

    test('renders typed accessor flags and their value completions', () {
      final registry = specRegistry(
        commands: [
          TestCommand(
            'serve',
            'Serve requests.',
            accessors: [
              AccessorListOption(
                'server',
                options: [
                  AccessorIntOption('port', description: 'Server port.'),
                  AccessorChoiceOption<_Sku>(
                    'sku',
                    description: 'Server size.',
                    choices: _Sku.values,
                    defaultValue: _Sku.basic,
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final spec = convertSpec(registry.toMap());

      expect(
        spec,
        allOf(
          contains('--server.port?=: "Server port."'),
          contains('--server.sku?=:'),
          contains('description: "Server size."'),
          contains('default: "basic"'),
          isNot(contains(r'$carapace.number.Range(')),
          allOf(
            contains('server.sku:'),
            contains('- "basic"'),
            contains('- "standard"'),
          ),
        ),
      );
    });

    test('renders accessor paths with five dots and shared branches', () {
      final registry = specRegistry(
        accessors: [
          AccessorListOption(
            'profile',
            options: [AccessorStringOption('name')],
          ),
          AccessorListOption(
            'cloud',
            options: [
              AccessorListOption(
                'provider',
                options: [
                  AccessorListOption(
                    'credentials',
                    options: [
                      AccessorListOption(
                        'oauth',
                        options: [
                          AccessorListOption(
                            'client',
                            options: [
                              AccessorStringOption('token'),
                              AccessorIntOption('timeout'),
                            ],
                          ),
                        ],
                      ),
                      AccessorStringOption('region'),
                    ],
                  ),
                  AccessorStringOption('endpoint'),
                ],
              ),
            ],
          ),
        ],
      );

      final spec = convertSpec(registry.toMap());

      expect(
        spec,
        allOf(
          contains('--profile.name?=: ""'),
          contains('--cloud.provider.endpoint?=: ""'),
          contains('--cloud.provider.credentials.region?=: ""'),
          contains('--cloud.provider.credentials.oauth.client.token?=: ""'),
          contains('--cloud.provider.credentials.oauth.client.timeout?=: ""'),
        ),
      );
    });

    test('propagates hidden accessor groups to descendant flags', () {
      final registry = specRegistry(
        commands: [
          TestCommand(
            'publish',
            'Publish output.',
            accessors: [
              AccessorListOption(
                'internal',
                hidden: true,
                options: [AccessorStringOption('token')],
              ),
            ],
          ),
        ],
      );

      final spec = convertSpec(registry.toMap());

      expect(spec, contains('--internal.token?&='));
    });

    test('rejects legacy description-only accessor maps', () {
      expect(
        () => RegistryMap({
          'name': 'legacy',
          'description': 'Legacy map.',
          'accessors': {
            'profile': {
              'description': 'Profile settings.',
              'options': {
                'name': {'description': 'Profile name.'},
              },
            },
          },
        }),
        throwsA(isA<MambaIntegrationException>()),
      );
    });

    group("commands", () {
      test("rendered with flags", () {
        final registry = specRegistry(
          commands: [
            TestCommand('sub', 'a subcommand', flags: [BooleanFlag('force')]),
          ],
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
commands:
  - name: "sub"
    description: "a subcommand"
    flags:
      -h, --help: "Show this help message."
      --force: ""'''),
        );
      });

      test("rendered with aliases", () {
        final registry = specRegistry(
          commands: [
            TestCommand('sub', 'a subcommand', aliases: ['s', 'b']),
          ],
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
commands:
  - name: "sub"
    description: "a subcommand"
    aliases:
      - "s"
      - "b"
    flags:
      -h, --help: "Show this help message."'''),
        );
      });

      test("rendered with options", () {
        final registry = specRegistry(
          commands: [
            TestCommand('sub', 'a subcommand', options: [IntOption('retries')]),
          ],
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
commands:
  - name: "sub"
    description: "a subcommand"
    flags:
      -h, --help: "Show this help message."
      --retries?=: ""
    completion:
      flag:
        retries:
          - "\$carapace.number.Range({start: -10, end: 10})"
'''),
        );
      });

      test("rendered with description", () {
        final registry = specRegistry(
          commands: [
            TestCommand(
              'sub',
              'a subcommand',
              longDescription: 'does the subs work',
            ),
          ],
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
commands:
  - name: "sub"
    description: |-
      a subcommand

      does the subs work
    flags:
      -h, --help: "Show this help message."'''),
        );
      });
    });

    group("flags", () {
      group("count versus bool flags", () {
        test("count flag rendered", () {
          final registry = specRegistry(
            flags: [CountFlag('verbose', description: 'increase verbosity')],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --verbose*: "increase verbosity"'''),
          );
        });

        test("count flag rendered with short", () {
          final registry = specRegistry(
            flags: [CountFlag('verbose', short: 'v')],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  -v, --verbose*: ""'''),
          );
        });

        test("count and bool flag descriptions are rendered", () {
          final registry = specRegistry(
            flags: [
              CountFlag('verbose', description: 'increase verbosity'),
              BooleanFlag('force', description: 'overwrite existing files'),
            ],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --force: "overwrite existing files"
  --verbose*: "increase verbosity"'''),
          );
        });

        test("bool flag rendered with words", () {
          final registry = specRegistry(flags: [BooleanFlag('force')]);

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --force: ""'''),
          );
        });

        test("bool flag rendered with short", () {
          final registry = specRegistry(
            flags: [BooleanFlag('force', short: 'f')],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  -f, --force: ""'''),
          );
        });

        test("hidden count flag rendered", () {
          final registry = specRegistry(
            flags: [CountFlag('trace', hidden: true)],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --trace*&: ""'''),
          );
        });

        test("hidden bool flag rendered", () {
          final registry = specRegistry(
            flags: [BooleanFlag('quiet', hidden: true)],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --quiet&: ""'''),
          );
        });

        // Mamba boolean flags cannot be required, so the spec must never add
        // the required `!` marker to one even when the TODO asks for it.
        test("required bool flag rendered", () {
          final registry = specRegistry(flags: [BooleanFlag('force')]);

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --force: ""'''),
          );
        });
      });

      group("options", () {
        test("option rendered", () {
          final registry = specRegistry(options: [IntOption('retries')]);

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --retries?=: ""
completion:
  flag:
    retries:
      - "\$carapace.number.Range({start: -10, end: 10})"
'''),
          );
        });

        test("option rendered with short", () {
          final registry = specRegistry(
            options: [IntOption('retries', short: 'r')],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  -r, --retries?=: ""
completion:
  flag:
    retries:
      - "\$carapace.number.Range({start: -10, end: 10})"
'''),
          );
        });

        test("option and repeated option descriptions are rendered", () {
          final registry = specRegistry(
            options: [
              IntOption('retries', description: 'attempts before giving up'),
              RepeatableIntOption('include', description: 'globs to include'),
            ],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --retries?=: "attempts before giving up"
  --include*?=: "globs to include"
completion:
  flag:
    retries:
      - "\$carapace.number.Range({start: -10, end: 10})"
    include:
      - "\$carapace.number.Range({start: -10, end: 10})"'''),
          );
        });

        test("repeatable flag rendered", () {
          final registry = specRegistry(
            options: [RepeatableIntOption('include')],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --include*?=: ""
completion:
  flag:
    include:
      - "\$carapace.number.Range({start: -10, end: 10})"'''),
          );
        });

        test("repeatable option rendered", () {
          final registry = specRegistry(
            options: [RepeatableIntOption('include', short: 'i')],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  -i, --include*?=: ""
completion:
  flag:
    include:
      - "\$carapace.number.Range({start: -10, end: 10})"'''),
          );
        });

        test("hidden flag rendered", () {
          final registry = specRegistry(
            options: [IntOption('debug-level', hidden: true)],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --debug-level?&=: ""
completion:
  flag:
    debug-level:
      - "\$carapace.number.Range({start: -10, end: 10})"
'''),
          );
        });

        test("hidden option rendered", () {
          final registry = specRegistry(
            options: [IntOption('debug-level', short: 'd', hidden: true)],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  -d, --debug-level?&=: ""
completion:
  flag:
    debug-level:
      - "\$carapace.number.Range({start: -10, end: 10})"
'''),
          );
        });

        test("required flag rendered", () {
          final registry = specRegistry(
            options: [IntOption('token', required: true)],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --token!=: ""
completion:
  flag:
    token:
      - "\$carapace.number.Range({start: -10, end: 10})"
'''),
          );
        });

        test("required option rendered", () {
          final registry = specRegistry(
            options: [IntOption('token', short: 't', required: true)],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  -t, --token!=: ""
completion:
  flag:
    token:
      - "\$carapace.number.Range({start: -10, end: 10})"
'''),
          );
        });
      });

      group("defaults", () {
        test("choice option default rendered", () {
          final registry = specRegistry(
            options: [
              ChoiceOption<_Format>(
                'format',
                choices: _Format.values,
                defaultValue: _Format.json,
                description: 'output format',
              ),
            ],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --format?=:
    description: "output format"
    default: "json"
completion:
  flag:
    format:
      - "json"
      - "yaml"'''),
          );
        });

        test("boolean flag default rendered", () {
          final registry = specRegistry(
            flags: [BooleanFlag('assumeyes', defaultValue: true)],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --assumeyes:
    description: ""
    default: true'''),
          );
        });
      });

      group("modifier combos", () {
        for (final combo in modifierCombos) {
          // Optionality fills with ! or ? only on value-taking options; flags
          // carry neither optionality nor arity.
          final suffix =
              '${combo.repeatability ? '*' : ''}'
              '${combo.arity ? (combo.optionality ? '!' : '?') : ''}'
              '${combo.appearance ? '&' : ''}'
              '${combo.arity ? '=' : ''}';

          test("long flag renders --combo$suffix", () {
            // Value-taking options carry the arity slot while flags cannot;
            // optionality additionally requires an option to be expressible.
            final completion = combo.arity
                ? '\ncompletion:\n'
                      '  flag:\n'
                      '    combo:\n'
                      '      - "\$carapace.number.Range({start: -10, end: 10})"\n'
                : '';
            final registry = combo.arity
                ? specRegistry(
                    options: [
                      if (combo.repeatability)
                        RepeatableIntOption(
                          'combo',
                          required: combo.optionality,
                          hidden: combo.appearance,
                        )
                      else
                        IntOption(
                          'combo',
                          required: combo.optionality,
                          hidden: combo.appearance,
                        ),
                    ],
                  )
                : specRegistry(
                    flags: [
                      if (combo.repeatability)
                        CountFlag('combo', hidden: combo.appearance)
                      else
                        BooleanFlag('combo', hidden: combo.appearance),
                    ],
                  );

            expect(
              convertSpec(registry.toMap()),
              equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --combo$suffix: ""$completion'''),
            );
          });
        }
      });
    });

    group("positionals", () {
      test("choice positionals are rendered", () {
        final registry = specRegistry(
          mandatoryPositionals: [
            ChoicePositional<_Format>('format', choices: _Format.values),
          ],
          discretionaryPositionals: [
            ChoicePositional<_Level>('level', choices: _Level.values),
          ],
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
completion:
  positional:
    - - "json"
      - "json"
      - "yaml"
      - "yaml"
    - - "debug"
      - "debug"
      - "info"
      - "info"'''),
        );
      });

      test("unconstrained positionals preserve later choice slots", () {
        final registry = specRegistry(
          mandatoryPositionals: [
            NormalPositional('path'),
            ChoicePositional<_Format>('format', choices: _Format.values),
          ],
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
completion:
  positional:
    - []
    - - "json"
      - "json"
      - "yaml"
      - "yaml"'''),
        );
      });

      test("repeated choice positionals render bounded slots", () {
        final registry = specRegistry(
          discretionaryPositionals: [
            RepeatedChoicePositional<_Format>(
              'format',
              choices: _Format.values,
              times: 2,
            ),
          ],
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
completion:
  positional:
    - - "json"
      - "json"
      - "yaml"
      - "yaml"
    - - "json"
      - "json"
      - "yaml"
      - "yaml"
    - - "json"
      - "json"
      - "yaml"
      - "yaml"'''),
        );
      });
    });

    group("variadic", () {
      test("choice variadics complete the first argument after --", () {
        final registry = specRegistry(
          variadic: ChoiceVariadic<_Format>('extra', choices: _Format.values),
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
completion:
  dash:
    - - "json"
      - "json"
      - "yaml"
      - "yaml"'''),
        );
      });

      test("repeated choice variadics complete every argument after --", () {
        final registry = specRegistry(
          variadic: RepeatedChoiceVariadic<_Format>(
            'extra',
            choices: _Format.values,
          ),
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
completion:
  dashany:
    - "json"
    - "yaml"'''),
        );
      });

      test("keeps ordinary and dash completions separate", () {
        final registry = specRegistry(
          mandatoryPositionals: [
            ChoicePositional<_Format>('format', choices: _Format.values),
          ],
          variadic: ChoiceVariadic<_Level>('extra', choices: _Level.values),
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
completion:
  positional:
    - - "json"
      - "json"
      - "yaml"
      - "yaml"
  dash:
    - - "debug"
      - "debug"
      - "info"
      - "info"'''),
        );
      });
    });

    test('renders bounded numeric options as Carapace ranges', () {
      final registry = specRegistry(
        options: [
          IntOption('retries', min: 1, max: 3),
          DoubleOption('ratio', min: 0.5, max: 1.5),
        ],
      );

      final spec = convertSpec(registry.toMap());

      expect(
        spec,
        allOf(
          contains(r'$carapace.number.Range({start: 1, end: 3})'),
          contains(r'$carapace.number.Range({start: 0.5, end: 1.5})'),
        ),
      );
    });

    test('renders every stepped double value through its maximum', () {
      final registry = specRegistry(
        options: [DoubleOption('ratio', min: 0, max: 0.3, step: 0.1)],
      );

      expect(
        convertSpec(registry.toMap()),
        contains(r'$carapace.ActionValues(\"0.0\", \"0.1\", \"0.2\", \"0.3\")'),
      );
    });

    test('renders stepped values for every double option variant', () {
      final registry = specRegistry(
        options: [
          DoubleOption('single', min: 0, max: 1, step: 0.5),
          RepeatableDoubleOption('repeated', min: 0, max: 1, step: 0.5),
        ],
        pairedOptions: [
          PairedOptions(
            options: [
              PairDoubleOption('pair', min: 0, max: 1, step: 0.5),
              RepeatablePairDoubleOption(
                'repeated-pair',
                min: 0,
                max: 1,
                step: 0.5,
              ),
            ],
          ),
        ],
      );

      final spec = convertSpec(registry.toMap());
      expect(RegExp(r'\$carapace\.ActionValues').allMatches(spec).length, 4);
      expect(
        spec,
        contains(r'$carapace.ActionValues(\"0.0\", \"0.5\", \"1.0\")'),
      );
    });

    group("numeric options", () {
      test("int options no longer invent a bounded completion range", () {
        final registry = specRegistry(options: [IntOption('retries')]);

        expect(
          convertSpec(registry.toMap()),
          isNot(contains('carapace.number.Range(')),
        );
        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --retries?=: ""
completion:
  flag:
    retries:
      - "\$carapace.number.Range({start: -10, end: 10})"'''),
        );
      });
      test("double options do not invent a completion range", () {
        final registry = specRegistry(options: [DoubleOption('price')]);

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --price?=: ""
completion:
  flag:
    price:
      - "\$carapace.number.Range({format: '%.2f', start: -10, end: 10})"'''),
        );
      });
    });

    group("inherited flags and options", () {
      test("root inputs render as persistentflags once", () {
        final registry = specRegistry(
          flags: [
            BooleanFlag('force', short: 'f'),
            CountFlag('verbose'),
          ],
          options: [IntOption('retries', short: 'r', required: true)],
          commands: [
            TestCommand('push', 'push changes'),
            TestCommand('pull', 'pull changes'),
          ],
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  -f, --force: ""
  --verbose*: ""
  -r, --retries!=: ""
completion:
  flag:
    retries:
      - "\$carapace.number.Range({start: -10, end: 10})"
commands:
  - name: "push"
    description: "push changes"
    flags:
      -h, --help: "Show this help message."
  - name: "pull"
    description: "pull changes"
    flags:
      -h, --help: "Show this help message."'''),
        );
      });

      test("a group's inherited inputs render once on the group", () {
        final registry = specRegistry(
          commands: [
            TestGroupCommand(
              'container',
              [TestCommand('list', 'list containers')],
              'manage containers',
              inheritedFlags: [
                BooleanFlag('color'),
                CountFlag('verbose', short: 'v', hidden: true),
              ],
              inheritedOptions: [
                IntOption('namespace', short: 'n', required: true),
              ],
            ),
          ],
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
commands:
  - name: "container"
    description: "manage containers"
    flags:
      -h, --help: "Show this help message."
    persistentflags:
      --color: ""
      -v, --verbose*&: ""
      -n, --namespace!=: ""
    commands:
      - name: "list"
        description: "list containers"
        flags:
          -h, --help: "Show this help message."'''),
        );
      });

      test(
        "groups merge ancestor globals with their own persistent inputs",
        () {
          final registry = specRegistry(
            flags: [BooleanFlag('global-flag', short: 'g')],
            commands: [
              TestGroupCommand(
                'container',
                [TestCommand('list', 'list containers')],
                'manage containers',
                inheritedFlags: [BooleanFlag('color')],
              ),
            ],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  -g, --global-flag: ""
commands:
  - name: "container"
    description: "manage containers"
    flags:
      -h, --help: "Show this help message."
    persistentflags:
      --color: ""
    commands:
      - name: "list"
        description: "list containers"
        flags:
          -h, --help: "Show this help message."'''),
          );
        },
      );

      test(
        "published inputs move to persistentflags while locals stay put",
        () {
          final registry = specRegistry(
            flags: [BooleanFlag('global-flag')],
            commands: [
              TestCommand(
                'child',
                'child command',
                flags: [BooleanFlag('own-flag')],
              ),
            ],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --global-flag: ""
commands:
  - name: "child"
    description: "child command"
    flags:
      -h, --help: "Show this help message."
      --own-flag: ""'''),
          );
        },
      );

      test('local inputs replace a group\'s published inputs', () {
        final registry = specRegistry(
          commands: [
            TestGroupCommand(
              'container',
              [TestCommand('list', 'list containers')],
              'manage containers',
              inheritedFlags: [BooleanFlag('force', short: 'f')],
              inheritedOptions: [IntOption('retries', short: 'r')],
              flags: [BooleanFlag('local-force', short: 'F')],
              options: [IntOption('retries', short: 'R')],
            ),
          ],
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
commands:
  - name: "container"
    description: "manage containers"
    flags:
      -h, --help: "Show this help message."
      -F, --local-force: ""
      -R, --retries?=: ""
    persistentflags:
      -f, --force: ""
    commands:
      - name: "list"
        description: "list containers"
        flags:
          -h, --help: "Show this help message."'''),
        );
      });
    });

    group("persistent flag registries", () {
      test("root globals and each group's own inputs render persistently", () {
        final registry = specRegistry(
          flags: [
            BooleanFlag('verbose', short: 'v', description: 'increase output'),
            CountFlag('trace'),
          ],
          options: [IntOption('jobs', short: 'j')],
          commands: [
            TestGroupCommand(
              'remote',
              [
                TestCommand('add', 'add a remote'),
                TestCommand('remove', 'remove a remote'),
              ],
              'manage remotes',
              inheritedFlags: [BooleanFlag('force')],
              inheritedOptions: [
                IntOption('depth', short: 'd', required: true),
              ],
            ),
            TestGroupCommand(
              'auth',
              [TestCommand('login', 'log in')],
              'manage credentials',
              inheritedFlags: [CountFlag('attempts')],
            ),
          ],
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  -v, --verbose: "increase output"
  --trace*: ""
  -j, --jobs?=: ""
completion:
  flag:
    jobs:
      - "\$carapace.number.Range({start: -10, end: 10})"
commands:
  - name: "remote"
    description: "manage remotes"
    flags:
      -h, --help: "Show this help message."
    persistentflags:
      --force: ""
      -d, --depth!=: ""
    commands:
      - name: "add"
        description: "add a remote"
        flags:
          -h, --help: "Show this help message."
      - name: "remove"
        description: "remove a remote"
        flags:
          -h, --help: "Show this help message."
  - name: "auth"
    description: "manage credentials"
    flags:
      -h, --help: "Show this help message."
    persistentflags:
      --attempts*: ""
    commands:
      - name: "login"
        description: "log in"
        flags:
          -h, --help: "Show this help message."'''),
        );
      });
    });

    group("real-world registries", () {
      // Modeled on the Azure CLI: documented globals (-v/--verbose, --debug,
      // -o/--output, --subscription) and a real four-group chain
      // (network > dns > record-set > a). Az scopes most flags per command,
      // so group-owned persistent inputs here adapt its conventions.
      test(
        "an az-style tree carries persistent flags down four group levels",
        () {
          final registry = specRegistry(
            flags: [
              BooleanFlag('verbose', short: 'v'),
              BooleanFlag('debug'),
            ],
            options: [
              IntOption('output', short: 'o'),
              StringOption('subscription', regex: RegExp(r'\S+')),
            ],
            commands: [
              TestGroupCommand(
                'vm',
                [TestCommand('list', 'list virtual machines')],
                'manage virtual machines',
                inheritedFlags: [BooleanFlag('no-wait')],
              ),
              TestGroupCommand(
                'storage',
                [TestCommand('check-name', 'check name availability')],
                'manage storage accounts',
                inheritedFlags: [BooleanFlag('https-only')],
                inheritedOptions: [
                  StringOption('account-name', regex: RegExp(r'\S+')),
                ],
              ),
              TestGroupCommand(
                'network',
                [
                  TestGroupCommand(
                    'dns',
                    [
                      TestGroupCommand(
                        'record-set',
                        [
                          TestGroupCommand(
                            'a',
                            [
                              TestCommand('add-record', 'add an a record'),
                              TestCommand(
                                'remove-record',
                                'remove an a record',
                              ),
                            ],
                            'manage a record sets',
                            inheritedOptions: [DoubleOption('ttl')],
                          ),
                        ],
                        'manage record sets',
                        inheritedOptions: [
                          StringOption('relative-name', regex: RegExp(r'\S+')),
                        ],
                      ),
                    ],
                    'manage dns zones',
                    inheritedOptions: [
                      StringOption('zone-name', regex: RegExp(r'\S+')),
                    ],
                  ),
                ],
                'manage networks',
                inheritedOptions: [IntOption('timeout')],
              ),
            ],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  -v, --verbose: ""
  --debug: ""
  -o, --output?=: ""
  --subscription?=: ""
completion:
  flag:
    output:
      - "\$carapace.number.Range({start: -10, end: 10})"
commands:
  - name: "vm"
    description: "manage virtual machines"
    flags:
      -h, --help: "Show this help message."
    persistentflags:
      --no-wait: ""
    commands:
      - name: "list"
        description: "list virtual machines"
        flags:
          -h, --help: "Show this help message."
  - name: "storage"
    description: "manage storage accounts"
    flags:
      -h, --help: "Show this help message."
    persistentflags:
      --https-only: ""
      --account-name?=: ""
    commands:
      - name: "check-name"
        description: "check name availability"
        flags:
          -h, --help: "Show this help message."
  - name: "network"
    description: "manage networks"
    flags:
      -h, --help: "Show this help message."
    persistentflags:
      --timeout?=: ""
    commands:
      - name: "dns"
        description: "manage dns zones"
        flags:
          -h, --help: "Show this help message."
        persistentflags:
          --zone-name?=: ""
        commands:
          - name: "record-set"
            description: "manage record sets"
            flags:
              -h, --help: "Show this help message."
            persistentflags:
              --relative-name?=: ""
            commands:
              - name: "a"
                description: "manage a record sets"
                flags:
                  -h, --help: "Show this help message."
                persistentflags:
                  --ttl?=: ""
                commands:
                  - name: "add-record"
                    description: "add an a record"
                    flags:
                      -h, --help: "Show this help message."
                  - name: "remove-record"
                    description: "remove an a record"
                    flags:
                      -h, --help: "Show this help message."'''),
          );
        },
      );
      test("choice inputs complete locally while their flags publish", () {
        final registry = specRegistry(
          flags: [BooleanFlag('verbose', short: 'v')],
          options: [IntOption('output', short: 'o')],
          commands: [
            TestGroupCommand(
              'vm',
              [
                TestCommand(
                  'show',
                  'show a virtual machine',
                  discretionaryPositionals: [
                    RepeatedChoicePositional<_Sku>('sku', choices: _Sku.values),
                  ],
                  variadic: RepeatedChoiceVariadic<_Format>(
                    'extra',
                    choices: _Format.values,
                  ),
                ),
              ],
              'manage virtual machines',
              inheritedFlags: [BooleanFlag('no-wait')],
              mandatoryPositionals: [
                ChoicePositional<_Sku>('sku', choices: _Sku.values),
              ],
            ),
          ],
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  -v, --verbose: ""
  -o, --output?=: ""
completion:
  flag:
    output:
      - "\$carapace.number.Range({start: -10, end: 10})"
commands:
  - name: "vm"
    description: "manage virtual machines"
    flags:
      -h, --help: "Show this help message."
    persistentflags:
      --no-wait: ""
    completion:
      positional:
        - - "basic"
          - "basic"
          - "standard"
          - "standard"
    commands:
      - name: "show"
        description: "show a virtual machine"
        flags:
          -h, --help: "Show this help message."
        completion:
          positional:
            - - "basic"
              - "basic"
              - "standard"
              - "standard"
            - - "basic"
              - "basic"
              - "standard"
              - "standard"
          dashany:
            - "json"
            - "yaml"'''),
        );
      });
    });

    group("nested subcommands", () {
      for (final depth in [2, 3, 4, 5]) {
        test("a single flag reaches $depth nested subcommands", () {
          final registry = nestedRegistry(
            depth,
            flags: [BooleanFlag('force', short: 'f')],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml(
              nestedExpectation(
                depth: depth,
                rootFlagEntries: ['-f, --force: ""'],
                persistentEntries: ['-f, --force: ""'],
              ),
            ),
          );
        });
      }

      for (final depth in [2, 3, 4, 5]) {
        test("a repeated option reaches $depth nested subcommands", () {
          final registry = nestedRegistry(
            depth,
            options: [RepeatableIntOption('include', short: 'i')],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml(
              nestedExpectation(
                depth: depth,
                rootFlagEntries: ['-i, --include*?=: ""'],
                persistentEntries: ['-i, --include*?=: ""'],
                rootCompletionLines: [
                  'completion:',
                  '  flag:',
                  '    include:',
                  '      - "\$carapace.number.Range({start: -10, end: 10})"',
                ],
              ),
            ),
          );
        });
      }
    });
  });
}
