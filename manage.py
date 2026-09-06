#!/usr/bin/env python3
"""Capture and install an explicit selection of desktop settings."""
import argparse
import fnmatch
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parent
APPS = 'hypr eww alacritty ghostty mako rofi waybar quickshell nvim tmux yazi zathura btop fastfetch gtk-3.0 gtk-4.0 qt5ct qt6ct xsettingsd uwsm tmux-sessionizer lazygit'.split()
ROOTS = [f'.config/{a}' for a in APPS] + ['.config/starship.toml', '.zshrc', '.zprofile', '.bashrc', '.tmux.conf', '.gtkrc-2.0']
BINS = 'printAndEdit ready-tmux rofi-script run testar-cor theme tmux-lazygit tmux-relative-numbers tmux-sessionizer window-info'.split()
ROOTS += [f'.local/bin/{b}' for b in BINS]
ROOTS += ['.local/share/fonts', '.local/state/dotfiles/current-theme', '.local/state/dotfiles/profile']
ROOTS += ['plugins/gruber-darker', 'plugins/present', '.config/nwg-look',
          '.local/share/nwg-look', '.config/mimeapps.list', '.config/git/ignore',
          '.local/share/applications/claude-code-url-handler.desktop', '.bash_profile', '.bash_logout']
ASSETS = '.local/share/hyprland-dotfiles'
SKIP = ['.git', '__pycache__', '*.pyc', '*.bak*', '.backup*', '*~', '*.zip', 'history', '*.log', 'cover.png']

def exists(p):
    return p.exists() or p.is_symlink()

def copy(src, dst):
    dst.parent.mkdir(parents=True, exist_ok=True)
    if src.is_dir():
        shutil.copytree(src, dst, ignore=lambda _, names: [n for n in names if any(fnmatch.fnmatch(n, pat) for pat in SKIP)])
    else:
        shutil.copy2(src, dst)

def rewrite(root, replacements):
    for path in root.rglob('*'):
        if not path.is_file():
            continue
        try:
            value = path.read_text()
        except (UnicodeError, OSError):
            continue
        for old, new in replacements:
            value = value.replace(old, new)
        path.write_text(value)

def safe_roots(roots):
    for rel in roots:
        p = Path(rel)
        if p.is_absolute() or '..' in p.parts or not p.parts or str(p) == '.':
            raise ValueError(f'Unsafe manifest path: {rel}')
    if len(set(roots)) != len(roots):
        raise ValueError('Duplicate roots')
    for a in roots:
        if any(a != b and Path(a) in Path(b).parents for b in roots):
            raise ValueError('Overlapping roots')
    return roots

def check_parents(home, roots):
    for rel in roots:
        for parent in (home / rel).parents:
            if parent == home:
                break
            if parent.is_symlink():
                raise ValueError(f'Parent is a symlink; resolve manually before installation: {parent}')

def deploy(src, dst):
    # Replace symlinks themselves, never write through them into another repo.
    if dst.is_symlink():
        dst.unlink()
    if src.is_dir():
        if dst.exists() and not dst.is_dir():
            raise ValueError(f'Directory required at {dst}')
        dst.mkdir(parents=True, exist_ok=True)
        for child in src.iterdir():
            deploy(child, dst / child.name)
    else:
        if dst.is_dir():
            raise ValueError(f'File required at {dst}')
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)

def capture(args):
    home = args.home
    if args.output.exists():
        raise ValueError('Output already exists; use a new directory to preserve the previous snapshot')
    stage = args.output
    stage.mkdir(parents=True, mode=0o700)
    roots = []
    for rel in ROOTS:
        if (home / rel).exists():
            copy(home / rel, stage / 'home' / rel)
            roots.append(rel)
    source = args.assets or (home / ASSETS if (home / ASSETS).exists() else home / 'dotfiles')
    for name in ['themes', 'wallpapers', 'zen-themes', 'profiles']:
        if (source / name).exists():
            copy(source / name, stage / 'home' / ASSETS / name)
    if (stage / 'home' / ASSETS).exists():
        roots.append(ASSETS)
    rewrite(stage / 'home', [(str(source), '@@ASSETS@@'), (str(home), '@@HOME@@')])
    # The original helpers derive their location from the Stow layout.
    for name in ['theme', 'rofi-script']:
        path = stage / 'home/.local/bin' / name
        if path.exists():
            text = path.read_text()
            lines = text.splitlines(keepends=True)
            path.write_text(''.join('DOTFILES="${DOTFILES:-$HOME/.local/share/hyprland-dotfiles}"\n' if line.startswith('DOTFILES=') else line for line in lines))
    telescope = stage / 'home/.config/nvim/lua/NeoVim/plugins/telescope.lua'
    if telescope.exists():
        telescope.write_text(telescope.read_text().replace('~/dotfiles/packages/nvim/.config/nvim', '~/.config/nvim'))
    sessionizer = stage / 'home/.local/bin/tmux-sessionizer'
    if sessionizer.exists():
        text = sessionizer.read_text().replace('DOTFILES="${DOTFILES:-$HOME/dotfiles}"', 'DOTFILES="${DOTFILES:-$HOME/hyprland-dotfiles}"')
        # Configs are now independent files, not Stow packages.
        text = text.replace('\nexclude_stowed_config\n', '\n# Stow exclusions no longer apply.\n')
        sessionizer.write_text(text)
    paths = stage / 'home/.config/tmux-sessionizer/paths'
    if paths.exists():
        paths.write_text(paths.read_text().replace('~/dotfiles/packages', '~/hyprland-dotfiles/snapshot/home/.config'))
    (stage / 'manifest.json').write_text(json.dumps({'roots': roots}, indent=2) + '\n')
    if shutil.which('pacman'):
        for flag, name in [('-Q', 'versions.txt'), ('-Qqe', 'explicit.txt'), ('-Qqm', 'foreign.txt')]:
            (stage / name).write_text(subprocess.check_output(['pacman', flag], text=True))
    print(f'Snapshot: {stage} ({len(roots)} roots). Review before committing.')

def install(args):
    roots = safe_roots(json.loads((args.source / 'manifest.json').read_text())['roots'])
    check_parents(args.home, roots)
    for rel in roots:
        if not (args.source / 'home' / rel).exists():
            raise ValueError(f'Missing source: {rel}')
        print(f'Apply: {rel}')
    if args.dry_run:
        return
    with tempfile.TemporaryDirectory(prefix='hyprland-dotfiles-') as temporary:
        stage = Path(temporary)
        for rel in roots:
            copy(args.source / 'home' / rel, stage / rel)
        rewrite(stage, [('@@ASSETS@@', str(args.home / ASSETS)), ('@@HOME@@', str(args.home))])
        if args.monitors == 'auto' and '.config/hypr' in roots:
            (stage / '.config/hypr/conf/monitors.lua').write_text('hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })\n')
        uwsm = stage / '.config/uwsm/env'
        if getattr(args, 'gpu', 'auto') == 'auto' and uwsm.exists():
            uwsm.write_text(''.join(line for line in uwsm.read_text().splitlines(keepends=True) if not line.startswith(('export LIBVA_DRIVER_NAME=', 'export __GLX_VENDOR_LIBRARY_NAME='))))
        for rel in roots:
            deploy(stage / rel, args.home / rel)
    print('Applied. Log in to a new Hyprland session when ready.')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    for name in ['capture', 'install']:
        p = sub.add_parser(name)
        p.add_argument('--home', type=Path, default=Path.home())
        if name == 'capture':
            p.add_argument('--output', type=Path, required=True)
            p.add_argument('--assets', type=Path)
        else:
            p.add_argument('--dry-run', action='store_true')
        if name == 'install':
            p.add_argument('--source', type=Path, default=REPO / 'snapshot')
            p.add_argument('--monitors', choices=['auto', 'original'], default='auto')
            p.add_argument('--gpu', choices=['auto', 'original'], default='auto')
    args = parser.parse_args()
    args.home = args.home.expanduser().resolve()
    if str(args.home) == '/':
        parser.error('The filesystem root cannot be a target home')
    try:
        {'capture': capture, 'install': install}[args.command](args)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f'Error: {error}\n')

if __name__ == '__main__':
    main()
