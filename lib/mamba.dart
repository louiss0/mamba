/// The public API for defining and executing Mamba command-line applications.
///
/// Mamba keeps command definition, validation, and execution separate:
///
/// 1. Commands register names, descriptions, inputs, and behavior.
/// 2. An [Executor] builds a [CommandRegistry] that organizes that data.
/// 3. A [Parser] reads the selected registry and decides whether an invocation
///    is valid, producing typed values when it is.
/// 4. The executor selects the matching command and gives it parsed values,
///    trailing arguments, and global context established by hooks.
///
/// See `README.md` for the complete input syntax, rendered help, and
/// production and test setup guidance.
library;

export 'command.dart';
export 'context.dart';
export 'errors.dart';
export 'executor.dart';
export 'help_formatter.dart';
export 'integrations.dart';
export 'parser.dart';
export 'registry.dart';
