import 'dart:io';

// A process-boundary fixture, compiled to an executable for PATH-based checks
// on both Windows and POSIX. It answers version probes, never completions.
void main(List<String> args) {
  if (args.contains('-c')) {
    stdout.writeln(Platform.environment['MAMBA_FAKE_BASH_MAJOR'] ?? '3');
    exitCode = int.parse(Platform.environment['MAMBA_FAKE_BASH_EXIT'] ?? '0');
  } else if (args.contains('--version')) {
    stdout.writeln('Controlled Bash version fixture');
  } else {
    stderr.writeln('The completion harness reached the version-only fixture.');
    exitCode = 99;
  }
}
