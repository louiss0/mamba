import 'dart:io';

import 'package:mamba/errors.dart';
import 'package:mamba/registry.dart';

/// Base for checked-in completion converters.
abstract class RegistryRecordConverter {
  RegistryRecordConverter(this.registry);
  final RegistryRecord registry;
  String convert();
  Iterable<RegistryOption> get options sync* {
    yield* registry.options ?? const [];
    for (final command in registry.commands ?? const <RegistryCommand>[])
      yield* command.options ?? const [];
  }
}

/// Shell converters intentionally consume registry metadata only; command input
/// values never cross this serializable boundary.
final class ToBashCompletionConverter extends RegistryRecordConverter {
  ToBashCompletionConverter(super.registry);
  @override
  String convert() =>
      '# bash completion for ${registry.name}\n_${registry.name}_completion() { :; }\ncomplete -F _${registry.name}_completion ${registry.name}\n';
}

final class ToZshCompletionConverter extends RegistryRecordConverter {
  ToZshCompletionConverter(super.registry);
  @override
  String convert() =>
      '#compdef ${registry.name}\n_${registry.name}() { _arguments ${_options()} }\ncompdef _${registry.name} ${registry.name}\n';
  String _options() => [
    for (final option in options)
      "'--${option.name}[${option.description ?? ''}]'",
  ].join(' ');
}

final class ToFishCompletionConverter extends RegistryRecordConverter {
  ToFishCompletionConverter(super.registry);
  @override
  String convert() =>
      [
        for (final option in options)
          'complete -c ${registry.name} -l ${option.name}${option.unique == true ? " -n \"not __mamba_seen_${option.name}\"" : ""}',
      ].join('\n') +
      '\n';
}

final class ToPowerShellCompletionConverter extends RegistryRecordConverter {
  ToPowerShellCompletionConverter(super.registry);
  @override
  String convert() =>
      "Register-ArgumentCompleter -CommandName '${registry.name}' -ScriptBlock { param(\$wordToComplete) }\n";
}

final class CarapaceSpecConverter extends RegistryRecordConverter {
  CarapaceSpecConverter(super.registry);
  @override
  String convert() {
    final lines = <String>['name: ${registry.name}', 'flags:'];
    for (final option in options) {
      lines.add('  --${option.name}${option.repeatable == true ? '*' : ''}:');
      if (option.choices case final choices?)
        lines.add('    completion: [${choices.join(', ')}]');
    }
    return '${lines.join('\n')}\n';
  }
}

/// Writes the selected integration artifact to disk.
final class CarapaceSpecWriter {
  CarapaceSpecWriter(this.path);
  final String path;
  void write(RegistryRecord registry) {
    try {
      File(path).writeAsStringSync(CarapaceSpecConverter(registry).convert());
    } on FileSystemException catch (error) {
      throw MambaIntegrationException(error.message);
    }
  }
}
