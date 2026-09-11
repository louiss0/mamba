import 'package:mamba/command.dart';

/// The process boundary used by a production [Executor].
///
/// Supply an implementation to [Executor.create] to redirect process effects,
/// such as when embedding a command-line application or testing it in memory.
abstract interface class MambaProcess {
  /// Reads piped input, or returns `null` when no input is available.
  Future<ProcessedStandardInput?> readStandardInput();

  /// Writes successful command output.
  void writeOutput(String message);

  /// Writes a recoverable execution error.
  void writeError(String message);

  /// Sets the process exit code after a recoverable execution failure.
  set processExitCode(int value);
}
