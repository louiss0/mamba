import 'dart:io';

import 'package:mamba/command.dart';
import 'package:mamba/errors.dart';
import 'package:mamba/integrations.dart' as integrations;
import 'package:mamba/registry.dart';

enum ShellCompletion { bash, zsh, fish, powershell, carapace }

class CompletionCommand extends Command {
  late RegistryRecord registryRecord;
  final void Function(String path) createFile;
  final bool _usesDefaultGenerator;
  @override
  String get name => 'completion';
  @override
  String get shortDescription => 'Generate completion for various shells';
  new({
    void Function(String)? createFile,
    super.longDescription,
    super.aliases,
    super.mandatoryPositionals,
    super.discretionaryPositionals,
    super.options,
  }) : createFile = createFile ?? _createFileSynchronously,
       _usesDefaultGenerator = createFile == null;
  new preset({
    required void Function(String path)? createFile,
    String? longDescription,
  }) : this(
         createFile: createFile,
         longDescription:
             longDescription ??
             'Generate completions for Bash ZSH Fish or Powershell',
         aliases: ['cmp', 'cpt'],
         mandatoryPositionals: [shellInput],
         discretionaryPositionals: [pathInput],
       );
  @override
  String? run(ParsedInputs inputs, List<String> args) {
    final shell = inputs.valueOf(shellInput);
    final path = inputs.valueOf(pathInput) ?? '';
    final extension = _extensionFor(shell);
    if (path.isNotEmpty && !_isValidPath(path, extension)) {
      throw MambaException(
        'When shell is ${shell.name} the path must end in $extension and must have ${registryRecord.name} in the file name',
      );
    }
    if (_usesDefaultGenerator) {
      File(path).writeAsStringSync(_completionFor(shell));
    } else {
      createFile(path);
    }
    return 'Created completion ${shell.name} in $path';
  }

  String _completionFor(ShellCompletion shell) => switch (shell) {
    ShellCompletion.bash => integrations.ToBashCompletionConverter(
      registryRecord,
    ).convert(),
    ShellCompletion.zsh => integrations.ToZshCompletionConverter(
      registryRecord,
    ).convert(),
    ShellCompletion.fish => integrations.ToFishCompletionConverter(
      registryRecord,
    ).convert(),
    ShellCompletion.powershell => integrations.ToPowerShellCompletionConverter(
      registryRecord,
    ).convert(),
    ShellCompletion.carapace => integrations.CarapaceSpecConverter(
      registryRecord,
    ).convert(),
  };

  static final ChoicePositional<ShellCompletion> shellInput = ChoicePositional(
    'shell',
    choices: ShellCompletion.values,
  );
  static final DiscretionaryPositional<String?> pathInput =
      NormalPositional.optional('path');
  String _extensionFor(ShellCompletion shell) => switch (shell) {
    ShellCompletion.bash => '.bash',
    ShellCompletion.zsh => '.zsh',
    ShellCompletion.fish => '.fish',
    ShellCompletion.powershell => '.ps1',
    ShellCompletion.carapace => '.yaml',
  };
  bool _isValidPath(String path, String extension) {
    if (!path.endsWith(extension)) return false;
    final name = path.split(RegExp(r'[/\\]')).last;
    return name
        .substring(0, name.length - extension.length)
        .contains(registryRecord.name);
  }

  static void _createFileSynchronously(String path) {
    File(path).createSync(exclusive: true);
  }
}
