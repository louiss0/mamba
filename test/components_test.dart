import 'dart:io';

import 'package:mamba/mamba.dart';
import 'package:test/test.dart';

import 'fixtures/clix_io.dart';

final class RecordingSpinner() extends Spinner {
  this : super('Test');

  var active = false;
  var completed = false;
  var failed = false;

  @override
  void start() => active = true;
  @override
  void stop() => active = false;
  @override
  void complete([String? message]) => completed = true;
  @override
  void fail([String? message]) => failed = true;
}

void main() {
  test(
    'selector chooses an option by its displayed number without raw input',
    () async {
      final io = ScriptedCliIO(['2']);
      final value = await ClixSelector(
        prompt: 'Choose',
        options: ['Alpha', 'Beta'],
      ).interact(io);
      expect(value, 'Beta');
      expect(io.output.toString(), contains('2. Beta'));
    },
  );

  test('selector retries numbers outside the displayed range', () async {
    final io = ScriptedCliIO(['0', '3', '1']);
    expect(
      await ClixSelector(
        prompt: 'Choose',
        options: ['Alpha', 'Beta'],
      ).interact(io),
      'Alpha',
    );
    expect(io.reads, 3);
    expect(io.output.toString(), contains('Enter a number from 1 to 2.'));
  });

  test(
    'selector filters case-insensitively and retries a missing query',
    () async {
      final io = ScriptedCliIO(['missing', 'AL', '2']);
      expect(
        await ClixSelector(
          prompt: 'Choose',
          options: ['Alpha', 'Alpine', 'Beta'],
        ).interact(io),
        'Alpine',
      );
      expect(io.output.toString(), contains('No options match.'));
      expect(io.output.toString(), contains('2. Alpine'));
      expect(io.reads, 3);
    },
  );

  test('selector cancels on a blank line', () async {
    final io = ScriptedCliIO(['']);
    expect(
      await ClixSelector(prompt: 'Choose', options: ['Alpha']).interact(io),
      isNull,
    );
    expect(io.reads, 1);
  });

  test('selector with no choices returns without reading input', () async {
    final io = ScriptedCliIO([]);
    expect(
      await ClixSelector(prompt: 'Choose', options: []).interact(io),
      isNull,
    );
    expect(io.reads, 0);
  });

  test(
    'picker browses sorted directories and confirms the current directory',
    () async {
      final root = Directory.systemTemp.createTempSync('mamba_clix_picker_');
      addTearDown(() => root.deleteSync(recursive: true));
      final zulu = Directory('${root.path}${Platform.pathSeparator}Zulu')
        ..createSync();
      Directory('${root.path}/Alpha').createSync();
      File('${root.path}/ignored.txt').writeAsStringSync('not a directory');
      final io = ScriptedCliIO(['4', '1']);
      final selected = await ClixDirectoryPicker(
        prompt: 'Pick',
        startDirectory: root,
      ).interact(io);
      expect(selected, zulu.absolute.path);
      expect(io.output.toString(), contains('3. Alpha/'));
      expect(io.output.toString(), isNot(contains('ignored.txt')));
    },
  );

  test('picker can navigate to its parent directory', () async {
    final root = Directory.systemTemp.createTempSync('mamba_clix_parent_');
    addTearDown(() => root.deleteSync(recursive: true));
    final child = Directory('${root.path}/child')..createSync();
    expect(
      await ClixDirectoryPicker(
        prompt: 'Pick',
        startDirectory: child,
      ).interact(ScriptedCliIO(['2', '1'])),
      root.absolute.path,
    );
  });

  test(
    'picker cancels from its default current directory on a blank line',
    () async {
      expect(
        await ClixDirectoryPicker(prompt: 'Pick').interact(ScriptedCliIO([''])),
        isNull,
      );
    },
  );

  test('spinner completes and stops after returning the work result', () async {
    final spinner = RecordingSpinner();
    expect(spinner.active, isTrue);
    expect(await spinner.whileRunning(() async => 17), 17);
    expect(spinner.completed, isTrue);
    expect(spinner.active, isFalse);
  });

  test('spinner stops and rethrows the original work error', () async {
    final spinner = RecordingSpinner();
    final error = StateError('work failed');
    await expectLater(
      spinner.whileRunning<int>(() async => throw error),
      throwsA(same(error)),
    );
    expect(spinner.failed, isTrue);
    expect(spinner.active, isFalse);
  });
}
