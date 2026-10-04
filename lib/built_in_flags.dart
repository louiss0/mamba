import 'package:mamba/command.dart';

/// Reusable flag declarations supplied by Mamba.
abstract final class MambaBuiltInFlags {
  static const help = BooleanFlag(
    'help',
    short: 'h',
    description: 'Show this help message.',
  );
  static const dryRun = BooleanFlag(
    'dry-run',
    description: 'Show what would happen without changing anything.',
  );
  static const verbose = CountFlag(
    'verbose',
    short: 'v',
    description: 'Increase output verbosity.',
  );
  static const version = BooleanFlag(
    'version',
    short: 'V',
    description: 'Show the application version.',
  );

  /// The spellings Mamba always reads itself rather than as a declaration.
  ///
  /// Help and version are the only reserved inputs, and a declaration may not
  /// claim either spelling. Opt-in built-ins such as [dryRun] are ordinary
  /// declarations and are not control tokens.
  static bool isHelp(String token) =>
      token == '--${help.name}' || token == '-${help.short}';

  static bool isVersion(String token) =>
      token == '--${version.name}' || token == '-${version.short}';

  static bool isControl(String token) =>
      isHelp(token) || isVersion(token) || _clusteredControl(token);

  /// Whether a clustered short group such as `-xh` carries a control letter.
  static bool _clusteredControl(String token) {
    if (!token.startsWith('-') || token.startsWith('--') || token == '-') {
      return false;
    }
    final letters = token.substring(1);
    return letters.contains(help.short!) || letters.contains(version.short!);
  }
}
