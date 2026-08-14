import 'package:arg_parser/registry.dart';

class TestCommand extends Command {
  TestCommand(
    super.name,
    super.shortDescription, {
    super.longDescription,
    super.positionalSchema,
    super.flagSchema,
    super.optionSchema,
    super.accessorSchema,
    super.commands,
  });

  @override
  void run(Inputs input, List<String> variadic) {}
}

class TestPositionalSchema extends PositionalSchema<()> {
  TestPositionalSchema(super.mandatory, {super.discretionary, super.variadic});

  factory TestPositionalSchema.create(
    List<Positional> mandatory, {
    List<Positional>? discretionary,
    Variadic? variadic,
  }) => TestPositionalSchema(
    mandatory,
    discretionary: discretionary,
    variadic: variadic,
  );

  @override
  () toRecord(Map<String, dynamic> args) => ();
}

class TestFlagSchema extends FlagSchema<()> {
  TestFlagSchema(this._schema);

  final List<Flag> _schema;

  factory TestFlagSchema.create(List<Flag> schema) => TestFlagSchema(schema);

  @override
  List<Flag> get schema => _schema;

  @override
  () toRecord(Map<String, dynamic> args) => ();
}

class TestOptionSchema extends OptionSchema<()> {
  TestOptionSchema(this._schema);

  final List<Option> _schema;

  factory TestOptionSchema.create(List<Option> schema) =>
      TestOptionSchema(schema);

  @override
  List<Option> get schema => _schema;

  @override
  () toRecord(Map<String, dynamic> args) => ();
}

class TestAccessorOptionSchema extends AccessorOptionSchema<()> {
  TestAccessorOptionSchema(this._schema);

  final List<AccessorOption> _schema;

  factory TestAccessorOptionSchema.create(List<AccessorOption> schema) =>
      TestAccessorOptionSchema(schema);

  @override
  List<AccessorOption> get schema => _schema;

  @override
  () toRecord(Map<String, dynamic> args) => ();
}
