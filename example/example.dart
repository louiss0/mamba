import 'dart:convert';
import 'dart:io';

import 'package:mamba/mamba.dart';
import 'package:zema/zema.dart';

final _taskStore = TaskStore();

Future<void> main(List<String> args) => Executor(
  'mamba',
  'Manage a persisted task list.',
  commands: [
    CreateTaskCommand(_taskStore),
    ListTaskCommand(_taskStore),
    ReadTaskCommand(_taskStore),
    UpdateTaskCommand(_taskStore),
    DeleteTaskCommand(_taskStore),
  ],
).create().execute(args);

final class Task {
  const Task({
    required this.id,
    required this.title,
    required this.description,
  });

  final int id;
  final String title;
  final String description;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
  };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'] as int,
    title: json['title'] as String,
    description: json['description'] as String,
  );
}

final class TaskStore {
  TaskStore()
    : file = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}mamba_tasks.json',
      ) {
    if (!file.existsSync()) {
      file.writeAsStringSync('[]');
    }
  }

  final File file;

  List<Task> readAll() {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! List) return [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Task.fromJson)
        .toList();
  }

  void writeAll(List<Task> tasks) {
    file.writeAsStringSync(
      const JsonEncoder.withIndent(
        '  ',
      ).convert(tasks.map((task) => task.toJson()).toList()),
    );
  }

  Task? find(int id) {
    for (final task in readAll()) {
      if (task.id == id) return task;
    }
    return null;
  }

  Task add(String title, String description) {
    final tasks = readAll();
    final task = Task(
      id: tasks.isEmpty
          ? 1
          : tasks.map((task) => task.id).reduce((a, b) => a > b ? a : b) + 1,
      title: title,
      description: description,
    );
    writeAll([...tasks, task]);
    return task;
  }
}

final _textSchema = z.string().trim().min(1);

String _validatedText(String field, String? value) {
  if (value == null) throw MambaException('Option --$field is required.');
  try {
    final result = _textSchema.safeParse(value);
    if (result.isFailure) {
      throw MambaException('$field must not be empty.');
    }
    return value.trim();
  } on ZemaException {
    throw MambaException('$field must not be empty.');
  }
}

int _taskId(ParsedPositionals positionals) =>
    int.parse(positionals.singles!['id']!);

StringOption _textOption(
  String name,
  String description, {
  bool required = false,
}) => StringOption(
  name,
  description: description,
  required: required,
  regex: RegExp(r'.+'),
);

final class CreateTaskCommand extends Command {
  CreateTaskCommand(this.store)
    : super(
        options: [
          _textOption('title', 'Task title.', required: true),
          _textOption('description', 'Task description.', required: true),
        ],
      );

  final TaskStore store;
  @override
  String get name => 'create';
  @override
  String get shortDescription => 'Create a task.';

  @override
  String run(_, ParsedNamedInputs inputs, _) {
    final task = store.add(
      _validatedText('title', inputs.stringOptions?['title']),
      _validatedText('description', inputs.stringOptions?['description']),
    );
    return 'Created task ${task.id}: ${task.title}';
  }
}

final class ListTaskCommand extends Command {
  ListTaskCommand(this.store);
  final TaskStore store;
  @override
  String get name => 'list';
  @override
  String get shortDescription => 'List all tasks.';

  @override
  String run(_, __, ___) {
    final tasks = store.readAll();
    if (tasks.isEmpty) return 'No tasks.';
    return tasks
        .map((task) => '${task.id}: ${task.title} — ${task.description}')
        .join('\n');
  }
}

final class ReadTaskCommand extends Command {
  ReadTaskCommand(this.store)
    : super(mandatoryPositionals: [Positional('id', regex: RegExp(r'\d+'))]);
  final TaskStore store;
  @override
  String get name => 'read';
  @override
  String get shortDescription => 'Read one task.';

  @override
  String run(ParsedPositionals positionals, _, __) {
    final task = store.find(_taskId(positionals));
    if (task == null) throw MambaException('Task not found.');
    return '${task.id}: ${task.title}\n${task.description}';
  }
}

final class UpdateTaskCommand extends Command {
  UpdateTaskCommand(this.store)
    : super(
        mandatoryPositionals: [Positional('id', regex: RegExp(r'\d+'))],
        options: [
          _textOption('title', 'Replacement title.'),
          _textOption('description', 'Replacement description.'),
        ],
      );
  final TaskStore store;
  @override
  String get name => 'update';
  @override
  String get shortDescription => 'Update a task.';

  @override
  String run(ParsedPositionals positionals, ParsedNamedInputs inputs, _) {
    final tasks = store.readAll();
    final id = _taskId(positionals);
    final index = tasks.indexWhere((task) => task.id == id);
    if (index < 0) throw MambaException('Task not found.');
    final title = inputs.stringOptions?['title'];
    final description = inputs.stringOptions?['description'];
    if (title == null && description == null) {
      throw MambaException('Provide --title, --description, or both.');
    }
    final current = tasks[index];
    tasks[index] = Task(
      id: id,
      title: title == null ? current.title : _validatedText('title', title),
      description: description == null
          ? current.description
          : _validatedText('description', description),
    );
    store.writeAll(tasks);
    return 'Updated task $id.';
  }
}

final class DeleteTaskCommand extends Command {
  DeleteTaskCommand(this.store)
    : super(mandatoryPositionals: [Positional('id', regex: RegExp(r'\d+'))]);
  final TaskStore store;
  @override
  String get name => 'delete';
  @override
  String get shortDescription => 'Delete a task.';

  @override
  String run(ParsedPositionals positionals, _, __) {
    final tasks = store.readAll();
    final id = _taskId(positionals);
    final remaining = tasks.where((task) => task.id != id).toList();
    if (remaining.length == tasks.length)
      throw MambaException('Task not found.');
    store.writeAll(remaining);
    return 'Deleted task $id.';
  }
}
