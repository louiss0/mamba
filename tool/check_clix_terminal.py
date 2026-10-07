"""Windows ConPTY regression checks for Mamba's Clix-backed components.

Run with Python 3.13 and pywinpty==3.0.5. Uses synthetic input and a recording
scaffolder; never creates a project, installs dependencies, or initializes Git.
"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[1]
ANSI = re.compile(r'\x1b\[[0-?]*[ -/]*[@-~]')


def check(name, scenario, ready, keys, expected, extra=()):
    from winpty import Backend, PtyProcess
    process = PtyProcess.spawn(
        ['cmd.exe', '/d', '/c', DART, str(SNAPSHOT), scenario, *extra],
        cwd=str(ROOT), dimensions=(40, 120), backend=Backend.ConPTY,
    )
    chunks = []

    def read():
        try:
            while True:
                data = process.read(4096)
                if not data:
                    return
                chunks.append(data)
        except (EOFError, OSError):
            return

    def text():
        return ANSI.sub('', ''.join(chunks))

    def wait(marker, seconds=15):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            if marker in text():
                return
            time.sleep(0.02)
        raise RuntimeError(f'{name}: did not receive {marker!r}; output: {text()[-1000:]!r}')

    thread = threading.Thread(target=read, daemon=True)
    thread.start()
    try:
        wait(ready)
        for item in keys:
            if isinstance(item, tuple):
                marker, value = item
                wait(marker)
            else:
                value = item
            process.write(value)
            time.sleep(0.06)
        wait('CLIX_RESULT=')
        line = next(line for line in text().splitlines() if 'CLIX_RESULT=' in line)
        observed = json.loads(line.split('CLIX_RESULT=', 1)[1])
        if observed != expected:
            raise AssertionError(f'{name}: expected {expected!r}, received {observed!r}')
        print(f'PASS {name}: {observed!r}', flush=True)
    finally:
        process.close(force=True)
        thread.join(timeout=1)


if __name__ == '__main__':
    if os.name != 'nt':
        raise SystemExit('This check specifically exercises Windows console line editing.')
    DART = shutil.which('dart')
    if DART is None:
        raise SystemExit('dart was not found on PATH')
    SNAPSHOT = ROOT / '.dart_tool/clix_terminal.dill'
    subprocess.run([DART, 'compile', 'kernel', str(ROOT / 'test/fixtures/clix_terminal.dart'),
        '--output=' + str(SNAPSHOT)], cwd=ROOT, check=True, timeout=90)

    check('Backspace', 'input', 'Clix input', ['probeX', '\x7f', '\r'], 'probe')
    check('Left cursor', 'input', 'Clix input', ['ac', '\x1b[D', 'b', '\r'], 'abc')
    check('Delete', 'input', 'Clix input', ['abc', '\x1b[D', '\x1b[3~', '\r'], 'ab')
    check('Create answers', 'create', 'Install dependencies?', ['n\r',
        ('Initialize a Git repository?', 'y\r')],
        {'description': 'This is a CLI app', 'install': False, 'git': True})
    check('Create defaults', 'create', 'Install dependencies?', ['\r',
        ('Initialize a Git repository?', '\r')],
        {'description': 'This is a CLI app', 'install': True, 'git': False})
    check('Custom description', 'create-custom', 'Install dependencies?', ['n\r',
        ('Initialize a Git repository?', 'y\r')],
        {'description': 'Custom description', 'install': False, 'git': True})
    check('Create without input', 'create-flags', 'CLIX_RESULT=', [],
        {'description': 'This is a CLI app', 'install': True, 'git': True})
    check('Filtered selection', 'selector', 'Clix selection', ['Al\r', '2\r'], 'Alpine')
    check('Selection cancellation', 'selector', 'Clix selection', ['\r'], None)
    with tempfile.TemporaryDirectory(prefix='mamba-clix-') as directory:
        root = Path(directory)
        (root / 'Alpha').mkdir()
        (root / 'Beta').mkdir()
        check('Directory navigation', 'picker', 'Clix directory', ['4\r', '1\r'],
            str(root / 'Beta'), (str(root),))
        check('Directory cancellation', 'picker', 'Clix directory', ['\r'], None, (str(root),))
    print('All eleven Windows terminal checks passed.')
