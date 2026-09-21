import 'dart:io';

import 'package:mamba/command.dart';

final class SystemMambaProcess {
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

  void writeOutput(String message) => stdout.writeln(message);

  void writeError(String message) => stderr.writeln(message);

  set processExitCode(int value) => exitCode = value;
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
