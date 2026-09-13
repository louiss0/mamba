import 'package:mamba/registry.dart';

abstract interface class HelpFormatter {
  String format(CommandRegistry registry);
}

/// Renders the registry metadata without exposing parsed runtime values.
final class MambaHelpFormatter implements HelpFormatter {
  @override
  String format(CommandRegistry registry) {
    final lines = <String>[
      registry.fullPath.join(' '),
      "  '${registry.shortDescription}'",
      '',
      'Usage:',
      '  ${registry.fullPath.join(' ')}${_usage(registry)}',
    ];
    if (registry.commandRegistries.isNotEmpty) {
      lines.addAll(['', 'Commands:']);
      for (final command in registry.commandRegistries) {
        lines.add('  ${command.name}\t${command.shortDescription}');
      }
    }
    final flags = registry.applicableFlags.where((flag) => !flag.hidden);
    if (flags.isNotEmpty) {
      lines.addAll(['', 'Flags:']);
      for (final flag in flags) {
        lines.add(
          '  ${_spell(flag.name, flag.short)}\t${flag.description ?? ''}',
        );
      }
    }
    final options = registry.applicableOptions.where(
      (option) => !option.hidden,
    );
    if (options.isNotEmpty) {
      lines.addAll(['', 'Options:']);
      for (final option in options) {
        lines.add(
          '  ${_spell(option.name, option.short)} <value>\t${option.description ?? ''}',
        );
      }
    }
    for (final group in registry.pairedOptionGroups) {
      lines.add(
        '  ${group.options.map((item) => '--${item.name}').join(' & ')}',
      );
    }
    for (final group in registry.selectedOptionses) {
      lines.add(
        '  ${group.options.map((item) => '--${item.name}').join(' * ')}',
      );
    }
    return lines.join('\n');
  }

  String _usage(CommandRegistry registry) {
    final positionals = [
      ...registry.mandatoryPositionals.map((input) => ' <${input.name}>'),
      ...registry.discretionaryPositionals.map((input) => ' [${input.name}]'),
    ].join();
    return ' [options]$positionals';
  }

  String _spell(String name, String? short) =>
      short == null ? '--$name' : '-$short, --$name';
}
