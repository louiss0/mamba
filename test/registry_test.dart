import 'package:mamba/command.dart';
import 'package:mamba/errors.dart';
import 'package:mamba/registry.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

enum VariantChoice { one }

enum DeploymentFormat { yaml, json }

/// Expected metadata for a flag exported by a registry.
typedef FlagExpectation = (
  String name, {
  String? short,
  bool? defaultValue,
  bool? negatable,
  bool? hidden,
  String? description,
});

/// Expected metadata for an option exported by a registry.
typedef OptionExpectation = (
  String name, {
  String? short,
  bool? required,
  bool? hidden,
  String? description,
  bool? repeatable,
  bool? variant,
  List<String>? choices,
  String? choiceDefault,
});

/// Expected metadata for a positional exported by a registry.
typedef PositionalExpectation = (
  String name, {
  bool? required,
  String? description,
});

/// Expected metadata for an accessor and its nested options.
final class AccessorExpectation {
  const AccessorExpectation(this.name, {this.description, this.options});

  final String name;
  final String? description;
  final List<AccessorExpectation>? options;
}

/// Expected metadata for a command and its nested registry categories.
final class CommandExpectation {
  const CommandExpectation(
    this.name,
    this.description, {
    this.flags,
    this.options,
    this.positionals,
    this.accessors,
    this.commands,
  });

  final String name;
  final String description;
  final List<FlagExpectation>? flags;
  final List<OptionExpectation>? options;
  final List<PositionalExpectation>? positionals;
  final List<AccessorExpectation>? accessors;
  final List<CommandExpectation>? commands;
}

/// Builds the expected map for a registry level from its [name] and
/// [description] plus optional category expectations, with an optional
/// [commands] list whose records recurse through this builder.
Map<String, dynamic> buildRegistryExpectation(
  String name,
  String description, {
  List<String>? aliases,
  List<FlagExpectation>? flags,
  List<OptionExpectation>? options,
  List<PositionalExpectation>? positionals,
  List<AccessorExpectation>? accessors,
  List<CommandExpectation>? commands,
}) {
  Map<String, dynamic> mapFlags(List<FlagExpectation> entries) => {
    for (final entry in entries)
      entry.$1: {
        if (entry.short != null || entry.defaultValue != null)
          'short': entry.short,
        if (entry.defaultValue != null) 'default': entry.defaultValue,
        if (entry.negatable != null) 'negatable': entry.negatable,
        'hidden': entry.hidden,
        'description': entry.description,
      },
  };

  Map<String, dynamic> mapOptions(List<OptionExpectation> entries) => {
    for (final entry in entries)
      entry.$1: {
        'short': entry.short,
        'required': entry.required,
        'hidden': entry.hidden,
        'description': entry.description,
        if (entry.repeatable case final repeatable?) 'repeatable': repeatable,
        if (entry.variant case final variant?) 'variant': variant,
        if (entry.choices case final choices?) 'choices': choices,
        if (entry.choiceDefault case final choiceDefault?)
          'default': choiceDefault,
      },
  };

  Map<String, dynamic> mapPositionals(List<PositionalExpectation> entries) => {
    for (final entry in entries)
      entry.$1: {'required': entry.required, 'description': entry.description},
  };

  Object? mapAccessor(AccessorExpectation entry, {bool root = true}) {
    final options = entry.options;
    if (root) {
      return {
        'description': entry.description,
        'options': {
          for (final option in options ?? const <AccessorExpectation>[])
            option.name: {'description': option.description},
        },
      };
    }
    if (options == null) return entry.description;
    return {
      for (final option in options)
        option.name: mapAccessor(option, root: false),
    };
  }

  Map<String, dynamic> mapAccessors(
    List<AccessorExpectation> entries, {
    bool root = true,
  }) => {
    for (final entry in entries) entry.name: mapAccessor(entry, root: root),
  };

  Map<String, dynamic> mapCommand(CommandExpectation entry) => {
    'name': entry.name,
    'description': entry.description,
    if (entry.flags case final flags?) 'flags': mapFlags(flags),
    if (entry.options case final options?) 'options': mapOptions(options),
    if (entry.positionals case final positionals?)
      'positionals': mapPositionals(positionals),
    if (entry.accessors case final accessors?)
      'accessors': mapAccessors(accessors, root: false),
    if (entry.commands case final commands?)
      'commands': {
        for (final command in commands) command.name: mapCommand(command),
      },
  };

  return {
    'name': name,
    'description': description,
    'aliases': ?aliases,
    if (flags case final flags?) 'flags': mapFlags(flags),
    if (options case final options?) 'options': mapOptions(options),
    if (positionals case final positionals?)
      'positionals': mapPositionals(positionals),
    if (accessors case final accessors?) 'accessors': mapAccessors(accessors),
    if (commands case final commands?)
      'commands': {
        for (final command in commands) command.name: mapCommand(command),
      },
  };
}

void main() {
  group('CommandRegistry', () {
    group("toMap", () {
      test("makes the map based on the inputs ", () {
        final color = BooleanFlag('color', negatable: true);
        final verbose = CountFlag('verbose');
        final name = StringOption('name', regex: RegExp(r'\S+'));
        final tag = RepeatableStringOption('tag');
        final source = Positional('source');
        final target = Positional('target');

        final profile = AccessorListOption(
          'user',
          options: [AccessorStringOption('profile')],
        );

        final registry = CommandRegistry.create(
          'tool',
          'Tool command.',
          flags: [color, verbose],
          options: [name, tag],
          accessors: [profile],
          mandatoryPositionals: [source],
          discretionaryPositionals: [target],
        );

        expect(
          registry.toMap(),
          equals(
            buildRegistryExpectation(
              'tool',
              'Tool command.',

              flags: [
                (
                  'color',
                  short: null,
                  defaultValue: false,
                  negatable: true,
                  hidden: false,
                  description: null,
                ),
                (
                  'verbose',
                  short: null,
                  defaultValue: null,
                  negatable: null,
                  hidden: false,
                  description: null,
                ),
              ],

              options: [
                (
                  'name',
                  short: null,
                  required: false,
                  hidden: false,
                  description: null,
                  repeatable: null,
                  variant: null,
                  choices: null,
                  choiceDefault: null,
                ),
                (
                  'tag',
                  short: null,
                  required: false,
                  hidden: false,
                  description: null,
                  repeatable: true,
                  variant: null,
                  choices: null,
                  choiceDefault: null,
                ),
              ],

              positionals: [
                ('source', required: true, description: null),
                ('target', required: false, description: null),
              ],

              accessors: [
                AccessorExpectation(
                  'user',
                  description: null,
                  options: [AccessorExpectation('profile', description: null)],
                ),
              ],
              aliases: null,
            ),
          ),
        );
      });

      test(
        "When a long description is added it's added to the description",
        () {
          final registry = CommandRegistry.create(
            'tool',
            'Tool command.',
            longDescription: "This is a tool meant to be used to make ",
          );

          expect(
            registry.toMap(),
            equals(
              buildRegistryExpectation(
                'tool',

                'Tool command.\n\nThis is a tool meant to be used to make ',
                aliases: null,
                flags: null,
                options: null,
                positionals: null,
                accessors: null,
              ),
            ),
          );
        },
      );

      test(
        "When a command is added it's added to a commands prop that's a map",
        () {
          final registry = CommandRegistry.create(
            'git',
            'Save snapshots of your code and be able to send them anywhere',
            commands: [
              TestCommand('add', 'Add a file to the staging area'),
              TestCommand('commit', 'Take a snapshot of your code'),
              TestGroupCommand("worktree", [
                TestCommand(
                  'add',
                  'Make a new work tree',
                  mandatoryPositionals: [
                    Positional(
                      'path',
                      description: 'The path to the work tree',
                    ),
                  ],
                  discretionaryPositionals: [
                    Positional(
                      "commit-ish",
                      description:
                          "Choosse a commit to use to scaffold the worktree",
                    ),
                  ],
                ),
                TestCommand('commit', 'Take a snapshot of your code'),
              ], "Place your code in separate repo that can be merged"),
            ],
          );

          expect(
            registry.toMap(),
            equals(
              buildRegistryExpectation(
                'git',

                'Save snapshots of your code and be able to send them anywhere',
                aliases: null,
                flags: null,
                options: null,
                positionals: null,
                accessors: null,

                commands: [
                  CommandExpectation(
                    'add',
                    'Add a file to the staging area',
                    flags: null,
                    options: null,
                    positionals: null,
                    accessors: null,
                    commands: null,
                  ),
                  CommandExpectation(
                    'commit',
                    'Take a snapshot of your code',
                    flags: null,
                    options: null,
                    positionals: null,
                    accessors: null,
                    commands: null,
                  ),
                  CommandExpectation(
                    'worktree',
                    'Place your code in separate repo that can be merged',
                    flags: null,
                    options: null,
                    positionals: null,
                    accessors: null,
                    commands: [
                      CommandExpectation(
                        'add',
                        'Make a new work tree',
                        flags: null,
                        options: null,
                        positionals: [
                          (
                            'path',
                            required: true,
                            description: 'The path to the work tree',
                          ),
                          (
                            'commit-ish',
                            required: false,
                            description:
                                "Choosse a commit to use to scaffold the worktree",
                          ),
                        ],
                        accessors: null,
                        commands: null,
                      ),
                      CommandExpectation(
                        'commit',
                        'Take a snapshot of your code',
                        flags: null,
                        options: null,
                        positionals: null,
                        accessors: null,
                        commands: null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );

      test("Adds commands recursively", () {
        final registry = CommandRegistry.create(
          'tool',
          'Tool command.',
          commands: [
            TestCommand('sub', 'Sub command.'),
            TestGroupCommand('one', [
              TestGroupCommand('two', [
                TestGroupCommand('three', [
                  TestGroupCommand('four', [
                    TestGroupCommand('five', [
                      TestCommand('sub', 'Sub command.'),
                    ], 'Group five.'),
                  ], 'Group four.'),
                ], 'Group three.'),
              ], 'Group two.'),
            ], 'Group one.'),
          ],
        );

        expect(
          registry.toMap(),
          equals(
            buildRegistryExpectation(
              'tool',
              'Tool command.',
              aliases: null,
              flags: null,
              options: null,
              positionals: null,
              accessors: null,

              commands: [
                CommandExpectation(
                  'sub',
                  'Sub command.',
                  flags: null,
                  options: null,
                  positionals: null,
                  accessors: null,
                  commands: null,
                ),
                CommandExpectation(
                  'one',
                  'Group one.',
                  flags: null,
                  options: null,
                  positionals: null,
                  accessors: null,
                  commands: [
                    CommandExpectation(
                      'two',
                      'Group two.',
                      flags: null,
                      options: null,
                      positionals: null,
                      accessors: null,
                      commands: [
                        CommandExpectation(
                          'three',
                          'Group three.',
                          flags: null,
                          options: null,
                          positionals: null,
                          accessors: null,
                          commands: [
                            CommandExpectation(
                              'four',
                              'Group four.',
                              flags: null,
                              options: null,
                              positionals: null,
                              accessors: null,
                              commands: [
                                CommandExpectation(
                                  'five',
                                  'Group five.',
                                  flags: null,
                                  options: null,
                                  positionals: null,
                                  accessors: null,
                                  commands: [
                                    CommandExpectation(
                                      'sub',
                                      'Sub command.',
                                      flags: null,
                                      options: null,
                                      positionals: null,
                                      accessors: null,
                                      commands: null,
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
                ),
              ],
            ),
          ),
        );
      });

      test("Map's accessors properly", () {
        final registry = CommandRegistry.create(
          'git',
          'Create a new Git repository.',
          commands: [
            TestCommand(
              'config',
              'Configure Git.',
              accessors: [
                AccessorListOption(
                  'branch',
                  options: [
                    AccessorListOption(
                      'main',
                      options: [
                        AccessorStringOption(
                          'remote',
                          description: 'The remote to fetch from or push to.',
                        ),
                        AccessorStringOption(
                          'merge',
                          description: 'The upstream branch to merge.',
                        ),
                        AccessorStringOption(
                          'rebase',
                          description:
                              'Whether to rebase instead of merge when pulling.',
                        ),
                      ],
                    ),
                  ],
                ),
                AccessorListOption(
                  'remote',
                  options: [
                    AccessorListOption(
                      'origin',
                      options: [
                        AccessorStringOption(
                          'url',
                          description: 'The URL of a remote repository.',
                        ),
                        AccessorStringOption(
                          'pushurl',
                          description: 'The push URL of a remote repository.',
                        ),
                        AccessorStringOption(
                          'fetch',
                          description: 'The default set of refspecs for fetch.',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        );

        final map = registry.toMap();

        expect(
          map,
          equals(
            buildRegistryExpectation(
              'git',
              'Create a new Git repository.',
              aliases: null,
              flags: null,
              options: null,
              positionals: null,
              accessors: null,

              commands: [
                CommandExpectation(
                  'config',
                  'Configure Git.',
                  flags: null,
                  options: null,
                  positionals: null,
                  accessors: [
                    AccessorExpectation(
                      'branch',
                      description: null,
                      options: [
                        AccessorExpectation(
                          'main',
                          description: null,
                          options: [
                            AccessorExpectation(
                              'remote',
                              description:
                                  'The remote to fetch from or push to.',
                            ),
                            AccessorExpectation(
                              'merge',
                              description: 'The upstream branch to merge.',
                            ),
                            AccessorExpectation(
                              'rebase',
                              description:
                                  'Whether to rebase instead of merge when pulling.',
                            ),
                          ],
                        ),
                      ],
                    ),
                    AccessorExpectation(
                      'remote',
                      description: null,
                      options: [
                        AccessorExpectation(
                          'origin',
                          description: null,
                          options: [
                            AccessorExpectation(
                              'url',
                              description: 'The URL of a remote repository.',
                            ),
                            AccessorExpectation(
                              'pushurl',
                              description:
                                  'The push URL of a remote repository.',
                            ),
                            AccessorExpectation(
                              'fetch',
                              description:
                                  'The default set of refspecs for fetch.',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                  commands: null,
                ),
              ],
            ),
          ),
        );
      });

      test('maps options properly', () {
        final registry = CommandRegistry.create(
          'curl',
          'Do HTTP Requests',
          options: [
            StringOption(
              'url',
              short: 'u',
              description: 'URL(s) to work with.',
              required: true,
              regex: RegExp(r'\S+'),
            ),
            IntOption('retry', description: 'Retry on transient problems.'),
            DoubleOption(
              'max-time',
              short: 'm',
              description: 'Maximum time allowed for a transfer.',
            ),
            RepeatableStringOption(
              'header',
              short: 'H',
              description: 'Pass custom headers to the server.',
            ),
            RepeatableStringOption(
              'data',
              short: 'd',
              description: 'HTTP POST data.',
            ),
          ],
        );

        expect(
          registry.toMap(),
          equals(
            buildRegistryExpectation(
              'curl',
              'Do HTTP Requests',

              options: [
                (
                  'url',
                  short: 'u',
                  required: true,
                  hidden: false,
                  description: 'URL(s) to work with.',
                  repeatable: null,
                  variant: null,
                  choices: null,
                  choiceDefault: null,
                ),
                (
                  'retry',
                  short: null,
                  required: false,
                  hidden: false,
                  description: 'Retry on transient problems.',
                  repeatable: null,
                  variant: null,
                  choices: null,
                  choiceDefault: null,
                ),
                (
                  'max-time',
                  short: 'm',
                  required: false,
                  hidden: false,
                  description: 'Maximum time allowed for a transfer.',
                  repeatable: null,
                  variant: null,
                  choices: null,
                  choiceDefault: null,
                ),
                (
                  'header',
                  short: 'H',
                  required: false,
                  hidden: false,
                  description: 'Pass custom headers to the server.',
                  repeatable: true,
                  variant: null,
                  choices: null,
                  choiceDefault: null,
                ),
                (
                  'data',
                  short: 'd',
                  required: false,
                  hidden: false,
                  description: 'HTTP POST data.',
                  repeatable: true,
                  variant: null,
                  choices: null,
                  choiceDefault: null,
                ),
              ],
              aliases: null,
              flags: null,
              positionals: null,
              accessors: null,
            ),
          ),
        );
      });

      test("maps flags properly", () {
        final registry = CommandRegistry.create(
          'rsync',
          'Synchronize files and directories.',
          flags: [
            CountFlag(
              'verbose',
              short: 'v',
              description: 'Increase verbosity.',
            ),
            CountFlag(
              'quiet',
              short: 'q',
              description: 'Suppress non-error messages.',
            ),
            BooleanFlag(
              'dry-run',
              short: 'n',
              description: 'Perform a trial run with no changes made.',
            ),
            BooleanFlag(
              'archive',
              short: 'a',
              description: 'Enable archive mode.',
            ),
          ],
        );

        expect(
          registry.toMap(),
          equals(
            buildRegistryExpectation(
              'rsync',
              'Synchronize files and directories.',

              flags: [
                (
                  'verbose',
                  short: 'v',
                  defaultValue: null,
                  negatable: null,
                  hidden: false,
                  description: 'Increase verbosity.',
                ),
                (
                  'quiet',
                  short: 'q',
                  defaultValue: null,
                  negatable: null,
                  hidden: false,
                  description: 'Suppress non-error messages.',
                ),
                (
                  'dry-run',
                  short: 'n',
                  defaultValue: false,
                  negatable: false,
                  hidden: false,
                  description: 'Perform a trial run with no changes made.',
                ),
                (
                  'archive',
                  short: 'a',
                  defaultValue: false,
                  negatable: false,
                  hidden: false,
                  description: 'Enable archive mode.',
                ),
              ],
              aliases: null,
              options: null,
              positionals: null,
              accessors: null,
            ),
          ),
        );
      });

      test("maps positionals properly", () {
        final registry = CommandRegistry.create(
          'docker',
          'Manage containers.',
          commands: [
            TestCommand(
              'run',
              'Create and run a new container from an image.',
              mandatoryPositionals: [
                Positional('image', description: 'The image to run.'),
              ],
              discretionaryPositionals: [
                Positional('command', description: 'The command to run.'),
                Positional(
                  'arguments',
                  description: 'Arguments for the command.',
                ),
              ],
            ),
            TestCommand(
              'exec',
              'Execute a command in a running container.',
              mandatoryPositionals: [
                Positional('container', description: 'The running container.'),
                Positional('command', description: 'The command to execute.'),
              ],
              discretionaryPositionals: [
                Positional(
                  'arguments',
                  description: 'Arguments for the command.',
                ),
              ],
            ),
            TestCommand(
              'cp',
              'Copy files between a container and the local filesystem.',
              mandatoryPositionals: [
                Positional('source-path', description: 'The source path.'),
                Positional(
                  'destination-path',
                  description: 'The destination path.',
                ),
              ],
            ),
            TestCommand(
              'rename',
              'Rename a container.',
              mandatoryPositionals: [
                Positional(
                  'container',
                  description: 'The container to rename.',
                ),
                Positional('new-name', description: 'The new container name.'),
              ],
            ),
            TestCommand(
              'commit',
              "Create a new image from a container's changes.",
              mandatoryPositionals: [
                Positional(
                  'container',
                  description: 'The container to commit.',
                ),
              ],
              discretionaryPositionals: [
                Positional('repository', description: 'The target repository.'),
              ],
            ),
          ],
        );

        expect(
          registry.toMap(),
          equals(
            buildRegistryExpectation(
              'docker',
              'Manage containers.',
              aliases: null,
              flags: null,
              options: null,
              positionals: null,
              accessors: null,

              commands: [
                CommandExpectation(
                  'run',
                  'Create and run a new container from an image.',
                  flags: null,
                  options: null,
                  positionals: [
                    ('image', required: true, description: 'The image to run.'),
                    (
                      'command',
                      required: false,
                      description: 'The command to run.',
                    ),
                    (
                      'arguments',
                      required: false,
                      description: 'Arguments for the command.',
                    ),
                  ],
                  accessors: null,
                  commands: null,
                ),
                CommandExpectation(
                  'exec',
                  'Execute a command in a running container.',
                  flags: null,
                  options: null,
                  positionals: [
                    (
                      'container',
                      required: true,
                      description: 'The running container.',
                    ),
                    (
                      'command',
                      required: true,
                      description: 'The command to execute.',
                    ),
                    (
                      'arguments',
                      required: false,
                      description: 'Arguments for the command.',
                    ),
                  ],
                  accessors: null,
                  commands: null,
                ),
                CommandExpectation(
                  'cp',
                  'Copy files between a container and the local filesystem.',
                  flags: null,
                  options: null,
                  positionals: [
                    (
                      'source-path',
                      required: true,
                      description: 'The source path.',
                    ),
                    (
                      'destination-path',
                      required: true,
                      description: 'The destination path.',
                    ),
                  ],
                  accessors: null,
                  commands: null,
                ),
                CommandExpectation(
                  'rename',
                  'Rename a container.',
                  flags: null,
                  options: null,
                  positionals: [
                    (
                      'container',
                      required: true,
                      description: 'The container to rename.',
                    ),
                    (
                      'new-name',
                      required: true,
                      description: 'The new container name.',
                    ),
                  ],
                  accessors: null,
                  commands: null,
                ),
                CommandExpectation(
                  'commit',
                  "Create a new image from a container's changes.",
                  flags: null,
                  options: null,
                  positionals: [
                    (
                      'container',
                      required: true,
                      description: 'The container to commit.',
                    ),
                    (
                      'repository',
                      required: false,
                      description: 'The target repository.',
                    ),
                  ],
                  accessors: null,
                  commands: null,
                ),
              ],
            ),
          ),
        );
      });

      test("maps nested commands with flags and options correctly", () {
        final registry = CommandRegistry.create(
          'git',
          'Track and manage source code.',
          commands: [
            TestGroupCommand('remote', [
              TestCommand(
                'add',
                'Add a tracked repository.',
                mandatoryPositionals: [
                  Positional('name', description: 'The remote name.'),
                  Positional('url', description: 'The remote URL.'),
                ],
                flags: [
                  BooleanFlag(
                    'fetch',
                    short: 'f',
                    description: 'Fetch the remote after adding it.',
                  ),
                  BooleanFlag(
                    'tags',
                    description: 'Import every tag from the remote.',
                    negatable: true,
                  ),
                ],
                options: [
                  RepeatableStringOption(
                    'track',
                    short: 't',
                    description: 'A branch to track.',
                  ),
                  StringOption(
                    'master',
                    short: 'm',
                    description: 'The remote default branch.',
                    regex: RegExp(r'\S+'),
                  ),
                  StringOption(
                    'mirror',
                    description: 'The mirror direction.',
                    regex: RegExp(r'\S+'),
                  ),
                ],
              ),
            ], 'Manage tracked repositories.'),
            TestGroupCommand('worktree', [
              TestCommand(
                'add',
                'Create a linked working tree.',
                mandatoryPositionals: [
                  Positional('path', description: 'The worktree path.'),
                ],
                discretionaryPositionals: [
                  Positional(
                    'commit-ish',
                    description: 'The revision to check out.',
                  ),
                ],
                flags: [
                  CountFlag(
                    'force',
                    short: 'f',
                    description: 'Override worktree safety checks.',
                  ),
                  BooleanFlag(
                    'detach',
                    short: 'd',
                    description: 'Detach HEAD in the new worktree.',
                  ),
                ],
                options: [
                  StringOption(
                    'new-branch',
                    short: 'b',
                    description: 'The branch to create.',
                    regex: RegExp(r'\S+'),
                  ),
                  StringOption(
                    'reason',
                    description: 'Why the worktree is locked.',
                    regex: RegExp(r'\S+'),
                  ),
                ],
              ),
            ], 'Manage linked working trees.'),
            TestGroupCommand('stash', [
              TestCommand(
                'push',
                'Stash changes in the working directory.',
                discretionaryPositionals: [
                  Positional('pathspec', description: 'A path to stash.'),
                ],
                flags: [
                  BooleanFlag(
                    'patch',
                    short: 'p',
                    description: 'Select changes interactively.',
                  ),
                  BooleanFlag(
                    'include-untracked',
                    short: 'u',
                    description: 'Include untracked files.',
                  ),
                ],
                options: [
                  StringOption(
                    'message',
                    short: 'm',
                    description: 'The stash message.',
                    regex: RegExp(r'\S+'),
                  ),
                ],
              ),
            ], 'Stash working directory changes.'),
          ],
        );

        expect(
          registry.toMap(),
          equals(
            buildRegistryExpectation(
              'git',
              'Track and manage source code.',
              aliases: null,
              flags: null,
              options: null,
              positionals: null,
              accessors: null,

              commands: [
                CommandExpectation(
                  'remote',
                  'Manage tracked repositories.',
                  flags: null,
                  options: null,
                  positionals: null,
                  accessors: null,
                  commands: [
                    CommandExpectation(
                      'add',
                      'Add a tracked repository.',
                      flags: [
                        (
                          'fetch',
                          short: 'f',
                          defaultValue: false,
                          negatable: false,
                          hidden: false,
                          description: 'Fetch the remote after adding it.',
                        ),
                        (
                          'tags',
                          short: null,
                          defaultValue: false,
                          negatable: true,
                          hidden: false,
                          description: 'Import every tag from the remote.',
                        ),
                      ],
                      options: [
                        (
                          'track',
                          short: 't',
                          required: false,
                          hidden: false,
                          description: 'A branch to track.',
                          repeatable: true,
                          variant: null,
                          choices: null,
                          choiceDefault: null,
                        ),
                        (
                          'master',
                          short: 'm',
                          required: false,
                          hidden: false,
                          description: 'The remote default branch.',
                          repeatable: null,
                          variant: null,
                          choices: null,
                          choiceDefault: null,
                        ),
                        (
                          'mirror',
                          short: null,
                          required: false,
                          hidden: false,
                          description: 'The mirror direction.',
                          repeatable: null,
                          variant: null,
                          choices: null,
                          choiceDefault: null,
                        ),
                      ],
                      positionals: [
                        (
                          'name',
                          required: true,
                          description: 'The remote name.',
                        ),
                        ('url', required: true, description: 'The remote URL.'),
                      ],
                      accessors: null,
                      commands: null,
                    ),
                  ],
                ),
                CommandExpectation(
                  'worktree',
                  'Manage linked working trees.',
                  flags: null,
                  options: null,
                  positionals: null,
                  accessors: null,
                  commands: [
                    CommandExpectation(
                      'add',
                      'Create a linked working tree.',
                      flags: [
                        (
                          'force',
                          short: 'f',
                          defaultValue: null,
                          negatable: null,
                          hidden: false,
                          description: 'Override worktree safety checks.',
                        ),
                        (
                          'detach',
                          short: 'd',
                          defaultValue: false,
                          negatable: false,
                          hidden: false,
                          description: 'Detach HEAD in the new worktree.',
                        ),
                      ],
                      options: [
                        (
                          'new-branch',
                          short: 'b',
                          required: false,
                          hidden: false,
                          description: 'The branch to create.',
                          repeatable: null,
                          variant: null,
                          choices: null,
                          choiceDefault: null,
                        ),
                        (
                          'reason',
                          short: null,
                          required: false,
                          hidden: false,
                          description: 'Why the worktree is locked.',
                          repeatable: null,
                          variant: null,
                          choices: null,
                          choiceDefault: null,
                        ),
                      ],
                      positionals: [
                        (
                          'path',
                          required: true,
                          description: 'The worktree path.',
                        ),
                        (
                          'commit-ish',
                          required: false,
                          description: 'The revision to check out.',
                        ),
                      ],
                      accessors: null,
                      commands: null,
                    ),
                  ],
                ),
                CommandExpectation(
                  'stash',
                  'Stash working directory changes.',
                  flags: null,
                  options: null,
                  positionals: null,
                  accessors: null,
                  commands: [
                    CommandExpectation(
                      'push',
                      'Stash changes in the working directory.',
                      flags: [
                        (
                          'patch',
                          short: 'p',
                          defaultValue: false,
                          negatable: false,
                          hidden: false,
                          description: 'Select changes interactively.',
                        ),
                        (
                          'include-untracked',
                          short: 'u',
                          defaultValue: false,
                          negatable: false,
                          hidden: false,
                          description: 'Include untracked files.',
                        ),
                      ],
                      options: [
                        (
                          'message',
                          short: 'm',
                          required: false,
                          hidden: false,
                          description: 'The stash message.',
                          repeatable: null,
                          variant: null,
                          choices: null,
                          choiceDefault: null,
                        ),
                      ],
                      positionals: [
                        (
                          'pathspec',
                          required: false,
                          description: 'A path to stash.',
                        ),
                      ],
                      accessors: null,
                      commands: null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      });

      group("maps paired options properly", () {
        test("maps dependent options", () {
          final registry = CommandRegistry.create(
            'aws',
            'Manage Amazon Web Services.',
            commands: [
              TestCommand(
                'put-object',
                'Add an object to an Amazon S3 bucket.',
                pairedOptions: [
                  PairedStringOption(
                    'sse-customer-algorithm',
                    description: 'The customer encryption algorithm.',
                    options: [
                      PairStringOption(
                        'sse-customer-key',
                        description: 'The customer encryption key.',
                      ),
                      PairStringOption(
                        'sse-customer-key-md5',
                        description: 'The MD5 digest of the customer key.',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );

          expect(
            registry.toMap(),
            equals(
              buildRegistryExpectation(
                'aws',
                'Manage Amazon Web Services.',
                aliases: null,
                flags: null,
                options: null,
                positionals: null,
                accessors: null,

                commands: [
                  CommandExpectation(
                    'put-object',
                    'Add an object to an Amazon S3 bucket.',
                    flags: null,
                    options: [
                      (
                        'sse-customer-algorithm',
                        short: null,
                        required: false,
                        hidden: false,
                        description: 'The customer encryption algorithm.',
                        repeatable: null,
                        variant: null,
                        choices: null,
                        choiceDefault: null,
                      ),
                      (
                        'sse-customer-key',
                        short: null,
                        required: false,
                        hidden: false,
                        description: 'The customer encryption key.',
                        repeatable: null,
                        variant: null,
                        choices: null,
                        choiceDefault: null,
                      ),
                      (
                        'sse-customer-key-md5',
                        short: null,
                        required: false,
                        hidden: false,
                        description: 'The MD5 digest of the customer key.',
                        repeatable: null,
                        variant: null,
                        choices: null,
                        choiceDefault: null,
                      ),
                    ],
                    positionals: null,
                    accessors: null,
                    commands: null,
                  ),
                ],
              ),
            ),
          );
        });

        test("maps independent options correctly", () {
          final registry = CommandRegistry.create(
            'git',
            'Track and manage source code.',
            commands: [
              TestGroupCommand('worktree', [
                TestCommand(
                  'add',
                  'Create a linked working tree.',
                  pairedOptions: [
                    PairedStringOption(
                      'new-branch',
                      short: 'b',
                      description: 'Create a new branch.',
                      variant: true,
                      options: [
                        PairStringOption(
                          'force-new-branch',
                          short: 'B',
                          description: 'Create or reset a branch.',
                        ),
                      ],
                    ),
                  ],
                ),
              ], 'Manage linked working trees.'),
            ],
          );

          expect(
            registry.toMap(),
            equals(
              buildRegistryExpectation(
                'git',
                'Track and manage source code.',
                aliases: null,
                flags: null,
                options: null,
                positionals: null,
                accessors: null,

                commands: [
                  CommandExpectation(
                    'worktree',
                    'Manage linked working trees.',
                    flags: null,
                    options: null,
                    positionals: null,
                    accessors: null,
                    commands: [
                      CommandExpectation(
                        'add',
                        'Create a linked working tree.',
                        flags: null,
                        options: [
                          (
                            'new-branch',
                            short: 'b',
                            required: false,
                            hidden: false,
                            description: 'Create a new branch.',
                            variant: true,
                            repeatable: null,
                            choices: null,
                            choiceDefault: null,
                          ),
                          (
                            'force-new-branch',
                            short: 'B',
                            required: false,
                            hidden: false,
                            description: 'Create or reset a branch.',
                            repeatable: null,
                            variant: null,
                            choices: null,
                            choiceDefault: null,
                          ),
                        ],
                        positionals: null,
                        accessors: null,
                        commands: null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });

        test(
          'maps choice options and paired variants for a deployment CLI',
          () {
            final registry = CommandRegistry.create(
              'deploy',
              'Deploy an application.',
              options: [
                ChoiceOption<DeploymentFormat>(
                  'format',
                  choices: DeploymentFormat.values,
                  defaultValue: DeploymentFormat.json,
                ),
              ],
              pairedOptions: [
                PairedChoiceOption<DeploymentFormat>(
                  'manifest',
                  choices: DeploymentFormat.values,
                  defaultValue: DeploymentFormat.yaml,
                  variant: true,
                  options: [
                    PairChoiceOption<DeploymentFormat>(
                      'manifest-file',
                      choices: DeploymentFormat.values,
                      defaultValue: DeploymentFormat.json,
                    ),
                  ],
                ),
              ],
            );

            expect(
              registry.toMap()['options'],
              equals({
                'format': {
                  'short': null,
                  'required': false,
                  'hidden': false,
                  'description': null,
                  'choices': ['yaml', 'json'],
                  'default': 'json',
                },
                'manifest': {
                  'short': null,
                  'required': false,
                  'hidden': false,
                  'description': null,
                  'variant': true,
                  'choices': ['yaml', 'json'],
                  'default': 'yaml',
                },
                'manifest-file': {
                  'short': null,
                  'required': false,
                  'hidden': false,
                  'description': null,
                  'choices': ['yaml', 'json'],
                  'default': 'json',
                },
              }),
            );
          },
        );

        test('maps numeric and repeatable paired options for a backup CLI', () {
          final registry = CommandRegistry.create(
            'backup',
            'Back up a workspace.',
            pairedOptions: [
              PairedIntOption(
                'chunk-size',
                options: [PairDoubleOption('compression-level')],
              ),
              PairedDoubleOption(
                'timeout',
                options: [PairIntOption('attempts')],
              ),
              RepeatablePairedStringOption(
                'include',
                options: [RepeatablePairStringOption('include-from')],
              ),
              RepeatablePairedIntOption(
                'shard',
                options: [RepeatablePairIntOption('shard-count')],
              ),
              RepeatablePairedDoubleOption(
                'rate',
                options: [RepeatablePairDoubleOption('rate-limit')],
              ),
            ],
          );

          final options = registry.toMap()['options'] as Map<String, dynamic>;

          expect(options['chunk-size']['repeatable'], isNull);
          expect(options['compression-level']['repeatable'], isNull);
          expect(options['timeout']['repeatable'], isNull);
          expect(options['attempts']['repeatable'], isNull);
          for (final name in [
            'include',
            'include-from',
            'shard',
            'shard-count',
            'rate',
            'rate-limit',
          ]) {
            expect(options[name]['repeatable'], isTrue, reason: name);
          }
        });

        test('exports command aliases and hidden inputs for a release CLI', () {
          final registry = CommandRegistry.create(
            'release',
            'Publish a release.',
            flags: [BooleanFlag('dry-run', hidden: true)],
            options: [
              StringOption('token', hidden: true, regex: RegExp(r'\S+')),
            ],
            accessors: [
              AccessorListOption(
                'internal',
                hidden: true,
                options: [AccessorStringOption('trace-id')],
              ),
            ],
            commands: [
              TestCommand('publish', 'Publish the release.', aliases: ['push']),
            ],
          );

          final exported = registry.toMap();

          expect(exported['commands']['publish']['aliases'], ['push']);
          expect(exported['flags']['dry-run'], {
            'short': null,
            'default': false,
            'negatable': false,
            'hidden': true,
            'description': null,
          });
          expect(exported['options']['token'], {
            'short': null,
            'required': false,
            'hidden': true,
            'description': null,
          });
          expect(exported['accessors']['internal'], {
            'hidden': true,
            'description': null,
            'options': {
              'trace-id': {'description': null},
            },
          });
        });
      });
    });

    test('indexes list-defined inputs by their names', () {
      final color = BooleanFlag('color');
      final verbose = CountFlag('verbose');
      final name = StringOption('name', regex: RegExp(r'\S+'));
      final tag = RepeatableStringOption('tag');
      final source = Positional('source');
      final target = Positional('target');
      final profile = AccessorListOption(
        'user',
        options: [AccessorStringOption('profile')],
      );

      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        flags: [color, verbose],
        options: [name, tag],
        accessors: [profile],
        mandatoryPositionals: [source],
        discretionaryPositionals: [target],
      );

      expect(registry.boolFlags, {'color': color});
      expect(registry.helpFlag.short, 'h');
      expect(registry.countFlags, {'verbose': verbose});
      expect(registry.singleOptions, {'name': name});
      expect(registry.repeatedOptions, {'tag': tag});
      expect(registry.mandatoryPositionals, {'source': source});
      expect(registry.discretionaryPositionals, {'target': target});
      expect(registry.accessors, {'user': profile});
    });

    test('indexes paired options by their group name', () {
      final credentials = PairedStringOption(
        'username',
        options: [PairStringOption('password')],
      );

      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        pairedOptions: [credentials],
      );

      expect(registry.pairedOptions, {'username': credentials});
    });

    test('defaults paired options to grouping', () {
      final credentials = PairedStringOption(
        'username',
        options: [PairStringOption('password')],
      );

      expect(credentials.variant, isFalse);
    });

    test('supports variants for every paired option type', () {
      final variants = <PairedOption>[
        PairedStringOption(
          'string',
          variant: true,
          options: [PairStringOption('stringPair')],
        ),
        PairedIntOption(
          'int',
          variant: true,
          options: [PairIntOption('intPair')],
        ),
        PairedDoubleOption(
          'double',
          variant: true,
          options: [PairDoubleOption('doublePair')],
        ),
        PairedChoiceOption<VariantChoice>(
          'choice',
          choices: VariantChoice.values,
          variant: true,
          options: [
            PairChoiceOption<VariantChoice>(
              'choicePair',
              choices: VariantChoice.values,
            ),
          ],
        ),
        RepeatablePairedStringOption(
          'repeatedString',
          variant: true,
          options: [RepeatablePairStringOption('repeatedStringPair')],
        ),
        RepeatablePairedIntOption(
          'repeatedInt',
          variant: true,
          options: [RepeatablePairIntOption('repeatedIntPair')],
        ),
        RepeatablePairedDoubleOption(
          'repeatedDouble',
          variant: true,
          options: [RepeatablePairDoubleOption('repeatedDoublePair')],
        ),
      ];

      expect(variants.map((option) => option.variant), everyElement(isTrue));
    });

    test('rejects paired options without a paired member', () {
      expect(
        () => CommandRegistry.create(
          'login',
          'Authenticate a user.',
          pairedOptions: [PairedStringOption('username', options: [])],
        ),
        throwsA(isA<MambaException>()),
      );
    });

    test('creates registries for list-defined child commands', () {
      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        commands: [
          TestCommand(
            'config',
            'Configure the tool.',
            accessors: [
              AccessorListOption(
                'server',
                options: [AccessorIntOption('port')],
              ),
            ],
          ),
        ],
      );

      final config = registry.commandRegistries!.single;
      expect(config.name, 'config');
      expect(config.accessors!['server']!.options.single.name, 'port');
    });

    test('reserves the built-in help flag name and alias', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          flags: [BooleanFlag('help')],
        ),
        throwsA(isA<MambaRegistryError>()),
      );
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          flags: [BooleanFlag('custom', short: 'h')],
        ),
        throwsA(isA<MambaRegistryError>()),
      );
    });

    test('resolves the command whose help was requested', () {
      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        flags: [CountFlag('verbose', short: 'v')],
        commands: [TestGroupCommand('config', [], 'Configure the tool.')],
      );

      expect(registry.requestsHelp(['config', '--help']), isTrue);
      expect(registry.requestsHelp(['--', '--help']), isFalse);
      expect(
        registry.registryForArguments(['--verbose', 'config', '-h']).name,
        'config',
      );
    });

    test('group commands publish explicit inputs to descendants', () {
      final inheritedFlag = BooleanFlag('color');
      final inheritedOption = IntOption('retries');
      final localFlag = BooleanFlag('color', description: 'child');
      final localOption = IntOption('retries', description: 'child');
      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        commands: [
          TestGroupCommand(
            'config',
            [
              TestCommand(
                'get',
                'Get configuration.',
                flags: [localFlag],
                options: [localOption],
              ),
            ],
            'Configure.',
            inheritedFlags: [inheritedFlag],
            inheritedOptions: [inheritedOption],
          ),
        ],
      );

      final group = registry.commandRegistries!.single;
      final child = group.commandRegistries!.single;
      expect(group.boolFlags!['color'], same(inheritedFlag));
      expect(group.singleOptions!['retries'], same(inheritedOption));
      expect(child.boolFlags!['color'], same(localFlag));
      expect(child.singleOptions!['retries'], same(localOption));
    });

    test('only group commands register child commands', () {
      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        commands: [
          TestGroupCommand(
            'config',
            [TestCommand('get', 'Get configuration.')],
            'Configure.',
            flags: [BooleanFlag('color')],
            options: [IntOption('retries')],
          ),
        ],
      );

      final group = registry.commandRegistries!.single;
      final child = group.commandRegistries!.single;
      expect(group.boolFlags, contains('color'));
      expect(group.singleOptions, contains('retries'));
      expect(child.boolFlags, isNull);
      expect(child.singleOptions, isNull);
    });

    test('distinguishes absent input collections from empty collections', () {
      final absent = CommandRegistry.create('tool', 'Tool command.');
      final empty = CommandRegistry.create(
        'tool',
        'Tool command.',
        options: const [],
      );

      expect(absent.singleOptions, isNull);
      expect(empty.singleOptions, isEmpty);
    });

    test('rejects invalid command and description boundaries', () {
      for (final name in ['', 'tool1', '_', '-', 'tool!']) {
        expect(
          () => CommandRegistry.create(name, 'Tool command.'),
          throwsA(anyOf(isA<MambaException>(), isA<MambaRegistryError>())),
        );
      }
      expect(
        () => CommandRegistry.create('tool', ''),
        throwsA(isA<MambaException>()),
      );
      expect(
        () => CommandRegistry.create('tool', 'x' * 150),
        throwsA(isA<MambaException>()),
      );
      expect(() => CommandRegistry.create('tool', 'x' * 149), returnsNormally);
    });

    test('accepts letter-led alphanumeric and hyphenated input names', () {
      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        flags: [
          BooleanFlag('verbose2', short: 'v'),
          BooleanFlag('dry-run'),
        ],
        options: [
          IntOption('retry2', short: 'r'),
          IntOption('back-off'),
        ],
      );

      expect(registry.boolFlags, contains('verbose2'));
      expect(registry.boolFlags, contains('dry-run'));
      expect(registry.singleOptions, contains('retry2'));
      expect(registry.singleOptions, contains('back-off'));
    });

    test('rejects input names outside the letter-led supported form', () {
      for (final name in ['2fast', 'dry_run', 'verbose!']) {
        expect(
          () => CommandRegistry.create(
            'tool',
            'Tool command.',
            flags: [BooleanFlag(name)],
          ),
          throwsA(isA<MambaRegistryError>()),
        );
        expect(
          () => CommandRegistry.create(
            'tool',
            'Tool command.',
            options: [IntOption(name)],
          ),
          throwsA(isA<MambaRegistryError>()),
        );
      }
    });

    test('rejects non-letter short aliases', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          flags: [BooleanFlag('verbose', short: '2')],
        ),
        throwsA(isA<MambaRegistryError>()),
      );
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          options: [IntOption('retry', short: '-')],
        ),
        throwsA(isA<MambaRegistryError>()),
      );
    });

    test('rejects invalid input and positional symbols', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          options: [StringOption('bad!', regex: RegExp(r'.+'))],
        ),
        throwsA(isA<MambaRegistryError>()),
      );
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          mandatoryPositionals: [Positional('bad!')],
        ),
        throwsA(isA<MambaRegistryError>()),
      );
    });

    test('recursively validates nested accessor names', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          accessors: [
            AccessorListOption(
              'server',
              options: [
                AccessorListOption(
                  'authentication',
                  options: [AccessorStringOption('help')],
                ),
              ],
            ),
          ],
        ),
        throwsA(isA<MambaRegistryError>()),
      );
    });

    test('rejects collisions between accessors and other inputs', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          accessors: [
            AccessorListOption(
              'profile',
              options: [AccessorStringOption('value')],
            ),
          ],
          flags: [BooleanFlag('profile')],
        ),
        throwsA(isA<MambaException>()),
      );
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          accessors: [
            AccessorListOption(
              'profile',
              options: [AccessorStringOption('value')],
            ),
          ],
          options: [StringOption('profile', regex: RegExp(r'.+'))],
        ),
        throwsA(isA<MambaException>()),
      );
    });

    test('rejects positional collisions', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          mandatoryPositionals: [Positional('source')],
          discretionaryPositionals: [Positional('source')],
        ),
        throwsA(isA<MambaException>()),
      );
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          mandatoryPositionals: [Positional('config')],
          commands: [TestCommand('config', 'Configure.')],
        ),
        throwsA(isA<MambaException>()),
      );
    });

    test('rejects duplicate command names', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          commands: [
            TestCommand('config', 'Configure.'),
            TestCommand('config', 'Configure again.'),
          ],
        ),
        throwsA(isA<MambaException>()),
      );
    });

    test('rejects conflicting flag and option names', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          flags: [BooleanFlag('verbose')],
          options: [IntOption('verbose')],
        ),
        throwsA(isA<MambaException>()),
      );
    });

    test('rejects conflicting short aliases', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          flags: [BooleanFlag('verbose', short: 'v')],
          options: [IntOption('version', short: 'v')],
        ),
        throwsA(isA<MambaException>()),
      );
    });

    test('rejects invalid and duplicate list definitions', () {
      expect(
        () => CommandRegistry.create('bad name', 'Tool command.'),
        throwsA(isA<MambaException>()),
      );
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          flags: [BooleanFlag('verbose'), BooleanFlag('verbose')],
        ),
        throwsA(isA<MambaException>()),
      );
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          options: [
            StringOption('name', regex: RegExp(r'\S+')),
            RepeatableStringOption('name'),
          ],
        ),
        throwsA(isA<MambaException>()),
      );
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          accessors: [
            AccessorListOption(
              'remote',
              options: [
                AccessorStringOption('url'),
                AccessorStringOption('url'),
              ],
            ),
          ],
        ),
        throwsA(isA<MambaException>()),
      );
    });
  });

  group('processes aliases correctly', () {
    test('indexes command aliases by alias and command name', () {
      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        commands: [
          TestCommand('checkout', 'Checkout.', aliases: ['co', 'check']),
        ],
      );

      expect(registry.aliases, {'co': 'checkout', 'check': 'checkout'});
      expect(registry.registryForArguments(['co']).name, 'checkout');
      expect(registry.registryForArguments(['check']).name, 'checkout');
    });

    test('throws a Mamba error for duplicate aliases on one command', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          commands: [
            TestCommand('checkout', 'Checkout.', aliases: ['co', 'co']),
          ],
        ),
        throwsA(
          isA<MambaException>().having(
            (error) => error.message,
            'message',
            contains('tool checkout'),
          ),
        ),
      );
    });

    test('rejects an alias already registered by another command', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          commands: [
            TestCommand('checkout', 'Checkout.', aliases: ['co']),
            TestCommand('config', 'Configure.', aliases: ['co']),
          ],
        ),
        throwsA(
          isA<MambaException>().having(
            (error) => error.message,
            'message',
            allOf(contains('already registered'), contains('pick another one')),
          ),
        ),
      );
    });

    test('rejects an alias equal to its command name', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          commands: [
            TestCommand('checkout', 'Checkout.', aliases: ['checkout']),
          ],
        ),
        throwsA(
          isA<MambaException>().having(
            (error) => error.message,
            'message',
            contains('tool checkout'),
          ),
        ),
      );
    });

    test('rejects an explicitly empty alias list', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          commands: [TestCommand('checkout', 'Checkout.', aliases: const [])],
        ),
        throwsA(
          isA<MambaException>().having(
            (error) => error.message,
            'message',
            contains('tool checkout'),
          ),
        ),
      );
    });

    for (final depth in [1, 2, 3, 4, 5]) {
      for (final violation in _AliasViolation.values) {
        test('reports the command path for $violation at depth $depth', () {
          final commandPath = ['tool', ..._groupNames.take(depth)];
          final invalidCommand = _nestedCommandWithAliasViolation(
            depth,
            violation,
          );
          final path = violation == _AliasViolation.duplicateAcrossCommands
              ? [...commandPath, 'second']
              : [...commandPath, 'leaf'];

          expect(
            () => CommandRegistry.create(
              'tool',
              'Tool command.',
              commands: [invalidCommand],
            ),
            throwsA(
              isA<MambaException>().having(
                (error) => error.message,
                'message',
                contains(path.join(' ')),
              ),
            ),
          );
        });
      }
    }
  });
}

const _groupNames = ['one', 'two', 'three', 'four', 'five'];

enum _AliasViolation {
  duplicateOnCommand,
  duplicateAcrossCommands,
  sameAsCommand,
  empty,
}

Command _nestedCommandWithAliasViolation(int depth, _AliasViolation violation) {
  final groupNames = _groupNames.take(depth).toList();
  final command = switch (violation) {
    _AliasViolation.duplicateAcrossCommands => TestGroupCommand(
      groupNames.last,
      [
        TestCommand('first', 'First.', aliases: ['shared']),
        TestCommand('second', 'Second.', aliases: ['shared']),
      ],
      'Group.',
      aliases: ['group-alias-${groupNames.last}'],
    ),
    _AliasViolation.duplicateOnCommand => TestGroupCommand(
      groupNames.last,
      [
        TestCommand('leaf', 'Leaf.', aliases: ['leaf-alias', 'leaf-alias']),
      ],
      'Group.',
      aliases: ['group-alias-${groupNames.last}'],
    ),
    _AliasViolation.sameAsCommand => TestGroupCommand(
      groupNames.last,
      [
        TestCommand('leaf', 'Leaf.', aliases: ['leaf']),
      ],
      'Group.',
      aliases: ['group-alias-${groupNames.last}'],
    ),
    _AliasViolation.empty => TestGroupCommand(
      groupNames.last,
      [TestCommand('leaf', 'Leaf.', aliases: const [])],
      'Group.',
      aliases: ['group-alias-${groupNames.last}'],
    ),
  };

  var nested = command;
  for (var index = depth - 2; index >= 0; index--) {
    nested = TestGroupCommand(
      groupNames[index],
      [nested],
      'Group.',
      aliases: ['group-alias-${groupNames[index]}'],
    );
  }
  return nested;
}
