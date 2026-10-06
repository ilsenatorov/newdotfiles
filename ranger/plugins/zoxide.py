import shutil
import subprocess

import ranger.api


_previous_hook_init = ranger.api.hook_init


def hook_init(fm):
    _previous_hook_init(fm)
    if not shutil.which('zoxide'):
        return

    def record_directory(signal):
        if signal.previous and signal.previous.path == signal.new.path:
            return
        result = subprocess.run(
            ['zoxide', 'add', '--', signal.new.path],
            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
        )
        if result.returncode:
            fm.notify('zoxide: ' + result.stderr.decode(errors='replace').strip(), bad=True)

    fm.signal_bind('cd', record_directory)


ranger.api.hook_init = hook_init
