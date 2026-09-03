import 'dart:async';
import 'dart:convert';

import 'package:mamba/mamba.dart';

enum _OutputFormat { text, json, yaml }

enum _VolumeTarget { output, input }

enum _PowerAction { lock, sleep, hibernate, restart, shutdown }

enum _ProcessAction { inspect, limit, kill, priority }

enum _CleanTarget { cache, logs, temp, thumbnails, downloads, trash }

enum _CompletionShell { carapace, bash, fish, zsh, powershell }

final class _RigMockState {
  final profiles = <String>{'balanced', 'gaming', 'quiet'};
}

typedef _CommandHandler =
    FutureOr<String?> Function(
      ParsedPositionals positionals,
      ParsedNamedInputs inputs,
      List<String> trailingArguments,
    );

/// A small adapter keeps the fixture's command declarations readable while
/// leaving all argument parsing and validation to Mamba.
final class _MockCommand extends Command {
  _MockCommand(
    this.name,
    this.shortDescription, {
    required this.handler,
    super.aliases,
    super.mandatoryPositionals,
    super.flags,
    super.options,
    super.accessors,
  });

  @override
  final String name;
  @override
  final String shortDescription;
  final _CommandHandler handler;

  @override
  FutureOr<String?> run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  ) => handler(positionals, inputs, trailingArguments);
}

final class _RigCompletionCommand extends CompletionCommand {
  _RigCompletionCommand()
    : super(
        longDescription:
            'Print a generated completion artifact to standard output. The command\n'
            'never writes files; redirect its output explicitly if desired.',
        options: [
          ChoiceOption<_CompletionShell>(
            'shell',
            choices: _CompletionShell.values,
            defaultValue: _CompletionShell.carapace,
            description: 'Completion artifact format to print to stdout.',
          ),
        ],
      );

  @override
  String get name => 'completion';

  @override
  String get shortDescription =>
      'Generate a completion artifact without writing files.';

  @override
  String run(_, ParsedNamedInputs inputs, _) {
    final shell = inputs.stringOptions?['shell'] ?? 'carapace';
    final completion = switch (shell) {
      'carapace' => CarapaceSpecConverter(registryMap).convert(),
      'bash' => ToBashCompletionConverter(registryMap).convert(),
      'fish' => ToFishCompletionConverter(registryMap).convert(),
      'zsh' => ToZshCompletionConverter(registryMap).convert(),
      'powershell' => ToPowerShellCompletionConverter(registryMap).convert(),
      _ => throw MambaException('Unsupported completion shell: $shell'),
    };
    return completion.trimRight();
  }
}

final class _MockGroup extends GroupCommand {
  _MockGroup(
    this.name,
    this.shortDescription, {
    required List<Command> commands,
    required this.groupHelp,
    String? longDescription,
    List<String>? aliases,
  }) : super(commands, longDescription: longDescription, aliases: aliases);

  @override
  final String name;
  @override
  final String shortDescription;
  final String groupHelp;

  @override
  String run(ParsedPositionals _, ParsedNamedInputs __, List<String> ___) =>
      groupHelp;
}

const _rigDescription =
    'A mock workstation-control CLI for harmless terminal simulations.';
const _rigLongDescription =
    'rig only prints simulated operations. It never changes, inspects,\n'
    'connects to, or otherwise affects the computer.';

List<Command> _rigCommands(_RigMockState state) => [
  _volumeCommand(),
  _brightnessCommand(),
  _powerCommand(),
  _processCommand(),
  _cleanCommand(),
  _RigCompletionCommand(),
  _networkGroup(),
  _profileGroup(state),
];

List<Option> _rigOptions() => [
  ChoiceOption<_OutputFormat>(
    'format',
    choices: _OutputFormat.values,
    defaultValue: _OutputFormat.text,
    description: 'Simulated output format: text, json, or yaml.',
  ),
];

/// Builds a fresh, entirely in-memory `rig` executor for production or tests.
Executor createRigExecutor() {
  final state = _RigMockState();
  return Executor(
    'rig',
    _rigDescription,
    _rigCommands(state),
    longDescription: _rigLongDescription,
    options: _rigOptions(),
  );
}

/// Returns the complete registry used to generate fixture completions.
RegistryMap createRigRegistryMap() => CommandRegistry.create(
  'rig',
  _rigDescription,
  longDescription: _rigLongDescription,
  flags: [
    BooleanFlag(
      'dry-run',
      description: 'Show what would happen without changing anything.',
    ),
    CountFlag('verbose', short: 'v', description: 'Increase output verbosity.'),
  ],
  options: _rigOptions(),
  commands: _rigCommands(_RigMockState()),
).toMap();

Future<void> main(List<String> args) =>
    createRigExecutor().create().execute(args);

_MockCommand _volumeCommand() => _MockCommand(
  'volume',
  'Describe simulated audio input and output operations.',
  aliases: ['vol'],
  mandatoryPositionals: [
    ChoicePositional<_VolumeTarget>(
      'target',
      choices: _VolumeTarget.values,
      description: 'Simulated audio target.',
    ),
  ],
  flags: [
    BooleanFlag('mute', short: 'm', description: 'Mute the simulated target.'),
    BooleanFlag(
      'unmute',
      short: 'u',
      description: 'Unmute the simulated target.',
    ),
  ],
  options: [
    StringOption(
      'device',
      short: 'd',
      description: 'Simulated audio device name.',
      regex: RegExp(r'.+'),
    ),
    IntOption(
      'level',
      short: 'l',
      min: 0,
      max: 100,
      description: 'Simulated volume level, from 0 through 100.',
    ),
    DoubleOption(
      'balance',
      short: 'b',
      min: -1,
      max: 1,
      description: 'Simulated stereo balance, from -1.0 through 1.0.',
    ),
    RepeatableStringOption(
      'channel',
      description: 'Repeatable simulated audio channel name.',
    ),
    RepeatableDoubleOption(
      'channel-gain',
      min: 0,
      max: 2,
      description: 'Repeatable channel gain, from 0.0 through 2.0.',
    ),
  ],
  handler: (positionals, inputs, _) {
    final target = positionals.singles!['target']!;
    final mute = inputs.boolFlags?['mute'] == true;
    final unmute = inputs.boolFlags?['unmute'] == true;
    if (mute && unmute) {
      throw const MambaException(
        'rig volume cannot use --mute and --unmute together.',
      );
    }

    final channels = inputs.repeatedStringOptions?['channel'] ?? const [];
    final gains = inputs.repeatedDoubleOptions?['channel-gain'] ?? const [];
    if (gains.isNotEmpty && channels.isEmpty) {
      throw const MambaException(
        'rig volume --channel-gain requires at least one --channel.',
      );
    }
    if (gains.length > channels.length) {
      throw MambaException(
        'rig volume received ${gains.length} channel gains for '
        '${channels.length} channels; provide a matching value for each channel.',
      );
    }

    final device = inputs.stringOptions?['device'];
    final parameters = <String, dynamic>{
      'target': target,
      if (device != null) 'device': device,
      if (inputs.intOptions?['level'] case final level?) 'level': level,
      if (inputs.doubleOptions?['balance'] case final balance?)
        'balance': balance,
      if (channels.isNotEmpty) 'channels': channels,
      if (gains.isNotEmpty) 'channel_gains': gains,
      if (mute) 'muted': true,
      if (unmute) 'muted': false,
    };
    final targetLabel = device == null
        ? 'simulated $target'
        : 'simulated $target device "$device"';
    final details = <String>[];
    if (inputs.intOptions?['level'] case final level?) {
      details.add('set $targetLabel volume to $level%');
    }
    if (inputs.doubleOptions?['balance'] case final balance?) {
      details.add('set balance to $balance');
    }
    if (mute) details.add('mute $targetLabel');
    if (unmute) details.add('unmute $targetLabel');
    if (channels.isNotEmpty) {
      final channelText = [
        for (var index = 0; index < channels.length; index++)
          gains.length > index
              ? '${channels[index]}=${gains[index]}'
              : channels[index],
      ].join(', ');
      details.add('describe channels $channelText');
    }
    if (details.isEmpty) details.add('inspect $targetLabel');
    return _renderResult(
      inputs,
      operation: 'volume',
      parameters: parameters,
      message: 'would ${details.join('; ')}',
    );
  },
);

_MockCommand _brightnessCommand() => _MockCommand(
  'brightness',
  'Describe simulated display brightness and visual properties.',
  aliases: ['bright'],
  options: [
    RepeatableStringOption(
      'display',
      short: 'd',
      description: 'Repeatable simulated display name.',
    ),
    IntOption(
      'level',
      short: 'l',
      min: 0,
      max: 100,
      description: 'Brightness percentage, from 0 through 100.',
    ),
    DoubleOption(
      'gamma',
      short: 'g',
      min: .5,
      max: 3,
      description: 'Display gamma, from 0.5 through 3.0.',
    ),
    IntOption(
      'temperature',
      short: 't',
      min: 1000,
      max: 10000,
      description: 'Color temperature in simulated Kelvin.',
    ),
    DoubleOption(
      'contrast',
      min: 0,
      max: 2,
      description: 'Contrast multiplier, from 0.0 through 2.0.',
    ),
  ],
  handler: (_, inputs, _) {
    final displays = inputs.repeatedStringOptions?['display'] ?? const [];
    final selected = displays.isEmpty
        ? 'the default simulated display set'
        : 'simulated displays ${_joinHuman(displays, quote: true)}';
    final parameters = <String, dynamic>{
      'displays': displays.isEmpty ? ['default'] : displays,
      if (inputs.intOptions?['level'] case final level?) 'level': level,
      if (inputs.doubleOptions?['gamma'] case final gamma?) 'gamma': gamma,
      if (inputs.intOptions?['temperature'] case final temperature?)
        'temperature_kelvin': temperature,
      if (inputs.doubleOptions?['contrast'] case final contrast?)
        'contrast': contrast,
    };
    final properties = <String>[];
    if (inputs.intOptions?['level'] case final level?)
      properties.add('brightness $level%');
    if (inputs.doubleOptions?['gamma'] case final gamma?)
      properties.add('gamma $gamma');
    if (inputs.intOptions?['temperature'] case final temperature?)
      properties.add('temperature ${temperature}K');
    if (inputs.doubleOptions?['contrast'] case final contrast?)
      properties.add('contrast $contrast');
    final action = properties.isEmpty
        ? 'describe $selected'
        : 'set $selected to ${_joinHuman(properties)}';
    return _renderResult(
      inputs,
      operation: 'brightness',
      parameters: parameters,
      message: 'would $action',
    );
  },
);

_MockCommand _powerCommand() => _MockCommand(
  'power',
  'Describe a simulated workstation power action.',
  aliases: ['pwr'],
  mandatoryPositionals: [
    ChoicePositional<_PowerAction>(
      'action',
      choices: _PowerAction.values,
      description: 'Simulated power action.',
    ),
  ],
  flags: [
    BooleanFlag(
      'force',
      short: 'f',
      description:
          'Describe simulated force behavior without bypassing safety.',
    ),
  ],
  options: [
    IntOption(
      'delay',
      short: 'd',
      min: 0,
      description: 'Non-negative simulated delay in seconds.',
    ),
    StringOption(
      'reason',
      short: 'r',
      regex: RegExp(r'.+'),
      description: 'Human-readable simulated reason.',
    ),
  ],
  handler: (positionals, inputs, _) {
    final action = positionals.singles!['action']!;
    final delay = inputs.intOptions?['delay'] ?? 0;
    final reason = inputs.stringOptions?['reason'];
    final force = inputs.boolFlags?['force'] == true;
    final actionText = switch (action) {
      'lock' => 'lock the simulated workstation',
      'sleep' => 'put the simulated workstation to sleep',
      'hibernate' => 'hibernate the simulated workstation',
      'restart' => 'restart the simulated workstation',
      'shutdown' => 'shut down the simulated workstation',
      _ => 'perform the simulated $action action',
    };
    final parameters = <String, dynamic>{
      'action': action,
      'delay_seconds': delay,
      if (reason != null) 'reason': reason,
      if (force) 'force': true,
    };
    final message = StringBuffer('would $actionText after $delay seconds');
    if (reason != null) message.write('. Reason: $reason');
    if (force) message.write('. Simulated force behavior requested');
    message.write('. The action did not occur');
    return _renderResult(
      inputs,
      operation: 'power',
      parameters: parameters,
      message: message.toString(),
    );
  },
);

_MockCommand _processCommand() => _MockCommand(
  'process',
  'Describe simulated process inspection and control operations.',
  aliases: ['proc'],
  mandatoryPositionals: [
    ChoicePositional<_ProcessAction>(
      'action',
      choices: _ProcessAction.values,
      description: 'Simulated process action.',
    ),
  ],
  options: [
    RepeatableIntOption(
      'pid',
      min: 1,
      short: 'p',
      description: 'Repeatable simulated process ID.',
    ),
    RepeatableStringOption(
      'name',
      short: 'n',
      description: 'Repeatable simulated process name.',
    ),
    RepeatableIntOption(
      'cpu',
      min: 0,
      short: 'c',
      description: 'Repeatable simulated CPU index.',
    ),
    IntOption(
      'priority',
      description: 'Simulated process priority for the priority action.',
    ),
  ],
  accessors: [
    AccessorListOption('limit', [
      AccessorListOption('cpu', [
        AccessorDoubleOption(
          'percent',
          description: 'CPU percentage from 0 through 100.',
        ),
      ], description: 'CPU limit settings.'),
      AccessorListOption('memory', [
        AccessorIntOption('mb', description: 'Memory limit in MB.'),
      ], description: 'Memory limit settings.'),
      AccessorListOption('io', [
        AccessorDoubleOption('read', description: 'Read limit in MB/s.'),
        AccessorDoubleOption('write', description: 'Write limit in MB/s.'),
      ], description: 'I/O rate limits in MB/s.'),
    ], description: 'Hierarchical simulated process limits.'),
  ],
  handler: (positionals, inputs, _) {
    final action = positionals.singles!['action']!;
    final pids = inputs.repeatedIntOptions?['pid'] ?? const [];
    final names = inputs.repeatedStringOptions?['name'] ?? const [];
    final cpus = inputs.repeatedIntOptions?['cpu'] ?? const [];
    final priority = inputs.intOptions?['priority'];
    final limits = _nestedMap(inputs.accessors?['limit']);
    final hasLimits = limits.isNotEmpty;
    if (action != 'limit' && hasLimits) {
      throw MambaException(
        'rig process $action does not support hierarchical process limits; '
        'use `rig process limit`.',
      );
    }
    if (action != 'priority' && priority != null) {
      throw MambaException(
        'rig process $action does not support --priority; use '
        '`rig process priority`.',
      );
    }
    if (action == 'limit' && priority != null) {
      throw const MambaException(
        'rig process limit does not support --priority; use `priority` action.',
      );
    }
    for (final entry in _flattenNumericLimits(limits).entries) {
      final value = entry.value;
      if (value < 0 ||
          (entry.key == 'memory.mb' && value == 0) ||
          (entry.key == 'cpu.percent' && value > 100)) {
        throw MambaException(
          'Invalid simulated limit ${entry.key}=$value; CPU percent must be '
          '0 through 100 and memory must be greater than zero.',
        );
      }
    }

    final selectors = <String>[];
    if (pids.isNotEmpty) selectors.add('PIDs ${_joinHuman(pids)}');
    if (names.isNotEmpty)
      selectors.add('names ${_joinHuman(names, quote: true)}');
    if (cpus.isNotEmpty) selectors.add('CPUs ${_joinHuman(cpus)}');
    final target = selectors.isEmpty
        ? 'the simulated process set'
        : _joinHuman(selectors);
    final parameters = <String, dynamic>{
      'action': action,
      if (pids.isNotEmpty) 'pids': pids,
      if (names.isNotEmpty) 'names': names,
      if (cpus.isNotEmpty) 'cpus': cpus,
      if (priority != null) 'priority': priority,
      if (hasLimits) 'limits': limits,
    };
    final detail = <String>[];
    if (hasLimits) {
      if (_limitValue(limits, 'cpu', 'percent') case final value?)
        detail.add('CPU limit: $value%');
      if (_limitValue(limits, 'memory', 'mb') case final memory?)
        detail.add('Memory limit: $memory MB');
      if (_limitValue(limits, 'io', 'read') case final value?)
        detail.add('I/O read limit: $value MB/s');
      if (_limitValue(limits, 'io', 'write') case final value?)
        detail.add('I/O write limit: $value MB/s');
    }
    if (priority != null) detail.add('Priority: $priority');
    final verb = switch (action) {
      'inspect' => 'inspect',
      'limit' => 'apply simulated process limits to',
      'kill' => 'terminate',
      'priority' => 'set simulated priority for',
      _ => 'operate on',
    };
    return _renderResult(
      inputs,
      operation: 'process',
      parameters: parameters,
      message:
          'would $verb $target${detail.isEmpty ? '' : '. ${detail.join('. ')}'}',
    );
  },
);

_MockCommand _cleanCommand() => _MockCommand(
  'clean',
  'Describe simulated cleanup of selected categories.',
  aliases: ['sweep'],
  mandatoryPositionals: [
    RepeatedChoicePositional<_CleanTarget>(
      'targets',
      choices: _CleanTarget.values,
      times: 5,
      description: 'One or more simulated cleanup targets.',
    ),
  ],
  flags: [
    BooleanFlag(
      'include-hidden',
      description: 'Include simulated hidden items in the description.',
    ),
  ],
  options: [
    IntOption(
      'older-than',
      min: 0,
      description: 'Age filter in non-negative days.',
    ),
    DoubleOption(
      'larger-than',
      min: 0,
      description: 'Size threshold in non-negative MB.',
    ),
    RepeatableStringOption(
      'exclude',
      description: 'Repeatable simulated category, path, or pattern exclusion.',
    ),
  ],
  handler: (positionals, inputs, _) {
    final targets = positionals.repeated!['targets']!;
    final olderThan = inputs.intOptions?['older-than'];
    final largerThan = inputs.doubleOptions?['larger-than'];
    final excludes = inputs.repeatedStringOptions?['exclude'] ?? const [];
    final hidden = inputs.boolFlags?['include-hidden'] == true;
    final parameters = <String, dynamic>{
      'targets': targets,
      if (olderThan != null) 'older_than_days': olderThan,
      if (largerThan != null) 'larger_than_mb': largerThan,
      if (excludes.isNotEmpty) 'exclude': excludes,
      'include_hidden': hidden,
      'estimated_data_affected_mb': 384.0,
    };
    final filters = <String>[];
    if (olderThan != null) filters.add('older than $olderThan days');
    if (largerThan != null) filters.add('larger than $largerThan MB');
    if (excludes.isNotEmpty) {
      filters.add('excluding ${_joinHuman(excludes, quote: true)}');
    }
    if (hidden) filters.add('including hidden items');
    final filterText = filters.isEmpty ? '' : ' ${filters.join(' and ')}';
    return _renderResult(
      inputs,
      operation: 'clean',
      parameters: parameters,
      message:
          'would simulate cleaning ${_joinHuman(targets)} items$filterText; '
          'estimated simulated impact: 384.0 MB',
      noChangeStatement: 'No files were changed.',
    );
  },
);

_MockGroup _networkGroup() => _MockGroup(
  'network',
  'Organize simulated networking commands; no traffic is sent.',
  aliases: ['net'],
  groupHelp: '''rig network  'Organize simulated networking commands.'

Network operations are simulations only; no connections, DNS lookups, or traffic occur.

Commands:
  wifi    Describe simulated Wi-Fi operations.
  dns     Describe simulated DNS configuration.
  proxy   Describe simulated proxy configuration.
  ping    Describe mock connectivity measurements.

Use `rig network <command> --help` for command-specific options.''',
  commands: [_wifiGroup(), _dnsGroup(), _proxyCommand(), _pingCommand()],
);

_MockGroup _wifiGroup() => _MockGroup(
  'wifi',
  'Describe simulated Wi-Fi operations.',
  groupHelp: '''rig network wifi  'Describe simulated Wi-Fi operations.'

The Wi-Fi command never connects, disconnects, scans, or inspects real networks.

Commands:
  connect      Describe a simulated Wi-Fi connection.
  disconnect   Describe a simulated Wi-Fi disconnection.
  scan         Describe a simulated Wi-Fi scan.
  status       Describe simulated Wi-Fi status.''',
  commands: [
    _MockCommand(
      'connect',
      'Describe connecting to a simulated Wi-Fi network.',
      options: [
        StringOption(
          'ssid',
          required: true,
          description: 'Simulated network name.',
          regex: RegExp(r'.+'),
        ),
        StringOption(
          'password',
          description: 'Masked simulated password; it is never printed.',
          regex: RegExp(r'.+'),
        ),
        IntOption(
          'channel',
          min: 1,
          max: 196,
          description: 'Simulated Wi-Fi channel.',
        ),
      ],
      flags: [
        BooleanFlag(
          'hidden',
          description: 'Describe a hidden simulated network.',
        ),
      ],
      handler: (_, inputs, _) {
        final ssid = inputs.stringOptions!['ssid']!;
        final parameters = <String, dynamic>{
          'ssid': ssid,
          if (inputs.intOptions?['channel'] case final channel?)
            'channel': channel,
          if (inputs.boolFlags?['hidden'] == true) 'hidden': true,
          if (inputs.stringOptions?['password'] != null) 'password': '[masked]',
        };
        return _renderResult(
          inputs,
          operation: 'network wifi connect',
          parameters: parameters,
          message: 'would connect to simulated Wi-Fi network "$ssid"',
          noChangeStatement: 'No network connection was made.',
        );
      },
    ),
    _MockCommand(
      'disconnect',
      'Describe disconnecting from a simulated Wi-Fi network.',
      options: [
        StringOption(
          'ssid',
          description: 'Optional simulated network name.',
          regex: RegExp(r'.+'),
        ),
      ],
      handler: (_, inputs, _) {
        final ssid = inputs.stringOptions?['ssid'];
        return _renderResult(
          inputs,
          operation: 'network wifi disconnect',
          parameters: {if (ssid != null) 'ssid': ssid},
          message:
              'would disconnect from ${ssid == null ? 'the simulated Wi-Fi network' : 'simulated Wi-Fi network "$ssid"'}',
          noChangeStatement: 'No network connection was changed.',
        );
      },
    ),
    _MockCommand(
      'scan',
      'Describe scanning simulated Wi-Fi results.',
      options: [
        IntOption(
          'channel',
          min: 1,
          max: 196,
          description: 'Optional simulated channel filter.',
        ),
      ],
      flags: [
        BooleanFlag(
          'hidden',
          description: 'Include hidden simulated networks.',
        ),
      ],
      handler: (_, inputs, _) => _renderResult(
        inputs,
        operation: 'network wifi scan',
        parameters: {
          if (inputs.intOptions?['channel'] case final channel?)
            'channel': channel,
          'include_hidden': inputs.boolFlags?['hidden'] == true,
          'networks': const ['ExampleNet', 'MockGuest'],
        },
        message: 'would scan simulated Wi-Fi networks',
        noChangeStatement: 'No network scan occurred.',
      ),
    ),
    _MockCommand(
      'status',
      'Describe simulated Wi-Fi status.',
      handler: (_, inputs, _) => _renderResult(
        inputs,
        operation: 'network wifi status',
        parameters: const {
          'connected': false,
          'network': null,
          'note': 'fixed mock status',
        },
        message: 'would report simulated Wi-Fi status: disconnected',
        noChangeStatement: 'No network state was inspected.',
      ),
    ),
  ],
);

_MockGroup _dnsGroup() => _MockGroup(
  'dns',
  'Describe simulated DNS configuration.',
  groupHelp: '''rig network dns  'Describe simulated DNS configuration.'

Commands:
  get      Show fixed simulated DNS configuration.
  set      Describe ordered simulated DNS servers.
  reset    Describe restoring simulated platform defaults.''',
  commands: [
    _MockCommand(
      'get',
      'Show fixed simulated DNS configuration.',
      options: [
        StringOption(
          'interface',
          description: 'Simulated network interface.',
          regex: RegExp(r'.+'),
        ),
      ],
      handler: (_, inputs, _) => _renderResult(
        inputs,
        operation: 'network dns get',
        parameters: {
          if (inputs.stringOptions?['interface'] case final interface?)
            'interface': interface,
          'servers': const ['1.1.1.1', '1.0.0.1'],
          'source': 'fixed mock configuration',
        },
        message: 'would show simulated DNS servers 1.1.1.1 and 1.0.0.1',
        noChangeStatement: 'No network settings were changed.',
      ),
    ),
    _MockCommand(
      'set',
      'Describe configuring simulated DNS servers.',
      options: [
        RepeatableStringOption(
          'server',
          required: true,
          description: 'Repeatable simulated DNS server in preserved order.',
          regex: RegExp(r'.+'),
        ),
        StringOption(
          'interface',
          description: 'Simulated network interface.',
          regex: RegExp(r'.+'),
        ),
      ],
      handler: (_, inputs, _) {
        final servers = inputs.repeatedStringOptions!['server']!;
        final interface = inputs.stringOptions?['interface'];
        return _renderResult(
          inputs,
          operation: 'network dns set',
          parameters: {
            'servers': servers,
            if (interface != null) 'interface': interface,
          },
          message:
              'would configure simulated DNS servers in this order: ${servers.join(', ')}',
          noChangeStatement: 'No network settings were changed.',
        );
      },
    ),
    _MockCommand(
      'reset',
      'Describe restoring simulated DNS defaults.',
      options: [
        StringOption(
          'interface',
          description: 'Simulated network interface.',
          regex: RegExp(r'.+'),
        ),
      ],
      handler: (_, inputs, _) => _renderResult(
        inputs,
        operation: 'network dns reset',
        parameters: {
          if (inputs.stringOptions?['interface'] case final interface?)
            'interface': interface,
          'mode': 'simulated platform defaults',
        },
        message: 'would restore simulated DNS platform-default behavior',
        noChangeStatement: 'No network settings were changed.',
      ),
    ),
  ],
);

_MockCommand _proxyCommand() => _MockCommand(
  'proxy',
  'Describe simulated HTTP, HTTPS, and SOCKS proxy settings.',
  accessors: [
    AccessorListOption('http', [
      AccessorStringOption('host', description: 'HTTP proxy host.'),
      AccessorIntOption('port', description: 'HTTP TCP port.'),
    ], description: 'HTTP proxy settings.'),
    AccessorListOption('https', [
      AccessorStringOption('host', description: 'HTTPS proxy host.'),
      AccessorIntOption('port', description: 'HTTPS TCP port.'),
    ], description: 'HTTPS proxy settings.'),
    AccessorListOption('socks', [
      AccessorStringOption('host', description: 'SOCKS proxy host.'),
      AccessorIntOption('port', description: 'SOCKS TCP port.'),
    ], description: 'SOCKS proxy settings.'),
  ],
  handler: (_, inputs, _) {
    final protocols = <String, dynamic>{};
    for (final protocol in ['http', 'https', 'socks']) {
      final settings = _nestedMap(inputs.accessors?[protocol]);
      if (settings.isEmpty) continue;
      final host = settings['host'];
      final port = settings['port'];
      if (host == null || port == null) {
        throw MambaException(
          'rig network proxy requires --$protocol.host and '
          '--$protocol.port together.',
        );
      }
      if (port is! int || port < 1 || port > 65535) {
        throw MambaException(
          'Invalid --$protocol.port value $port; accepted TCP port range is 1 through 65535.',
        );
      }
      protocols[protocol] = {'host': host, 'port': port};
    }
    return _renderResult(
      inputs,
      operation: 'network proxy',
      parameters: protocols,
      message: protocols.isEmpty
          ? 'would describe simulated proxy settings'
          : 'would configure simulated ${protocols.entries.map((entry) => '${entry.key.toUpperCase()} ${entry.value['host']}:${entry.value['port']}').join(' and ')}',
      noChangeStatement: 'No proxy settings were changed.',
    );
  },
);

_MockCommand _pingCommand() => _MockCommand(
  'ping',
  'Describe mock connectivity measurements without sending traffic.',
  mandatoryPositionals: [
    Positional(
      'host',
      description: 'Hostname or address represented by the mock test.',
      regex: RegExp(r'.+'),
    ),
  ],
  options: [
    IntOption(
      'count',
      min: 1,
      description: 'Positive number of simulated requests.',
    ),
    DoubleOption(
      'timeout',
      min: 0,
      description: 'Positive simulated timeout in seconds.',
    ),
  ],
  handler: (positionals, inputs, _) {
    final host = positionals.singles!['host']!;
    final count = inputs.intOptions?['count'] ?? 4;
    final timeout = inputs.doubleOptions?['timeout'] ?? 2.0;
    if (timeout <= 0) {
      throw MambaException(
        'rig network ping --timeout must be greater than zero seconds (received $timeout).',
      );
    }
    final measurements = [
      for (var index = 0; index < count; index++)
        {
          'sequence': index + 1,
          'latency_ms': 12.5 + index * 1.25,
          'failed': false,
        },
    ];
    return _renderResult(
      inputs,
      operation: 'network ping',
      parameters: {
        'host': host,
        'count': count,
        'timeout_seconds': timeout,
        'measurements': measurements,
      },
      message:
          'would perform $count simulated ping request${count == 1 ? '' : 's'} to "$host"; mock latency 12.5–${12.5 + (count - 1) * 1.25} ms, failures 0',
      noChangeStatement: 'No network requests were sent.',
    );
  },
);

_MockGroup _profileGroup(_RigMockState state) => _MockGroup(
  'profile',
  'Manage reusable simulated workstation configurations.',
  aliases: ['preset'],
  groupHelp:
      '''rig profile  'Manage reusable simulated workstation configurations.'

Profiles are fixed in-memory mock data and are never written to disk.

Commands:
  save     Capture the current simulated configuration.
  apply    Describe applying a simulated profile.
  remove   Describe removing an in-memory simulated profile.
  list     List simulated profiles.''',
  commands: [
    _MockCommand(
      'save',
      'Describe saving the current simulated configuration.',
      mandatoryPositionals: [_profileNamePositional()],
      handler: (positionals, inputs, _) {
        final name = positionals.singles!['name']!;
        if (state.profiles.contains(name)) {
          throw MambaException(
            'Simulated profile "$name" already exists; choose another name.',
          );
        }
        state.profiles.add(name);
        return _renderResult(
          inputs,
          operation: 'profile save',
          parameters: {'name': name},
          message:
              'would save simulated workstation configuration as profile "$name"',
          noChangeStatement: 'No profile was persisted.',
        );
      },
    ),
    _MockCommand(
      'apply',
      'Describe applying a simulated profile.',
      mandatoryPositionals: [_profileNamePositional()],
      flags: [
        BooleanFlag(
          'force',
          description:
              'Describe simulated force behavior without bypassing safety.',
        ),
      ],
      options: [
        RepeatableStringOption(
          'only',
          description: 'Repeatable simulated section to include.',
        ),
        RepeatableStringOption(
          'except',
          description: 'Repeatable simulated section to exclude.',
        ),
      ],
      handler: (positionals, inputs, _) {
        final name = positionals.singles!['name']!;
        if (!state.profiles.contains(name)) {
          throw MambaException('Simulated profile "$name" does not exist.');
        }
        final only = inputs.repeatedStringOptions?['only'] ?? const [];
        final except = inputs.repeatedStringOptions?['except'] ?? const [];
        if (only.isNotEmpty && except.isNotEmpty) {
          throw const MambaException(
            'rig profile apply cannot combine --only and --except; choose one selection strategy.',
          );
        }
        const validSections = {
          'volume',
          'brightness',
          'network',
          'process',
          'power',
        };
        for (final section in [...only, ...except]) {
          if (!validSections.contains(section)) {
            throw MambaException(
              'Invalid profile section "$section"; choose from ${validSections.join(', ')}.',
            );
          }
        }
        final sections = only.isNotEmpty
            ? only
            : except.isNotEmpty
            ? [
                'volume',
                'brightness',
                'network',
                'process',
                'power',
              ].where((section) => !except.contains(section)).toList()
            : validSections.toList();
        return _renderResult(
          inputs,
          operation: 'profile apply',
          parameters: {
            'name': name,
            'sections': sections,
            if (only.isNotEmpty) 'only': only,
            if (except.isNotEmpty) 'except': except,
            if (inputs.boolFlags?['force'] == true) 'force': true,
          },
          message:
              'would apply simulated profile "$name" to ${_joinHuman(sections)}',
          noChangeStatement: 'No workstation settings were changed.',
        );
      },
    ),
    _MockCommand(
      'remove',
      'Describe removing an in-memory simulated profile.',
      mandatoryPositionals: [_profileNamePositional()],
      flags: [
        BooleanFlag(
          'force',
          short: 'f',
          description: 'Confirm simulated profile removal.',
        ),
      ],
      handler: (positionals, inputs, _) {
        final name = positionals.singles!['name']!;
        if (!state.profiles.contains(name)) {
          throw MambaException('Simulated profile "$name" does not exist.');
        }
        state.profiles.remove(name);
        return _renderResult(
          inputs,
          operation: 'profile remove',
          parameters: {
            'name': name,
            'force': inputs.boolFlags?['force'] == true,
          },
          message: 'would remove simulated profile "$name"',
          noChangeStatement: 'No workstation settings were changed.',
        );
      },
    ),
    _MockCommand(
      'list',
      'List fixed in-memory simulated profiles.',
      handler: (_, inputs, _) => _renderResult(
        inputs,
        operation: 'profile list',
        parameters: {
          'profiles': state.profiles.toList()..sort(),
          'source': 'in-memory mock data',
        },
        message:
            'would list simulated profiles: ${state.profiles.toList()..sort()}',
        noChangeStatement: 'No profiles were loaded from the real system.',
      ),
    ),
  ],
);

Positional _profileNamePositional() => Positional(
  'name',
  description:
      'Profile name (letters, numbers, dots, underscores, or hyphens).',
  regex: RegExp(r'[A-Za-z0-9][A-Za-z0-9._-]*'),
);

String _renderResult(
  ParsedNamedInputs inputs, {
  required String operation,
  required Map<String, dynamic> parameters,
  required String message,
  String noChangeStatement = 'No changes were made.',
}) {
  final format = inputs.stringOptions?['format'] ?? 'text';
  final dryRun = inputs.boolFlags?['dry-run'] == true;
  final verbosity = inputs.countFlags?['verbose'] ?? 0;
  final structured = <String, dynamic>{
    'mock': true,
    'changes_made': false,
    'operation': operation,
    'parameters': parameters,
    'message': message,
    if (dryRun) 'dry_run': true,
  };
  if (verbosity > 0) {
    structured['diagnostics'] = {
      'verbosity': verbosity,
      'parser': 'Mamba validated input; no system APIs were called',
      'sensitive_values': 'redacted',
    };
  }
  if (format == 'json') return jsonEncode(structured);
  if (format == 'yaml') return YamlWriter().write(structured);

  final output = StringBuffer('Mock operation: $message. $noChangeStatement');
  if (dryRun) {
    output.write(
      ' Dry run: this is a simulation only; no changes would be made.',
    );
  }
  if (verbosity > 0) {
    output.write(
      '\nSimulation detail: verbosity $verbosity; all targets and values are mock data.',
    );
  }
  if (verbosity > 1) {
    output.write(
      '\nSimulation diagnostic: parser accepted the declared command hierarchy; no system APIs were called.',
    );
  }
  return output.toString();
}

String _joinHuman(Iterable<Object?> values, {bool quote = false}) {
  final rendered = values
      .map((value) => quote ? '"$value"' : '$value')
      .toList();
  if (rendered.length < 2) return rendered.singleOrNull ?? '';
  if (rendered.length == 2) return '${rendered[0]} and ${rendered[1]}';
  return '${rendered.take(rendered.length - 1).join(', ')}, and ${rendered.last}';
}

Map<String, dynamic> _nestedMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

Map<String, num> _flattenNumericLimits(Map<String, dynamic> limits) {
  final values = <String, num>{};
  if (_limitValue(limits, 'cpu', 'percent') case final value?) {
    values['cpu.percent'] = value;
  }
  if (_limitValue(limits, 'memory', 'mb') case final memory?) {
    values['memory.mb'] = memory;
  }
  if (_limitValue(limits, 'io', 'read') case final value?) {
    values['io.read'] = value;
  }
  if (_limitValue(limits, 'io', 'write') case final value?) {
    values['io.write'] = value;
  }
  return values;
}

num? _limitValue(Map<String, dynamic> values, String group, String name) {
  final groupValues = _nestedMap(values[group]);
  final value = groupValues[name];
  return value is num ? value : null;
}
