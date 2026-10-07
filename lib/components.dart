import 'dart:io';

import 'package:clix/clix.dart' as clix;

/// Clix's text prompt, named separately from Mamba's typed input declaration.
typedef ClixInput = clix.Input;

/// Runs work behind Clix's automatically started spinner.
extension ClixSpinnerWork on clix.Spinner {
  /// Completes on success, reports a failure, and stops on every exit.
  ///
  /// The work result is returned unchanged; work errors are rethrown.
  Future<T> whileRunning<T>(Future<T> Function() work) async {
    try {
      final result = await work();
      complete();
      return result;
    } on Object {
      fail();
      rethrow;
    } finally {
      stop();
    }
  }
}

/// A numbered Clix selector that keeps input in the terminal's line mode.
///
/// Text filters all choices case-insensitively; a number selects an entry from
/// the displayed list. A blank line or an empty choice list returns `null`.
final class ClixSelector({
  required final String prompt,
  required List<String> options,
}) extends clix.Prompt<String?> {
  /// A retained, immutable copy of the choices to search and display.
  final List<String> options = List.unmodifiable(options);

  @override
  Future<String?> run(clix.CliIO io, clix.CliTheme theme) async {
    if (options.isEmpty) return null;
    var visible = options;
    while (true) {
      for (var index = 0; index < visible.length; index++) {
        io.writeln('${index + 1}. ${visible[index]}');
      }
      final answer = await ClixInput(
        prompt: '$prompt (number, search text, or blank to cancel)',
      ).interact(io, theme);
      if (answer.isEmpty) return null;
      final number = int.tryParse(answer);
      if (number != null) {
        if (number >= 1 && number <= visible.length) {
          return visible[number - 1];
        }
        io.writeln(theme.error('Enter a number from 1 to ${visible.length}.'));
        continue;
      }
      final matches = options
          .where(
            (option) => option.toLowerCase().contains(answer.toLowerCase()),
          )
          .toList();
      if (matches.isEmpty) {
        io.writeln(theme.error('No options match.'));
      } else {
        visible = matches;
      }
    }
  }
}

/// A directory browser using Clix line input rather than raw arrow keys.
///
/// Choose the current directory, its parent, or a sorted child directory.
/// Returns the chosen absolute directory path, or `null` on a blank answer.
final class ClixDirectoryPicker({
  required final String prompt,
  Directory? startDirectory,
}) extends clix.Prompt<String?> {
  /// The initial location; defaults to the process's current directory.
  final Directory startDirectory = startDirectory ?? Directory.current;

  @override
  Future<String?> run(clix.CliIO io, clix.CliTheme theme) async {
    var current = startDirectory.absolute;
    while (true) {
      final children =
          (await current.list().toList()).whereType<Directory>().toList()
            ..sort((left, right) => _label(left).compareTo(_label(right)));
      io.writeln('Current directory: ${current.path}');
      final selection = await ClixSelector(
        prompt: prompt,
        options: [
          'Use this directory',
          'Go to parent',
          for (final child in children) _label(child),
        ],
      ).interact(io, theme);
      if (selection == null) return null;
      if (selection == 'Use this directory') return current.path;
      current = selection == 'Go to parent'
          ? current.parent
          : children.firstWhere((child) => _label(child) == selection);
    }
  }

  String _label(Directory directory) =>
      '${directory.uri.pathSegments.where((segment) => segment.isNotEmpty).last}/';
}
