import os
import shlex
import subprocess

from ranger.api.commands import Command


def _fzf_select(fm, source):
    preview = (
        'if [ -d {} ]; then ls -A -1 --color=always -- {}; '
        'else bat --color=always --paging=never --style=plain '
        '--line-range=1:200 -- {}; fi'
    )
    picker = shlex.join([
        'fzf', '--read0', '--print0', '+m', '--layout=reverse',
        '--bind=ctrl-j:down,ctrl-k:up,ctrl-/:toggle-preview',
        '--header=Enter: select · Esc: cancel · Ctrl-J/K: move · Ctrl-/: preview',
        '--preview', preview, '--preview-window=right:50%',
    ])
    process = fm.execute_command(
        source + ' | ' + picker, stdout=subprocess.PIPE, cwd=fm.thisdir.path,
    )
    if not process:
        return
    stdout, _ = process.communicate()
    if process.returncode == 0 and stdout:
        path = os.path.abspath(os.path.join(
            fm.thisdir.path, os.fsdecode(stdout.removesuffix(b'\0')),
        ))
        if os.path.isdir(path):
            fm.cd(path)
        elif os.path.lexists(path):
            fm.select_file(path)
        else:
            fm.notify('Path no longer exists: ' + path, bad=True)


class fzf_select(Command):
    """:fzf_select — search below the current directory; prefix 1 for directories.

    Respects gitignore; includes dotfiles when Ranger's show_hidden is enabled.
    """

    def execute(self):
        source = ['fd', '--print0']
        if self.quantifier:
            source += ['--type', 'd']
        if self.fm.settings.show_hidden:
            source += ['--hidden']
        _fzf_select(self.fm, shlex.join(source))


class fzf_locate(Command):
    """:fzf_locate — search the system's locate database with previews."""

    def execute(self):
        _fzf_select(self.fm, 'locate --null /')


class zoxide_jump(Command):
    """:zoxide_jump [keywords] — pick a frequently visited directory."""

    def execute(self):
        process = self.fm.execute_command(
            ['zoxide', 'query', '--interactive', '--'] + shlex.split(self.rest(1)),
            stdout=subprocess.PIPE,
        )
        if not process:
            return
        stdout, _ = process.communicate()
        if process.returncode == 0 and stdout:
            self.fm.cd(os.fsdecode(stdout.removesuffix(b'\n')))

class gdrive(Command):
    """
    Uploads the selected files to google drive via gdrive
    """
    def execute(self):
        file = self.fm.thisfile
        self.fm.run("gdrive upload \"{0}\" {1}".format(file.basename, self.rest(1)))
        self.fm.notify('Done!')

class ftp(Command):
    def execute(self):
        file = self.fm.thisfile
        self.fm.run("scp \"{0}\" {1} pi:/mnt/ftp/storage/".format(file.basename, self.rest(1)))
        self.fm.notify('Done!')
