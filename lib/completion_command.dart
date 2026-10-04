import 'dart:io';

import 'package:mamba/command.dart';
import 'package:mamba/errors.dart';
import 'package:mamba/integrations.dart' as integrations;
import 'package:mamba/registry.dart';

enum ShellCompletion { bash, zsh, fish, powershell, carapace }

/// Receives a validated destination and the completion script generated for
/// it.
///
/// The command hands both to one callback rather than writing the file itself,
/// which is what lets an application route the artifact to storage the
/// filesystem boundary does not reach. A callback that creates the file is still
/// responsible for writing [contents] into it.
typedef CompletionFileWriter = void Function(String path, String contents);

class CompletionCommand extends Command {
  late RegistryRecord registryRecord;
  final CompletionFileWriter createFile;
  @override
  String get name => 'completion';
  @override
  String get shortDescription => 'Generate completion for various shells';

  /// The command's inputs are intrinsic to what it does, so they are declared
  /// here rather than accepted from a caller: a `CompletionCommand` that could
  /// be built without them would have a [run] that reads handles the parser
  /// never registered.
  new({CompletionFileWriter? createFile, super.longDescription, super.aliases})
    : createFile = createFile ?? _writeToFile,
      super(
        mandatoryPositionals: [shellInput],
        discretionaryPositionals: [pathInput],
      );
  new preset({
    required CompletionFileWriter? createFile,
    String? longDescription,
  }) : this(
         createFile: createFile,
         longDescription:
             longDescription ??
             'Generate completions for Bash ZSH Fish or Powershell',
         aliases: ['cmp', 'cpt'],
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
    // The generated script is built before the destination is touched, so a
    // rejected invocation never leaves a half-written artifact behind.
    final contents = _completionFor(shell);
    if (path.isEmpty && identical(createFile, _writeToFile)) {
      throw MambaException(
        'A destination path is required to write ${shell.name} completions.',
      );
    }
    createFile(path, contents);
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

  static void _writeToFile(String path, String contents) {
    File(path).writeAsStringSync(contents);
  }
}
