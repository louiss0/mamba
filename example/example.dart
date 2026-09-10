import 'dart:convert';
import 'dart:io';

import 'package:mamba/mamba.dart';

Future<void> main(List<String> args) {
  final store = TaskStore(
    File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}mamba_tasks.json',
    ),
  );
  return Executor('task-cli', 'Manage a persisted task list.', '1.0.0', [
    CreateTaskCommand(store),
    ListTaskCommand(store),
    ReadTaskCommand(store),
    UpdateTaskCommand(store),
    DeleteTaskCommand(store),
    CompleteTaskCommand(store),
    ReopenTaskCommand(store),
    CompletionTaskCommand(),
  ]).create().execute(args);
}

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

  Task copyWith({String? title, String? description, bool? completed}) => Task(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    completed: completed ?? this.completed,
  );

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
  const TaskStore(this.file);

  final File file;

  ({int nextId, List<Task> tasks}) _read() {
    if (!file.existsSync()) return (nextId: 1, tasks: <Task>[]);

    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded case {
        'nextId': final int nextId,
        'tasks': final List<dynamic> taskData,
      }) {
        return (
          nextId: nextId,
          tasks: taskData
              .map((item) => Task.fromJson(item as Map<String, dynamic>))
              .toList(),
        );
      }
      throw const FormatException('Unexpected task-list structure.');
    } on FileSystemException catch (error) {
      throw MambaException('Could not read the task list: ${error.message}.');
    } on FormatException catch (error) {
      throw MambaException('Could not read the task list: ${error.message}');
    } on TypeError {
      throw MambaException('Could not read the task list: invalid task data.');
    }
  }

  List<Task> readAll() => List.unmodifiable(_read().tasks);

  void _write(int nextId, List<Task> tasks) {
    try {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        JsonEncoder.withIndent('  ').convert({
          'nextId': nextId,
          'tasks': tasks.map((task) => task.toJson()).toList(),
        }),
        flush: true,
      );
    } on FileSystemException catch (error) {
      throw MambaException('Could not save the task list: ${error.message}.');
    }
  }

  Task? find(int id) => readAll().where((task) => task.id == id).firstOrNull;

  Task add(String title, String description) {
    final document = _read();
    final task = Task(
      id: document.nextId,
      title: title,
      description: description,
      completed: false,
    );
    _write(document.nextId + 1, [...document.tasks, task]);
    return task;
  }

  Task update(int id, {String? title, String? description, bool? completed}) {
    final document = _read();
    final index = document.tasks.indexWhere((task) => task.id == id);
    if (index < 0) throw MambaException('Task $id was not found.');

    final updated = document.tasks[index].copyWith(
      title: title,
      description: description,
      completed: completed,
    );
    final tasks = [...document.tasks]..[index] = updated;
    _write(document.nextId, tasks);
    return updated;
  }

  void delete(int id) {
    final document = _read();
    final tasks = document.tasks.where((task) => task.id != id).toList();
    if (tasks.length == document.tasks.length) {
      throw MambaException('Task $id was not found.');
    }
    _write(document.nextId, tasks);
  }

  void setCompleted(int id, bool completed) => update(id, completed: completed);
}

String _validatedText(String field, String value) {
  final text = value.trim();
  if (text.isEmpty) throw MambaException('$field must not be empty.');
  return text;
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

enum TaskStatus { all, completed, pending }

final class ListTaskCommand extends Command {
  ListTaskCommand(this.store) : super(options: [status]);

  static final status = ChoiceOption<TaskStatus>(
    'status',
    choices: TaskStatus.values,
    defaultValue: TaskStatus.all,
    description: 'Filter tasks by completion status.',
  );

  final TaskStore store;

  @override
  String get name => 'list';

  @override
  String get shortDescription =>
      'List tasks, optionally filtered by completion.';

  @override
  String run(CommandInvocation invocation, List<String> args) {
    final statusValue = invocation.inputs.require(status);
    final tasks = store.readAll().where((task) {
      return switch (statusValue) {
        TaskStatus.all => true,
        TaskStatus.completed => task.completed,
        TaskStatus.pending => !task.completed,
      };
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
    final task = store.find(_taskId(invocation, TaskIdCommand.id));
    if (task == null) throw MambaException('Task not found.');
    return '${task.completed ? '[x]' : '[ ]'} ${task.id}: ${task.title}\n${task.description}';
  }
}

final class UpdateTaskCommand extends Command {
  UpdateTaskCommand(this.store)
    : super(
        mandatoryPositionals: [id],
        pairedOptions: [
          PairedOptions([title, description], required: true),
        ],
      );

  static final id = NormalPositional('id', regExp: RegExp(r'\d+'));
  static final title = PairStringOption(
    'title',
    regex: RegExp(r'.+'),
    description: 'Replacement title.',
  );
  static final description = PairStringOption(
    'description',
    regex: RegExp(r'.+'),
    description: 'Replacement description.',
  );

  final TaskStore store;

  @override
  String get name => 'update';

  @override
  String get shortDescription => 'Update a task.';

  @override
  String run(CommandInvocation invocation, List<String> args) {
    final idValue = _taskId(invocation, id);
    store.update(
      idValue,
      title: _validatedText('title', invocation.inputs.require(title)),
      description: _validatedText(
        'description',
        invocation.inputs.require(description),
      ),
    );
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
    final id = _taskId(invocation, TaskIdCommand.id);
    store.delete(id);
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
    final id = _taskId(invocation, TaskIdCommand.id);
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
    final id = _taskId(invocation, TaskIdCommand.id);
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
