import 'task.dart';
import 'task_store.dart';

/// Coordinates task-list mutations with persistent storage.
final class TaskService {
  TaskService(this._store);

  final TaskStore _store;

  Future<TaskOperation<Task>> addTask({
    required String title,
    required String? description,
  }) async {
    final loaded = await _store.readTasks();
    if (loaded case TaskStoreReadFailure(:final message)) {
      return TaskOperation.failure(message);
    }

    final tasks = (loaded as TaskStoreReadSuccess).tasks;
    final nextId =
        tasks.fold(
          0,
          (highestId, task) => task.id > highestId ? task.id : highestId,
        ) +
        1;
    final task = Task(
      id: nextId,
      title: title,
      description: description,
      complete: false,
    );
    final saved = await _store.writeTasks([...tasks, task]);
    if (saved case TaskStoreWriteFailure(:final message)) {
      return TaskOperation.failure(message);
    }
    return TaskOperation.success(task);
  }

  Future<TaskOperation<Task>> updateTask(int id, TaskUpdate update) async {
    final loaded = await _store.readTasks();
    if (loaded case TaskStoreReadFailure(:final message)) {
      return TaskOperation.failure(message);
    }

    final tasks = (loaded as TaskStoreReadSuccess).tasks;
    final taskIndex = tasks.indexWhere((task) => task.id == id);
    if (taskIndex == -1) {
      return TaskOperation.failure('No task has ID $id.');
    }

    final updated = update.applyTo(tasks[taskIndex]);
    final saved = await _store.writeTasks([
      for (var index = 0; index < tasks.length; index++)
        if (index == taskIndex) updated else tasks[index],
    ]);
    if (saved case TaskStoreWriteFailure(:final message)) {
      return TaskOperation.failure(message);
    }
    return TaskOperation.success(updated);
  }

  Future<TaskOperation<Task>> deleteTask(int id) async {
    final loaded = await _store.readTasks();
    if (loaded case TaskStoreReadFailure(:final message)) {
      return TaskOperation.failure(message);
    }

    final tasks = (loaded as TaskStoreReadSuccess).tasks;
    final taskIndex = tasks.indexWhere((task) => task.id == id);
    if (taskIndex == -1) {
      return TaskOperation.failure('No task has ID $id.');
    }

    final deleted = tasks[taskIndex];
    final saved = await _store.writeTasks(
      tasks.where((task) => task.id != id).toList(growable: false),
    );
    if (saved case TaskStoreWriteFailure(:final message)) {
      return TaskOperation.failure(message);
    }
    return TaskOperation.success(deleted);
  }

  Future<TaskOperation<int>> deleteCompletedTasks() async {
    final loaded = await _store.readTasks();
    if (loaded case TaskStoreReadFailure(:final message)) {
      return TaskOperation.failure(message);
    }

    final tasks = (loaded as TaskStoreReadSuccess).tasks;
    final remaining = tasks
        .where((task) => !task.complete)
        .toList(growable: false);
    final deletedCount = tasks.length - remaining.length;
    if (deletedCount == 0) return const TaskOperation.success(0);

    final saved = await _store.writeTasks(remaining);
    if (saved case TaskStoreWriteFailure(:final message)) {
      return TaskOperation.failure(message);
    }
    return TaskOperation.success(deletedCount);
  }

  Future<TaskOperation<List<Task>>> listTasks(TaskStatus status) async {
    final loaded = await _store.readTasks();
    if (loaded case TaskStoreReadFailure(:final message)) {
      return TaskOperation.failure(message);
    }

    final tasks = (loaded as TaskStoreReadSuccess).tasks;
    final filtered = switch (status) {
      TaskStatus.all => tasks,
      TaskStatus.complete =>
        tasks.where((task) => task.complete).toList(growable: false),
      TaskStatus.incomplete =>
        tasks.where((task) => !task.complete).toList(growable: false),
    };
    return TaskOperation.success(filtered);
  }
}

/// A list filter accepted by the `list` command.
enum TaskStatus { all, complete, incomplete }

sealed class TaskOperation<T> {
  const TaskOperation();

  const factory TaskOperation.success(T value) = TaskOperationSuccess<T>;
  const factory TaskOperation.failure(String message) = TaskOperationFailure<T>;
}

final class TaskOperationSuccess<T> extends TaskOperation<T> {
  const TaskOperationSuccess(this.value);

  final T value;
}

final class TaskOperationFailure<T> extends TaskOperation<T> {
  const TaskOperationFailure(this.message);

  final String message;
}
