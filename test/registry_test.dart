import 'package:mamba/command.dart';
import 'package:mamba/errors.dart';
import 'package:mamba/registry.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

enum VariantChoice { one }

enum DeploymentFormat { yaml, json }

Map<String, dynamic> buildRegistryExpectation(
  String name,
  String description, {
  List<String>? aliases,
  Map<String, dynamic>? flags,
  Map<String, dynamic>? options,
  Map<String, dynamic>? positionals,
  Map<String, dynamic>? accessors,
  Map<String, dynamic>? commands,
}) => {
  'name': name,
  'description': description,
  ...?(aliases == null ? null : {'aliases': aliases}),
  ...?(flags == null ? null : {'flags': flags}),
  ...?(options == null ? null : {'options': options}),
  ...?(positionals == null ? null : {'positionals': positionals}),
  ...?(accessors == null ? null : {'accessors': accessors}),
  ...?(commands == null ? null : {'commands': _addCommandNames(commands)}),
};

Map<String, dynamic> _addCommandNames(Map<String, dynamic> commands) => {
  for (final entry in commands.entries)
    entry.key: _addCommandName(entry.key, entry.value as Map<String, dynamic>),
};

Map<String, dynamic> _addCommandName(
  String name,
  Map<String, dynamic> command,
) => {
  ...command,
  'name': name,
  if (command['commands'] case final nestedCommands?)
    'commands': _addCommandNames(nestedCommands as Map<String, dynamic>),
};

void main() {
  group('CommandRegistry', () {
    group("toMap", () {
      test("makes the map based on the inputs ", () {
        final color = BooleanFlag(name: 'color', negatable: true);
        final verbose = CountFlag(name: 'verbose');
        final name = StringOption(name: 'name', regex: RegExp(r'\S+'));
        final tag = RepeatableStringOption(name: 'tag');
        final source = Positional('source');
        final target = Positional('target');

        final profile = AccessorListOption(
          name: 'user',
          options: [AccessorStringOption(name: 'profile')],
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
              flags: {
                'color': {
                  'short': null,
                  'default': false,
                  'negatable': true,
                  'hidden': false,
                  "description": null,
                },
                'verbose': {'hidden': false, "description": null},
              },
              options: {
                'name': {
                  'short': null,
                  'required': false,
                  'hidden': false,
                  "description": null,
                },
                'tag': {
                  'short': null,
                  'required': false,
                  'hidden': false,
                  "description": null,
                  'repeatable': true,
                },
              },
              positionals: {
                'source': {'required': true, "description": null},
                'target': {'required': false, "description": null},
              },
              accessors: {
                'user': {
                  'description': null,
                  'options': {
                    'profile': {'description': null},
                  },
                },
              },
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
                commands: {
                  'add': {'description': 'Add a file to the staging area'},
                  'commit': {'description': 'Take a snapshot of your code'},
                  'worktree': {
                    'description':
                        'Place your code in separate repo that can be merged',
                    'commands': {
                      'add': {
                        'description': 'Make a new work tree',
                        'positionals': {
                          'path': {
                            'required': true,
                            'description': 'The path to the work tree',
                          },
                          'commit-ish': {
                            'required': false,
                            'description':
                                "Choosse a commit to use to scaffold the worktree",
                          },
                        },
                      },
                      'commit': {'description': 'Take a snapshot of your code'},
                    },
                  },
                },
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
              commands: {
                'sub': {'description': 'Sub command.'},
                'one': {
                  'description': 'Group one.',
                  'commands': {
                    'two': {
                      'description': 'Group two.',
                      'commands': {
                        'three': {
                          'description': 'Group three.',
                          'commands': {
                            'four': {
                              'description': 'Group four.',
                              'commands': {
                                'five': {
                                  'description': 'Group five.',
                                  'commands': {
                                    'sub': {'description': 'Sub command.'},
                                  },
                                },
                              },
                            },
                          },
                        },
                      },
                    },
                  },
                },
              },
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
                  name: 'branch',
                  options: [
                    AccessorListOption(
                      name: 'main',
                      options: [
                        AccessorStringOption(
                          name: 'remote',
                          description: 'The remote to fetch from or push to.',
                        ),
                        AccessorStringOption(
                          name: 'merge',
                          description: 'The upstream branch to merge.',
                        ),
                        AccessorStringOption(
                          name: 'rebase',
                          description:
                              'Whether to rebase instead of merge when pulling.',
                        ),
                      ],
                    ),
                  ],
                ),
                AccessorListOption(
                  name: 'remote',
                  options: [
                    AccessorListOption(
                      name: 'origin',
                      options: [
                        AccessorStringOption(
                          name: 'url',
                          description: 'The URL of a remote repository.',
                        ),
                        AccessorStringOption(
                          name: 'pushurl',
                          description: 'The push URL of a remote repository.',
                        ),
                        AccessorStringOption(
                          name: 'fetch',
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
              commands: {
                'config': {
                  'description': 'Configure Git.',
                  'accessors': {
                    'branch': {
                      'main': {
                        'remote': 'The remote to fetch from or push to.',
                        'merge': 'The upstream branch to merge.',
                        'rebase':
                            'Whether to rebase instead of merge when pulling.',
                      },
                    },
                    'remote': {
                      'origin': {
                        'url': 'The URL of a remote repository.',
                        'pushurl': 'The push URL of a remote repository.',
                        'fetch': 'The default set of refspecs for fetch.',
                      },
                    },
                  },
                },
              },
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
              name: 'url',
              short: 'u',
              description: 'URL(s) to work with.',
              required: true,
              regex: RegExp(r'\S+'),
            ),
            IntOption(
              name: 'retry',
              description: 'Retry on transient problems.',
            ),
            DoubleOption(
              name: 'max-time',
              short: 'm',
              description: 'Maximum time allowed for a transfer.',
            ),
            RepeatableStringOption(
              name: 'header',
              short: 'H',
              description: 'Pass custom headers to the server.',
            ),
            RepeatableStringOption(
              name: 'data',
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
              options: {
                'url': {
                  'short': 'u',
                  'required': true,
                  'hidden': false,
                  'description': 'URL(s) to work with.',
                },
                'retry': {
                  'short': null,
                  'required': false,
                  'hidden': false,
                  'description': 'Retry on transient problems.',
                },
                'max-time': {
                  'short': 'm',
                  'required': false,
                  'hidden': false,
                  'description': 'Maximum time allowed for a transfer.',
                },
                'header': {
                  'short': 'H',
                  'required': false,
                  'hidden': false,
                  'description': 'Pass custom headers to the server.',
                  'repeatable': true,
                },
                'data': {
                  'short': 'd',
                  'required': false,
                  'hidden': false,
                  'description': 'HTTP POST data.',
                  'repeatable': true,
                },
              },
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
              name: 'verbose',
              short: 'v',
              description: 'Increase verbosity.',
            ),
            CountFlag(
              name: 'quiet',
              short: 'q',
              description: 'Suppress non-error messages.',
            ),
            BooleanFlag(
              name: 'dry-run',
              short: 'n',
              description: 'Perform a trial run with no changes made.',
            ),
            BooleanFlag(
              name: 'archive',
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
              flags: {
                'verbose': {
                  'short': 'v',
                  'hidden': false,
                  'description': 'Increase verbosity.',
                },
                'quiet': {
                  'short': 'q',
                  'hidden': false,
                  'description': 'Suppress non-error messages.',
                },
                'dry-run': {
                  'short': 'n',
                  'default': false,
                  'negatable': false,
                  'hidden': false,
                  'description': 'Perform a trial run with no changes made.',
                },
                'archive': {
                  'short': 'a',
                  'default': false,
                  'negatable': false,
                  'hidden': false,
                  'description': 'Enable archive mode.',
                },
              },
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
              commands: {
                'run': {
                  'description':
                      'Create and run a new container from an image.',
                  'positionals': {
                    'image': {
                      'required': true,
                      'description': 'The image to run.',
                    },
                    'command': {
                      'required': false,
                      'description': 'The command to run.',
                    },
                    'arguments': {
                      'required': false,
                      'description': 'Arguments for the command.',
                    },
                  },
                },
                'exec': {
                  'description': 'Execute a command in a running container.',
                  'positionals': {
                    'container': {
                      'required': true,
                      'description': 'The running container.',
                    },
                    'command': {
                      'required': true,
                      'description': 'The command to execute.',
                    },
                    'arguments': {
                      'required': false,
                      'description': 'Arguments for the command.',
                    },
                  },
                },
                'cp': {
                  'description':
                      'Copy files between a container and the local filesystem.',
                  'positionals': {
                    'source-path': {
                      'required': true,
                      'description': 'The source path.',
                    },
                    'destination-path': {
                      'required': true,
                      'description': 'The destination path.',
                    },
                  },
                },
                'rename': {
                  'description': 'Rename a container.',
                  'positionals': {
                    'container': {
                      'required': true,
                      'description': 'The container to rename.',
                    },
                    'new-name': {
                      'required': true,
                      'description': 'The new container name.',
                    },
                  },
                },
                'commit': {
                  'description':
                      "Create a new image from a container's changes.",
                  'positionals': {
                    'container': {
                      'required': true,
                      'description': 'The container to commit.',
                    },
                    'repository': {
                      'required': false,
                      'description': 'The target repository.',
                    },
                  },
                },
              },
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
                    name: 'fetch',
                    short: 'f',
                    description: 'Fetch the remote after adding it.',
                  ),
                  BooleanFlag(
                    name: 'tags',
                    description: 'Import every tag from the remote.',
                    negatable: true,
                  ),
                ],
                options: [
                  RepeatableStringOption(
                    name: 'track',
                    short: 't',
                    description: 'A branch to track.',
                  ),
                  StringOption(
                    name: 'master',
                    short: 'm',
                    description: 'The remote default branch.',
                    regex: RegExp(r'\S+'),
                  ),
                  StringOption(
                    name: 'mirror',
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
                    name: 'force',
                    short: 'f',
                    description: 'Override worktree safety checks.',
                  ),
                  BooleanFlag(
                    name: 'detach',
                    short: 'd',
                    description: 'Detach HEAD in the new worktree.',
                  ),
                ],
                options: [
                  StringOption(
                    name: 'new-branch',
                    short: 'b',
                    description: 'The branch to create.',
                    regex: RegExp(r'\S+'),
                  ),
                  StringOption(
                    name: 'reason',
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
                    name: 'patch',
                    short: 'p',
                    description: 'Select changes interactively.',
                  ),
                  BooleanFlag(
                    name: 'include-untracked',
                    short: 'u',
                    description: 'Include untracked files.',
                  ),
                ],
                options: [
                  StringOption(
                    name: 'message',
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
              commands: {
                'remote': {
                  'description': 'Manage tracked repositories.',
                  'commands': {
                    'add': {
                      'description': 'Add a tracked repository.',
                      'flags': {
                        'fetch': {
                          'short': 'f',
                          'default': false,
                          'negatable': false,
                          'hidden': false,
                          'description': 'Fetch the remote after adding it.',
                        },
                        'tags': {
                          'short': null,
                          'default': false,
                          'negatable': true,
                          'hidden': false,
                          'description': 'Import every tag from the remote.',
                        },
                      },
                      'options': {
                        'track': {
                          'short': 't',
                          'required': false,
                          'hidden': false,
                          'description': 'A branch to track.',
                          'repeatable': true,
                        },
                        'master': {
                          'short': 'm',
                          'required': false,
                          'hidden': false,
                          'description': 'The remote default branch.',
                        },
                        'mirror': {
                          'short': null,
                          'required': false,
                          'hidden': false,
                          'description': 'The mirror direction.',
                        },
                      },
                      'positionals': {
                        'name': {
                          'required': true,
                          'description': 'The remote name.',
                        },
                        'url': {
                          'required': true,
                          'description': 'The remote URL.',
                        },
                      },
                    },
                  },
                },
                'worktree': {
                  'description': 'Manage linked working trees.',
                  'commands': {
                    'add': {
                      'description': 'Create a linked working tree.',
                      'flags': {
                        'force': {
                          'short': 'f',
                          'hidden': false,
                          'description': 'Override worktree safety checks.',
                        },
                        'detach': {
                          'short': 'd',
                          'default': false,
                          'negatable': false,
                          'hidden': false,
                          'description': 'Detach HEAD in the new worktree.',
                        },
                      },
                      'options': {
                        'new-branch': {
                          'short': 'b',
                          'required': false,
                          'hidden': false,
                          'description': 'The branch to create.',
                        },
                        'reason': {
                          'short': null,
                          'required': false,
                          'hidden': false,
                          'description': 'Why the worktree is locked.',
                        },
                      },
                      'positionals': {
                        'path': {
                          'required': true,
                          'description': 'The worktree path.',
                        },
                        'commit-ish': {
                          'required': false,
                          'description': 'The revision to check out.',
                        },
                      },
                    },
                  },
                },
                'stash': {
                  'description': 'Stash working directory changes.',
                  'commands': {
                    'push': {
                      'description': 'Stash changes in the working directory.',
                      'flags': {
                        'patch': {
                          'short': 'p',
                          'default': false,
                          'negatable': false,
                          'hidden': false,
                          'description': 'Select changes interactively.',
                        },
                        'include-untracked': {
                          'short': 'u',
                          'default': false,
                          'negatable': false,
                          'hidden': false,
                          'description': 'Include untracked files.',
                        },
                      },
                      'options': {
                        'message': {
                          'short': 'm',
                          'required': false,
                          'hidden': false,
                          'description': 'The stash message.',
                        },
                      },
                      'positionals': {
                        'pathspec': {
                          'required': false,
                          'description': 'A path to stash.',
                        },
                      },
                    },
                  },
                },
              },
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
                    name: 'sse-customer-algorithm',
                    description: 'The customer encryption algorithm.',
                    options: [
                      PairStringOption(
                        name: 'sse-customer-key',
                        description: 'The customer encryption key.',
                      ),
                      PairStringOption(
                        name: 'sse-customer-key-md5',
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
                commands: {
                  'put-object': {
                    'description': 'Add an object to an Amazon S3 bucket.',
                    'options': {
                      'sse-customer-algorithm': {
                        'short': null,
                        'required': false,
                        'hidden': false,
                        'description': 'The customer encryption algorithm.',
                      },
                      'sse-customer-key': {
                        'short': null,
                        'required': false,
                        'hidden': false,
                        'description': 'The customer encryption key.',
                      },
                      'sse-customer-key-md5': {
                        'short': null,
                        'required': false,
                        'hidden': false,
                        'description': 'The MD5 digest of the customer key.',
                      },
                    },
                  },
                },
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
                      name: 'new-branch',
                      short: 'b',
                      description: 'Create a new branch.',
                      variant: true,
                      options: [
                        PairStringOption(
                          name: 'force-new-branch',
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
                commands: {
                  'worktree': {
                    'description': 'Manage linked working trees.',
                    'commands': {
                      'add': {
                        'description': 'Create a linked working tree.',
                        'options': {
                          'new-branch': {
                            'short': 'b',
                            'required': false,
                            'hidden': false,
                            'description': 'Create a new branch.',
                            'variant': true,
                          },
                          'force-new-branch': {
                            'short': 'B',
                            'required': false,
                            'hidden': false,
                            'description': 'Create or reset a branch.',
                          },
                        },
                      },
                    },
                  },
                },
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
                  name: 'format',
                  choices: DeploymentFormat.values,
                  defaultValue: DeploymentFormat.json,
                ),
              ],
              pairedOptions: [
                PairedChoiceOption<DeploymentFormat>(
                  name: 'manifest',
                  choices: DeploymentFormat.values,
                  defaultValue: DeploymentFormat.yaml,
                  variant: true,
                  options: [
                    PairChoiceOption<DeploymentFormat>(
                      name: 'manifest-file',
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
                name: 'chunk-size',
                options: [PairDoubleOption(name: 'compression-level')],
              ),
              PairedDoubleOption(
                name: 'timeout',
                options: [PairIntOption(name: 'attempts')],
              ),
              RepeatablePairedStringOption(
                name: 'include',
                options: [RepeatablePairStringOption(name: 'include-from')],
              ),
              RepeatablePairedIntOption(
                name: 'shard',
                options: [RepeatablePairIntOption(name: 'shard-count')],
              ),
              RepeatablePairedDoubleOption(
                name: 'rate',
                options: [RepeatablePairDoubleOption(name: 'rate-limit')],
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
            flags: [BooleanFlag(name: 'dry-run', hidden: true)],
            options: [
              StringOption(name: 'token', hidden: true, regex: RegExp(r'\S+')),
            ],
            accessors: [
              AccessorListOption(
                name: 'internal',
                hidden: true,
                options: [AccessorStringOption(name: 'trace-id')],
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
      final color = BooleanFlag(name: 'color');
      final verbose = CountFlag(name: 'verbose');
      final name = StringOption(name: 'name', regex: RegExp(r'\S+'));
      final tag = RepeatableStringOption(name: 'tag');
      final source = Positional('source');
      final target = Positional('target');
      final profile = AccessorListOption(
        name: 'user',
        options: [AccessorStringOption(name: 'profile')],
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
        name: 'username',
        options: [PairStringOption(name: 'password')],
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
        name: 'username',
        options: [PairStringOption(name: 'password')],
      );

      expect(credentials.variant, isFalse);
    });

    test('supports variants for every paired option type', () {
      final variants = <PairedOption>[
        PairedStringOption(
          name: 'string',
          variant: true,
          options: [PairStringOption(name: 'stringPair')],
        ),
        PairedIntOption(
          name: 'int',
          variant: true,
          options: [PairIntOption(name: 'intPair')],
        ),
        PairedDoubleOption(
          name: 'double',
          variant: true,
          options: [PairDoubleOption(name: 'doublePair')],
        ),
        PairedChoiceOption<VariantChoice>(
          name: 'choice',
          choices: VariantChoice.values,
          variant: true,
          options: [
            PairChoiceOption<VariantChoice>(
              name: 'choicePair',
              choices: VariantChoice.values,
            ),
          ],
        ),
        RepeatablePairedStringOption(
          name: 'repeatedString',
          variant: true,
          options: [RepeatablePairStringOption(name: 'repeatedStringPair')],
        ),
        RepeatablePairedIntOption(
          name: 'repeatedInt',
          variant: true,
          options: [RepeatablePairIntOption(name: 'repeatedIntPair')],
        ),
        RepeatablePairedDoubleOption(
          name: 'repeatedDouble',
          variant: true,
          options: [RepeatablePairDoubleOption(name: 'repeatedDoublePair')],
        ),
      ];

      expect(variants.map((option) => option.variant), everyElement(isTrue));
    });

    test('rejects paired options without a paired member', () {
      expect(
        () => CommandRegistry.create(
          'login',
          'Authenticate a user.',
          pairedOptions: [PairedStringOption(name: 'username', options: [])],
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
                name: 'server',
                options: [AccessorIntOption(name: 'port')],
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
          flags: [BooleanFlag(name: 'help')],
        ),
        throwsA(isA<MambaRegistryError>()),
      );
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          flags: [BooleanFlag(name: 'custom', short: 'h')],
        ),
        throwsA(isA<MambaRegistryError>()),
      );
    });

    test('resolves the command whose help was requested', () {
      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        flags: [CountFlag(name: 'verbose', short: 'v')],
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
      final inheritedFlag = BooleanFlag(name: 'color');
      final inheritedOption = IntOption(name: 'retries');
      final localFlag = BooleanFlag(name: 'color', description: 'child');
      final localOption = IntOption(name: 'retries', description: 'child');
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
            flags: [BooleanFlag(name: 'color')],
            options: [IntOption(name: 'retries')],
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
          BooleanFlag(name: 'verbose2', short: 'v'),
          BooleanFlag(name: 'dry-run'),
        ],
        options: [
          IntOption(name: 'retry2', short: 'r'),
          IntOption(name: 'back-off'),
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
            flags: [BooleanFlag(name: name)],
          ),
          throwsA(isA<MambaRegistryError>()),
        );
        expect(
          () => CommandRegistry.create(
            'tool',
            'Tool command.',
            options: [IntOption(name: name)],
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
          flags: [BooleanFlag(name: 'verbose', short: '2')],
        ),
        throwsA(isA<MambaRegistryError>()),
      );
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          options: [IntOption(name: 'retry', short: '-')],
        ),
        throwsA(isA<MambaRegistryError>()),
      );
    });

    test('rejects invalid input and positional symbols', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          options: [StringOption(name: 'bad!', regex: RegExp(r'.+'))],
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
              name: 'server',
              options: [
                AccessorListOption(
                  name: 'authentication',
                  options: [AccessorStringOption(name: 'help')],
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
              name: 'profile',
              options: [AccessorStringOption(name: 'value')],
            ),
          ],
          flags: [BooleanFlag(name: 'profile')],
        ),
        throwsA(isA<MambaException>()),
      );
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          accessors: [
            AccessorListOption(
              name: 'profile',
              options: [AccessorStringOption(name: 'value')],
            ),
          ],
          options: [StringOption(name: 'profile', regex: RegExp(r'.+'))],
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
          flags: [BooleanFlag(name: 'verbose')],
          options: [IntOption(name: 'verbose')],
        ),
        throwsA(isA<MambaException>()),
      );
    });

    test('rejects conflicting short aliases', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          flags: [BooleanFlag(name: 'verbose', short: 'v')],
          options: [IntOption(name: 'version', short: 'v')],
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
          flags: [
            BooleanFlag(name: 'verbose'),
            BooleanFlag(name: 'verbose'),
          ],
        ),
        throwsA(isA<MambaException>()),
      );
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          options: [
            StringOption(name: 'name', regex: RegExp(r'\S+')),
            RepeatableStringOption(name: 'name'),
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
              name: 'remote',
              options: [
                AccessorStringOption(name: 'url'),
                AccessorStringOption(name: 'url'),
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
