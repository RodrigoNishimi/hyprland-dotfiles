#!/usr/bin/env python3
"""Read configured shortcuts; commands in the catalog are never executed."""
import collections
import fcntl
import hashlib
import shlex
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import tomllib

BASE = Path(__file__).resolve().parent
HOME = Path.home()
CACHE = HOME / '.cache/eww/keybinds.json'
VIEW = CACHE.with_name('keybinds-view.json')
FAVORITES = Path(os.environ.get('XDG_STATE_HOME', HOME / '.local/state')) / 'eww/keybinds-favorites.json'

def run(*args, **kwargs):
    return subprocess.run(args, text=True, capture_output=True, timeout=25, check=True, **kwargs).stdout

def collect():
    rows, warnings = [], []
    def add(section, context, key, description, source):
        rows.append(dict(section=section, context=context, key=key.strip(),
                         description=description.strip(), source=str(source)))
    try:
        for line in run('lua', str(BASE / 'keybinds/hypr.lua')).splitlines():
            context, key, action = line.split('\t', 2)
            add('Hyprland', context or 'Global', re.sub(r'\s*\+\s*', ' + ', key), action,
                HOME / '.config/hypr/conf/keybinds.lua')
    except Exception as e:
        warnings.append('Hyprland: ' + str(e))
    try:
        prefix = run('tmux', 'show-options', '-gv', 'prefix').strip()
        for line in run('tmux', 'list-keys').splitlines():
            match = re.match(r'bind-key\s+(?:-r\s+)?-T\s+(\S+)\s+(\S+)\s+(.+)', line)
            if match:
                table, key, command = match.groups()
                add('Tmux', table, (prefix + ' → ' if table == 'prefix' else '') + key,
                    command, 'tmux list-keys (servidor ativo)')
    except Exception:
        warnings.append('Tmux sem servidor acessível: abra uma sessão para listar as teclas ativas.')
    try:
        with tempfile.TemporaryDirectory(prefix='keybinds-') as tmp:
            output = Path(tmp) / 'nvim.json'
            run('nvim', '--headless', '-i', 'NONE', '+luafile ' + str(BASE / 'keybinds/nvim.lua'),
                env={**os.environ, 'KEYBINDS_NVIM_OUTPUT': str(output)})
            rows.extend(json.loads(output.read_text()))
    except Exception as e:
        warnings.append('Nvim: ' + str(e))
    yazi = HOME / '.config/yazi/keymap.toml'
    if yazi.exists():
        for context, config in tomllib.loads(yazi.read_text()).items():
            for kind in ('prepend_keymap', 'keymap', 'append_keymap'):
                for entry in config.get(kind, []):
                    key = entry['on']
                    add('Yazi', context, ' → '.join(key) if isinstance(key, list) else key,
                        entry.get('desc', str(entry['run'])), yazi)
    zsh = HOME / '.zshrc'
    for line in zsh.read_text().splitlines():
        m = re.match(r'''\s*bindkey\s+(?:-s\s+)?(['"])(.*?)\1\s+(.+)''', line)
        if m:
            add('Zsh', 'Emacs', m[2], m[3], zsh)
    # These are context-dependent plugin maps and are not global Nvim maps.
    for file, context in [('cmp.lua', 'Autocompletar / snippets')]:
        path = HOME / '.config/nvim/lua/NeoVim/plugins' / file
        content = path.read_text()
        for m in re.finditer(r'\["([^"\n]+)"\]\s*=\s*\{([^}]+)', content):
            action = 'Expandir snippet LuaSnip' if 'ls.expandable' in m[2] else ' / '.join(re.findall(r'"([^"]+)"', m[2]))
            add('Nvim', context, m[1], action, path)
    descriptions = json.loads((BASE / 'keybinds/descriptions.json').read_text())
    for row in rows:
        if row['section'] == 'Hyprland':
            key = row['key']
            original = row['description']
            row['source'] += '\n' + original
            if row['context'] == 'resize':
                row['description'] = 'Sair do modo de redimensionamento' if key.lower() == 'escape' else 'Redimensionar janela: ' + original
            elif key in descriptions:
                row['description'] = descriptions[key]
            elif re.fullmatch(r'SUPER \+ (SHIFT \+ )?[0-9]', key):
                row['description'] = ('Mover janela para workspace ' if 'SHIFT' in key else 'Ir para workspace ') + str(int(key[-1]) or 10)
            elif key[-1:] in 'HJKL':
                direction = {'H': 'esquerda', 'J': 'baixo', 'K': 'cima', 'L': 'direita'}[key[-1]]
                row['description'] = ('Mover janela para ' if 'SHIFT' in key else 'Focar janela à direção: ') + direction
        elif row['section'] == 'Nvim' and row['description'].startswith('vim.keymap'):
            original = row['description']
            row['source'] += '\n' + original
            body = re.search(r'function\s*\([^)]*\)\s*(.*)', original)
            if body:
                row['description'] = re.sub(r'\s*end\)?\s*$', '', body[1])
        row['description'] = re.sub(r'\s+', ' ', row['description']) or 'Mapeamento interno do Nvim'
    rows.sort(key=lambda r: (['Hyprland','Tmux','Nvim','Yazi','Zsh'].index(r['section']), r['context'], r['key']))
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    temporary = CACHE.with_suffix('.tmp')
    temporary.write_text(json.dumps({'rows': rows, 'warnings': warnings}, ensure_ascii=False))
    temporary.replace(CACHE)
    return rows, warnings

def configured_tmux_binds():
    """Read explicit binds, including quoted conditional commands, without executing them."""
    path = HOME / '.tmux.conf'
    if not path.exists():
        return {}
    binds = {}
    def parse(command):
        try:
            tokens = shlex.split(command, comments=True)
        except ValueError:
            return
        if not tokens:
            return
        if tokens[0] in ('bind', 'bind-key'):
            table, i = 'prefix', 1
            while i < len(tokens) and tokens[i].startswith('-'):
                option = tokens[i]
                i += 1
                if option in ('-T', '-N') and i < len(tokens):
                    if option == '-T':
                        table = tokens[i]
                    i += 1
                elif option == '-n':
                    table = 'root'
            if i < len(tokens) - 1:
                binds[(table, tokens[i])] = shlex.join(tokens[i + 1:])
        elif tokens[0] in ('if-shell', 'if'):
            for token in tokens[1:]:
                if re.match(r'^(bind-key|bind)\s', token):
                    parse(token)
    for line in re.sub(r'\\\n', ' ', path.read_text()).splitlines():
        parse(line)
    return binds


def tmux_key(key):
    key = key.split(' → ', 1)[-1]
    try:
        return shlex.split(key)[0]
    except (ValueError, IndexError):
        return key


def row_id(row):
    key = row['key']
    if row['section'] == 'Tmux':
        key = tmux_key(key)
    value = json.dumps([row['section'], row['context'], key], ensure_ascii=False)
    return hashlib.sha256(value.encode()).hexdigest()[:20]


def favorite_defaults(rows):
    configured = configured_tmux_binds()
    return {row_id(row) for row in rows if row['section'] == 'Tmux'
            and (row['context'], tmux_key(row['key'])) in configured}


def favorite_overrides():
    return json.loads(FAVORITES.read_text()) if FAVORITES.exists() else {}


def toggle_favorite(identity, rows):
    if identity not in {row_id(row) for row in rows}:
        raise ValueError('Atalho desconhecido')
    FAVORITES.parent.mkdir(parents=True, exist_ok=True)
    with FAVORITES.with_suffix('.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        overrides = favorite_overrides()
        overrides[identity] = not overrides.get(identity, identity in favorite_defaults(rows))
        temporary = FAVORITES.with_suffix('.tmp')
        temporary.write_text(json.dumps(overrides))
        temporary.replace(FAVORITES)


def build_payload(rows, query='', favorites_only=False):
    defaults, overrides = favorite_defaults(rows), favorite_overrides()
    groups = collections.OrderedDict()
    for original in rows:
        identity = row_id(original)
        favorite = overrides.get(identity, identity in defaults)
        if favorites_only and not favorite:
            continue
        if query.casefold() not in ' '.join(str(v) for v in original.values()).casefold():
            continue
        row = dict(original, id=identity, favorite=favorite)
        groups.setdefault(row['section'], []).append(row)
    return [{'name': name, 'rows': rows} for name, rows in groups.items()]


def write_view(payload):
    VIEW.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode='w', dir=VIEW.parent, delete=False) as output:
        json.dump(payload, output, ensure_ascii=False, separators=(',', ':'))
        output.write('\n')
        temporary = Path(output.name)
    temporary.replace(VIEW)


def listen():
    VIEW.parent.mkdir(parents=True, exist_ok=True)
    # Watch the cache directory because view updates replace the file atomically.
    with subprocess.Popen(['inotifywait', '-m', '-q', '-e', 'moved_to,close_write',
                           '--format', '%f', str(VIEW.parent)],
                          stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True) as watcher:
        print(VIEW.read_text().strip() if VIEW.exists() else '[]', flush=True)
        try:
            for filename in watcher.stdout:
                if filename.strip() == VIEW.name:
                    print(VIEW.read_text().strip(), flush=True)
        finally:
            watcher.terminate()


def publish(query=None, favorites_only=None):
    data = json.loads(CACHE.read_text())
    if query is None:
        query = run('eww', 'get', 'shortcuts_query').rstrip('\n')
    if favorites_only is None:
        favorites_only = run('eww', 'get', 'shortcuts_favorites_only').strip() == 'true'
    payload = build_payload(data['rows'], query, favorites_only)
    write_view(payload)
    run('eww', 'update',
        'shortcuts_count=' + str(sum(len(g['rows']) for g in payload)),
        'shortcuts_query=' + query,
        'shortcuts_favorites_only=' + str(favorites_only).lower(),
        'shortcuts_warning=' + '\n'.join(data['warnings']))

if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'listen':
        listen()
    elif len(sys.argv) > 1 and sys.argv[1] == 'search':
        publish(' '.join(sys.argv[2:]))
    elif len(sys.argv) > 1 and sys.argv[1] == 'favorites':
        publish(favorites_only=True)
    elif len(sys.argv) > 1 and sys.argv[1] == 'all':
        publish(query='', favorites_only=False)
    elif len(sys.argv) > 2 and sys.argv[1] == 'favorite':
        toggle_favorite(sys.argv[2], json.loads(CACHE.read_text())['rows'])
        publish()
    elif len(sys.argv) > 1 and sys.argv[1] == 'collect':
        rows, warnings = collect()
        print(json.dumps(dict(counts=dict(collections.Counter(r['section'] for r in rows)), warnings=warnings), ensure_ascii=False))
    else:
        CACHE.parent.mkdir(parents=True, exist_ok=True)
        with (CACHE.parent / 'keybinds.lock').open('w') as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                sys.exit(0)
            if 'shortcuts: shortcuts' in run('eww', 'active-windows'):
                run('eww', 'close', 'shortcuts')
            else:
                collect()
                # Realize the scroll window before inserting hundreds of rows.
                write_view([])
                run('eww', 'update', 'shortcuts_count=0')
                run('eww', 'open', 'shortcuts')
                publish(query='', favorites_only=False)
