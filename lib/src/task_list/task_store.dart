import 'dart:convert';
import 'dart:io';

import 'task.dart';

/// Reads and writes a project-local task list JSON document.
final class TaskStore {
  TaskStore(this.file);

  final File file;

  Future<TaskStoreRead> readTasks() async {
    if (!await file.exists()) return const TaskStoreRead.success([]);

    try {
      final document = jsonDecode(await file.readAsString());
      if (document is! Map || document['tasks'] is! List) {
        return const TaskStoreRead.failure(
          'The task list file must contain a "tasks" array.',
        );
      }

      final tasks = <Task>[];
      for (final source in document['tasks'] as List) {
        final decoded = Task.decodeJson(source);
        if (decoded case TaskDecodeFailure(:final message)) {
          return TaskStoreRead.failure('Could not read ${file.path}: $message');
        }
        tasks.add((decoded as TaskDecodeSuccess).task);
      }
      return TaskStoreRead.success(tasks);
    } on FileSystemException catch (error) {
      return TaskStoreRead.failure(
        'Could not read ${file.path}: ${error.message}',
      );
    } on FormatException catch (error) {
      return TaskStoreRead.failure(
        'Could not read ${file.path}: ${error.message}',
      );
    } catch (_) {
      return TaskStoreRead.failure(
        'Could not read ${file.path}: invalid task JSON.',
      );
    }
  }

  Future<TaskStoreWrite> writeTasks(List<Task> tasks) async {
    final document = {
      'tasks': tasks.map((task) => task.toJson()).toList(growable: false),
    };

    try {
      await file.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(document)}\n',
      );
      return const TaskStoreWrite.success();
    } on FileSystemException catch (error) {
      return TaskStoreWrite.failure(
        'Could not save ${file.path}: ${error.message}',
      );
    }
  }
}

sealed class TaskStoreRead {
  const TaskStoreRead();

  const factory TaskStoreRead.success(List<Task> tasks) = TaskStoreReadSuccess;
  const factory TaskStoreRead.failure(String message) = TaskStoreReadFailure;
}

final class TaskStoreReadSuccess extends TaskStoreRead {
  const TaskStoreReadSuccess(this.tasks);

  final List<Task> tasks;
}

final class TaskStoreReadFailure extends TaskStoreRead {
  const TaskStoreReadFailure(this.message);

  final String message;
}

sealed class TaskStoreWrite {
  const TaskStoreWrite();

  const factory TaskStoreWrite.success() = TaskStoreWriteSuccess;
  const factory TaskStoreWrite.failure(String message) = TaskStoreWriteFailure;
}

final class TaskStoreWriteSuccess extends TaskStoreWrite {
  const TaskStoreWriteSuccess();
}

final class TaskStoreWriteFailure extends TaskStoreWrite {
  const TaskStoreWriteFailure(this.message);

  final String message;
}
