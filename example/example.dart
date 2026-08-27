import 'dart:convert';
import 'dart:io';

import 'package:mamba/mamba.dart';
import 'package:zema/zema.dart';

final _taskStore = TaskStore();

final List<Command> _taskCommands = [
  CreateTaskCommand(_taskStore),
  ListTaskCommand(_taskStore),
  ReadTaskCommand(_taskStore),
  UpdateTaskCommand(_taskStore),
  DeleteTaskCommand(_taskStore),
  CompleteTaskCommand(_taskStore),
  ReopenTaskCommand(_taskStore),
  CompletionTaskCommand(),
];

Future<void> main(List<String> args) => Executor(
  'task-cli',
  'Manage a persisted task list.',
  commands: _taskCommands,
).create().execute(args);

final class Task {
  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.completed,
  });

  final int id;
  final String title;
  final String description;
  final bool completed;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'completed': completed,
  };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'] as int,
    title: json['title'] as String,
    description: json['description'] as String,
    completed: json['completed'] as bool? ?? false,
  );
}

final class TaskStore {
  TaskStore()
    : file = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}mamba_tasks.json',
      ) {
    if (!file.existsSync()) {
      file.writeAsStringSync('{"nextId":1,"tasks":[]}');
    }
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is Map<String, dynamic>) {
      _nextId = decoded['nextId'] as int? ?? 1;
    } else if (decoded is List) {
      final ids = decoded
          .whereType<Map<String, dynamic>>()
          .map((task) => task['id'])
          .whereType<int>();
      _nextId = ids.isEmpty ? 1 : ids.reduce((a, b) => a > b ? a : b) + 1;
    }
  }

  final File file;
  int _nextId = 1;

  List<Task> readAll() {
    final decoded = jsonDecode(file.readAsStringSync());
    final taskData = decoded is Map<String, dynamic>
        ? decoded['tasks']
        : decoded;
    if (taskData is! List) return [];
    return taskData
        .whereType<Map<String, dynamic>>()
        .map(Task.fromJson)
        .toList();
  }

  void writeAll(List<Task> tasks) {
    file.writeAsStringSync(
      JsonEncoder.withIndent('  ').convert({
        'nextId': _nextId,
        'tasks': tasks.map((task) => task.toJson()).toList(),
      }),
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
      id: _nextId,
      title: title,
      description: description,
      completed: false,
    );
    _nextId++;
    writeAll([...tasks, task]);
    return task;
  }

  void setCompleted(int id, bool completed) {
    final tasks = readAll();
    final index = tasks.indexWhere((task) => task.id == id);
    if (index < 0) throw MambaException('Task not found.');
    final task = tasks[index];
    tasks[index] = Task(
      id: task.id,
      title: task.title,
      description: task.description,
      completed: completed,
    );
    writeAll(tasks);
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
  ListTaskCommand(this.store)
    : super(
        flags: [
          BooleanFlag('completed', description: 'Show completed tasks.'),
          BooleanFlag('pending', description: 'Show pending tasks.'),
        ],
      );

  final TaskStore store;
  @override
  String get name => 'list';
  @override
  String get shortDescription =>
      'List tasks, optionally filtered by completion.';

  @override
  String run(_, ParsedNamedInputs inputs, _) {
    final completed = inputs.boolFlags?['completed'] == true;
    final pending = inputs.boolFlags?['pending'] == true;
    if (completed && pending) {
      throw MambaException('Use either --completed or --pending, not both.');
    }
    final tasks = store.readAll().where((task) {
      if (completed) return task.completed;
      if (pending) return !task.completed;
      return true;
    }).toList();
    if (tasks.isEmpty) return 'No matching tasks.';
    return tasks
        .map(
          (task) =>
              '${task.completed ? '[x]' : '[ ]'} ${task.id}: ${task.title} — ${task.description}',
        )
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
  String run(ParsedPositionals positionals, _, _) {
    final task = store.find(_taskId(positionals));
    if (task == null) throw MambaException('Task not found.');
    return '${task.completed ? '[x]' : '[ ]'} ${task.id}: ${task.title}\n${task.description}';
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
      completed: current.completed,
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
  String run(ParsedPositionals positionals, _, _) {
    final tasks = store.readAll();
    final id = _taskId(positionals);
    final remaining = tasks.where((task) => task.id != id).toList();
    if (remaining.length == tasks.length) {
      throw MambaException('Task not found.');
    }
    store.writeAll(remaining);
    return 'Deleted task $id.';
  }
}

final class CompletionTaskCommand extends CompletionCommand {
  CompletionTaskCommand()
    : super(
        options: [
          _textOption(
            'output',
            'Override the default Carapace spec file location.',
          ),
        ],
      );
  @override
  String get name => 'completion';
  @override
  String get shortDescription => 'Generate the Carapace completion spec.';

  @override
  String run(_, ParsedNamedInputs inputs, _) {
    final outputFile = CarapaceSpecWriter(
      CarapaceSpecConverter(registryMap),
      development: false,
      outputPath: inputs.stringOptions?['output'],
    ).write();
    return 'Wrote Carapace spec to ${outputFile.path}.';
  }
}

final class CompleteTaskCommand extends Command {
  CompleteTaskCommand(this.store)
    : super(mandatoryPositionals: [Positional('id', regex: RegExp(r'\d+'))]);

  final TaskStore store;
  @override
  String get name => 'complete';
  @override
  String get shortDescription => 'Mark a task as completed.';

  @override
  String run(ParsedPositionals positionals, _, _) {
    final id = _taskId(positionals);
    store.setCompleted(id, true);
    return 'Completed task $id.';
  }
}

final class ReopenTaskCommand extends Command {
  ReopenTaskCommand(this.store)
    : super(mandatoryPositionals: [Positional('id', regex: RegExp(r'\d+'))]);

  final TaskStore store;
  @override
  String get name => 'reopen';
  @override
  String get shortDescription => 'Mark a task as pending.';

  @override
  String run(ParsedPositionals positionals, _, _) {
    final id = _taskId(positionals);
    store.setCompleted(id, false);
    return 'Reopened task $id.';
  }
}
