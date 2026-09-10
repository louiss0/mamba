import 'dart:convert';
import 'dart:io';

import 'package:mamba/mamba.dart';
import 'package:zema/zema.dart';

final _taskStore = TaskStore();

Future<void> main(List<String> args) =>
    Executor('task-cli', 'Manage a persisted task list.', '1.0.0', [
      CreateTaskCommand(_taskStore),
      ListTaskCommand(_taskStore),
      ReadTaskCommand(_taskStore),
      UpdateTaskCommand(_taskStore),
      DeleteTaskCommand(_taskStore),
      CompleteTaskCommand(_taskStore),
      ReopenTaskCommand(_taskStore),
      CompletionTaskCommand(),
    ]).create().execute(args);

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

  Map<String, Object> toJson() => {
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
    if (decoded case {'nextId': final int nextId}) {
      _nextId = nextId;
    }
  }

  final File file;
  int _nextId = 1;

  List<Task> readAll() {
    final decoded = jsonDecode(file.readAsStringSync());
    final taskData = decoded is Map<String, dynamic>
        ? decoded['tasks']
        : decoded;
    return taskData is List
        ? taskData.whereType<Map<String, dynamic>>().map(Task.fromJson).toList()
        : [];
  }

  void writeAll(List<Task> tasks) {
    file.writeAsStringSync(
      JsonEncoder.withIndent('  ').convert({
        'nextId': _nextId,
        'tasks': tasks.map((task) => task.toJson()).toList(),
      }),
    );
  }

  Task? find(int id) => readAll().where((task) => task.id == id).firstOrNull;

  Task add(String title, String description) {
    final task = Task(
      id: _nextId++,
      title: title,
      description: description,
      completed: false,
    );
    writeAll([...readAll(), task]);
    return task;
  }

  void setCompleted(int id, bool completed) {
    final tasks = readAll();
    final index = tasks.indexWhere((task) => task.id == id);
    if (index < 0) throw MambaException('Task not found.');
    final current = tasks[index];
    tasks[index] = Task(
      id: current.id,
      title: current.title,
      description: current.description,
      completed: completed,
    );
    writeAll(tasks);
  }
}

final _textSchema = z.string().trim().min(1);

String _validatedText(String field, String value) {
  try {
    if (_textSchema.safeParse(value).isFailure) {
      throw MambaException('$field must not be empty.');
    }
    return value.trim();
  } on ZemaException {
    throw MambaException('$field must not be empty.');
  }
}

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

int _taskId(CommandInvocation invocation, NormalPositional input) =>
    int.parse(invocation.inputs.require(input));

final class CreateTaskCommand extends Command {
  CreateTaskCommand(this.store) : super(options: [title, description]);

  static final title = _textOption('title', 'Task title.', required: true);
  static final description = _textOption(
    'description',
    'Task description.',
    required: true,
  );

  final TaskStore store;

  @override
  String get name => 'create';

  @override
  String get shortDescription => 'Create a task.';

  @override
  String run(CommandInvocation invocation, List<String> args) {
    final task = store.add(
      _validatedText('title', invocation.inputs.require(title)),
      _validatedText('description', invocation.inputs.require(description)),
    );
    return 'Created task ${task.id}: ${task.title}';
  }
}

final class ListTaskCommand extends Command {
  ListTaskCommand(this.store) : super(flags: [completed, pending]);

  static final completed = BooleanFlag(
    'completed',
    description: 'Show completed tasks.',
  );
  static final pending = BooleanFlag(
    'pending',
    description: 'Show pending tasks.',
  );

  final TaskStore store;

  @override
  String get name => 'list';

  @override
  String get shortDescription =>
      'List tasks, optionally filtered by completion.';

  @override
  String run(CommandInvocation invocation, List<String> args) {
    final showCompleted = invocation.inputs.require(completed);
    final showPending = invocation.inputs.require(pending);
    if (showCompleted && showPending) {
      throw MambaException('Use either --completed or --pending, not both.');
    }
    final tasks = store.readAll().where((task) {
      if (showCompleted) return task.completed;
      if (showPending) return !task.completed;
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

abstract class TaskIdCommand extends Command {
  TaskIdCommand() : super(mandatoryPositionals: [id]);

  static final id = NormalPositional('id', regExp: RegExp(r'\d+'));

  int taskIdOf(CommandInvocation invocation) => _taskId(invocation, id);
}

final class ReadTaskCommand extends TaskIdCommand {
  ReadTaskCommand(this.store);

  final TaskStore store;

  @override
  String get name => 'read';

  @override
  String get shortDescription => 'Read one task.';

  @override
  String run(CommandInvocation invocation, List<String> args) {
    final task = store.find(taskIdOf(invocation));
    if (task == null) throw MambaException('Task not found.');
    return '${task.completed ? '[x]' : '[ ]'} ${task.id}: ${task.title}\n${task.description}';
  }
}

final class UpdateTaskCommand extends Command {
  UpdateTaskCommand(this.store)
    : super(mandatoryPositionals: [id], options: [title, description]);

  static final id = NormalPositional('id', regExp: RegExp(r'\d+'));
  static final title = _textOption('title', 'Replacement title.');
  static final description = _textOption(
    'description',
    'Replacement description.',
  );

  final TaskStore store;

  @override
  String get name => 'update';

  @override
  String get shortDescription => 'Update a task.';

  @override
  String run(CommandInvocation invocation, List<String> args) {
    final tasks = store.readAll();
    final idValue = _taskId(invocation, id);
    final index = tasks.indexWhere((task) => task.id == idValue);
    if (index < 0) throw MambaException('Task not found.');
    final replacementTitle = invocation.inputs.valueOf(title);
    final replacementDescription = invocation.inputs.valueOf(description);
    if (replacementTitle == null && replacementDescription == null) {
      throw MambaException('Provide --title, --description, or both.');
    }
    final current = tasks[index];
    tasks[index] = Task(
      id: current.id,
      title: replacementTitle == null
          ? current.title
          : _validatedText('title', replacementTitle),
      description: replacementDescription == null
          ? current.description
          : _validatedText('description', replacementDescription),
      completed: current.completed,
    );
    store.writeAll(tasks);
    return 'Updated task $idValue.';
  }
}

final class DeleteTaskCommand extends TaskIdCommand {
  DeleteTaskCommand(this.store);

  final TaskStore store;

  @override
  String get name => 'delete';

  @override
  String get shortDescription => 'Delete a task.';

  @override
  String run(CommandInvocation invocation, List<String> args) {
    final id = taskIdOf(invocation);
    final tasks = store.readAll();
    final remaining = tasks.where((task) => task.id != id).toList();
    if (remaining.length == tasks.length)
      throw MambaException('Task not found.');
    store.writeAll(remaining);
    return 'Deleted task $id.';
  }
}

final class CompleteTaskCommand extends TaskIdCommand {
  CompleteTaskCommand(this.store);

  final TaskStore store;

  @override
  String get name => 'complete';

  @override
  String get shortDescription => 'Mark a task as completed.';

  @override
  String run(CommandInvocation invocation, List<String> args) {
    final id = taskIdOf(invocation);
    store.setCompleted(id, true);
    return 'Completed task $id.';
  }
}

final class ReopenTaskCommand extends TaskIdCommand {
  ReopenTaskCommand(this.store);

  final TaskStore store;

  @override
  String get name => 'reopen';

  @override
  String get shortDescription => 'Mark a task as pending.';

  @override
  String run(CommandInvocation invocation, List<String> args) {
    final id = taskIdOf(invocation);
    store.setCompleted(id, false);
    return 'Reopened task $id.';
  }
}

final class CompletionTaskCommand extends CompletionCommand {
  CompletionTaskCommand() : super(options: [output]);

  static final output = StringOption(
    'output',
    required: true,
    description: 'Write the Carapace spec to this path.',
  );

  @override
  String get name => 'completion';

  @override
  String get shortDescription => 'Generate the Carapace completion spec.';

  @override
  String run(CommandInvocation invocation, List<String> args) {
    final path = invocation.inputs.require(output);
    CarapaceSpecWriter(path).write(registryRecord);
    return 'Wrote Carapace spec to $path.';
  }
}
