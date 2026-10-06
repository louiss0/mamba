import 'package:mamba/command.dart';

/// One choice interpretation for parsing, help, defaults, and artifacts.
String choiceSpelling(Enum choice) =>
    choice is MambaEnumValue ? (choice as MambaEnumValue).value : choice.name;
