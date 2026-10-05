import 'dart:io';

import 'package:mamba/command.dart';

final class SystemMambaProcess {
  // This class only ever runs inside a child process: `dart test` measures the
  // parent VM, and a subprocess is not measurable from here. The behaviour is
  // covered end to end by `test/system_process_test.dart`, which runs a real
  // process and asserts the bytes it writes.
  // coverage:ignore-start
  Future<ProcessedStandardInput?> readStandardInput() async {
    try {
      if (stdioType(stdin) != StdioType.pipe) return null;
      return ProcessedStandardInput(
        await stdin.expand((item) => item).toList(),
      );
    } on FileSystemException catch (error) {
      if (!isClosedPipeFileSystemException(error)) rethrow;
      return null;
    }
  }

  void writeOutput(String message) => stdout.write(message);

  void writeError(String message) => stderr.write(message);

  set processExitCode(int value) => exitCode = value;
  // coverage:ignore-end
}

bool isClosedPipeFileSystemException(FileSystemException error) {
  final code = error.osError?.errorCode;
  if (code == 32 || code == 109 || code == 232) return true;
  final message = '${error.message} ${error.osError?.message ?? ''}'
      .toLowerCase();
  return message.contains('socket is closed') ||
      message.contains('pipe is being closed') ||
      message.contains('broken pipe');
}
