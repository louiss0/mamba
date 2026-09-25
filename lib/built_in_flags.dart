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
}
