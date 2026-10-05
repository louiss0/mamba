import 'dart:io';

/// Which shells are installed here.
///
/// Completion checks are only as good as the shells they can reach: a generated
/// artifact is validated by parsing it where the shell exists and by running it
/// where the runner is known. One place decides what is available so two suites
/// cannot disagree about it.
String? shellOnPath(String candidate) {
  final lookup = Platform.isWindows ? 'where.exe' : 'which';
  try {
    final result = Process.runSync(lookup, [candidate]);
    return result.exitCode == 0 ? candidate : null;
  } on ProcessException {
    return null;
  }
}

/// The first installed shell among [candidates], or null when none is.
String? firstShellOnPath(List<String> candidates) {
  for (final candidate in candidates) {
    final found = shellOnPath(candidate);
    if (found != null) return found;
  }
  return null;
}

/// Whether the current run is a CI run.
///
/// The suite that drives a real completion skips itself anywhere else: passing
/// because a shell was missing is worse than not running at all.
bool get runningInCi =>
    Platform.environment['CI'] == 'true' || Platform.environment['CI'] == '1';

/// The major version of the bash on this machine, or null when there is none.
///
/// The generated Bash completion uses associative arrays, which need bash 4.
/// The setup action provisions a supported Bash on CI, and the runtime suite
/// treats a missing, unreadable, or unsupported version as a failure.
int? bashMajorVersion() {
  final shell = shellOnPath('bash');
  if (shell == null) return null;
  try {
    final result = Process.runSync(shell, ['-c', r'echo ${BASH_VERSINFO[0]}']);
    if (result.exitCode != 0) return null;
    return int.tryParse('${result.stdout}'.trim());
  } on ProcessException {
    return null;
  }
}
