#!/usr/bin/env python3
"""OCR, persistent monitor profiles and independent Hyprland scratchpads."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time


def config_dir():
    return Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'hypr'


def data_dir():
    return Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share'))


def runtime_dir():
    root = Path(os.environ.get('XDG_RUNTIME_DIR', Path.home() / '.cache')) / 'hyprland-tools'
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    return root


def notify(title, body):
    subprocess.run(['notify-send', '-a', 'Hyprland', '-t', '4000', title, body], check=False)


def query(*args):
    return json.loads(subprocess.check_output(['hyprctl', '-j', *args], text=True))


def evaluate(code):
    result = subprocess.run(['hyprctl', 'eval', code], text=True, capture_output=True, check=True)
    if result.stdout.strip() != 'ok':
        raise RuntimeError(result.stdout.strip() or result.stderr.strip() or 'Hyprland não respondeu.')


def lua(value):
    """Serialize data only; monitor names and saved values are never Lua code."""
    if isinstance(value, str):
        # JSON's control/unicode escapes are not all valid Lua escapes.
        return '"' + ''.join(chr(b) if 32 <= b < 127 and b not in (34, 92)
                             else '\\%03d' % b for b in value.encode('utf-8')) + '"'
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, (int, float)):
        if not float('-inf') < value < float('inf'):
            raise ValueError('Número inválido no perfil.')
        return str(value)
    if isinstance(value, dict):
        return '{' + ', '.join('[' + lua(k) + '] = ' + lua(v) for k, v in value.items()) + '}'
    raise ValueError('Valor inválido no perfil.')


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, delete=False) as file:
        temporary = Path(file.name)
        json.dump(value, file, ensure_ascii=False, indent=2)
        file.write('\n')
    try:
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def ocr():
    selected = subprocess.run(['slurp'], text=True, capture_output=True)
    if selected.returncode or not selected.stdout.strip():
        return
    languages = subprocess.run(['tesseract', '--list-langs'], text=True,
                               capture_output=True, check=True).stdout.splitlines()
    options = []
    if not {'por', 'eng'}.issubset(languages):
        local = data_dir() / 'tessdata'
        if all((local / (lang + '.traineddata')).is_file() for lang in ('por', 'eng')):
            options = ['--tessdata-dir', str(local)]
        else:
            raise RuntimeError('Instale tesseract-data-por e tesseract-data-eng para usar OCR.')
    with tempfile.TemporaryDirectory(prefix='hypr-ocr-') as temporary:
        image = Path(temporary) / 'selection.png'
        subprocess.run(['grim', '-g', selected.stdout.strip(), str(image)], check=True)
        text = subprocess.run(['tesseract', str(image), 'stdout', *options, '-l', 'por+eng', '--psm', '6'],
                              text=True, capture_output=True, check=True).stdout.strip()
    if not text:
        notify('OCR', 'Nenhum texto reconhecido. A área de transferência foi preservada.')
        return
    subprocess.run(['wl-copy', '--type', 'text/plain;charset=utf-8'], input=text, text=True, check=True)
    notify('OCR', 'Texto copiado para a área de transferência.')


def topology(monitors):
    return json.dumps(sorted((m['name'], m.get('description', '')) for m in monitors), ensure_ascii=False)


def monitor_plan(monitors, profile):
    ordered = sorted(monitors, key=lambda m: (not m['name'].startswith(('eDP-', 'LVDS-', 'DSI-')), m['name']))
    if not ordered:
        return []
    primary = ordered[0]['name']
    plan = []
    for index, monitor in enumerate(ordered):
        plan.append(dict(output=monitor['name'], mode='preferred', position='0x0' if index == 0 else 'auto-right',
                         scale=1, transform=0, disabled=profile == 'notebook' and index > 0,
                         mirror=primary if profile == 'presentation' and index > 0 else ''))
    return plan


def capture_layout(monitors):
    return [dict(output=m['name'], mode=f"{m['width']}x{m['height']}@{m['refreshRate']:g}" if not m.get('disabled') else 'preferred',
                 position=f"{m['x']}x{m['y']}", scale=m.get('scale', 1) or 1,
                 transform=m.get('transform', 0), disabled=m.get('disabled', False),
                 mirror=m.get('mirrorOf', '') if m.get('mirrorOf') not in ('none', None) else '')
            for m in monitors]


def pick_monitor_profile():
    choices = {'Automático / layout salvo': 'auto', 'Notebook / uma tela': 'notebook',
               'Mesa / telas estendidas': 'desk', 'Apresentação / espelhar': 'presentation',
               'Salvar disposição atual': 'save'}
    choice = subprocess.run(['rofi', '-dmenu', '-i', '-p', 'Monitores', '-no-custom'],
                            input='\n'.join(choices), text=True, capture_output=True)
    return choices.get(choice.stdout.strip()) if choice.returncode == 0 else None


def monitors(action, force=False):
    path = config_dir() / 'monitor-profiles.json'
    config = json.loads(path.read_text()) if path.exists() else {}
    screens = query('monitors', 'all')
    if not screens:
        return
    key = topology(screens)
    selected = config.setdefault('selected', {})
    layouts = config.setdefault('layouts', {})
    if action == 'save':
        layouts[key] = capture_layout(screens)
        selected[key] = 'auto'
        write_json(path, config)
        notify('Monitores', 'Disposição salva para este conjunto de telas.')
        return
    profile = selected.get(key, 'auto') if action == 'apply' else action
    plan = layouts.get(key) if profile == 'auto' else None
    if not plan:
        plan = monitor_plan(screens, profile)
    # Refuse layouts that could leave the user without any usable screen.
    outputs = {m['name'] for m in screens}
    if {p['output'] for p in plan} != outputs or not any(not p.get('disabled') and not p.get('mirror') for p in plan):
        raise ValueError('O perfil precisa incluir todas as telas e manter uma tela principal ativa.')
    # Enabling the primary before disabling others also lets Hyprland migrate workspaces.
    plan = sorted(plan, key=lambda p: (bool(p.get('disabled')), bool(p.get('mirror'))))
    stamp = runtime_dir() / 'monitors-applied.json'
    fingerprint = hashlib.sha256((os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', '') + key + json.dumps(plan, sort_keys=True)).encode()).hexdigest()
    previous = json.loads(stamp.read_text()) if stamp.exists() else None
    if force or action != 'apply' or previous != fingerprint:
        evaluate('\n'.join('hl.monitor(' + lua(item) + ')' for item in plan))
        write_json(stamp, fingerprint)
    if action != 'apply':
        selected[key] = profile
        write_json(path, config)
        notify('Monitores', 'Perfil aplicado e salvo para este conjunto de telas.')


def scratch(name):
    app_class = 'local.scratch.' + name
    workspace = 'quick-' + name
    if not any(window['class'] == app_class for window in query('clients')):
        if name == 'terminal':
            command = ['tmux', 'new-session', '-A', '-s', 'quick-terminal']
        elif name == 'notes':
            notes = data_dir() / 'quick-notes/notes.md'
            notes.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            command = ['nvim', str(notes)]
        else:
            command = ['yazi', str(Path.home())]
        subprocess.Popen(['ghostty', '--class=' + app_class, '-e', *command],
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
        for _ in range(100):
            if any(window['class'] == app_class for window in query('clients')):
                break
            time.sleep(0.1)
        else:
            raise RuntimeError('A janela não abriu. Verifique Ghostty e o aplicativo solicitado.')
    evaluate('hl.dispatch(hl.dsp.workspace.toggle_special(' + json.dumps(workspace) + '))')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('ocr')
    monitor_parser = commands.add_parser('monitors')
    monitor_parser.add_argument('action', choices=['pick', 'apply', 'auto', 'notebook', 'desk', 'presentation', 'save'], default='pick', nargs='?')
    monitor_parser.add_argument('--force', action='store_true')
    commands.add_parser('scratch').add_argument('name', choices=['terminal', 'notes', 'files'])
    args = parser.parse_args()
    lock_name = args.command + ('-' + args.name if args.command == 'scratch' else '')
    try:
        # Do not hold the hotplug lock or cache the connected outputs while the
        # user is deciding in Rofi: a screen may be unplugged in the meantime.
        if args.command == 'monitors' and args.action == 'pick':
            args.action = pick_monitor_profile()
            if args.action is None:
                return 0
        with (runtime_dir() / (lock_name + '.lock')).open('w') as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                return 0
            if args.command == 'ocr':
                ocr()
            elif args.command == 'monitors':
                monitors(args.action, args.force)
            else:
                scratch(args.name)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f'Erro: {error}', file=sys.stderr)
        try:
            notify('Hyprland', str(error))
        except OSError:
            pass
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
