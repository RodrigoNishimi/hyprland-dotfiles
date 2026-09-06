#!/usr/bin/env python3
"""Read configured shortcuts; commands in the catalog are never executed."""
import collections
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

def publish(query=''):
    data = json.loads(CACHE.read_text())
    query = query.casefold()
    groups = collections.OrderedDict()
    for row in data['rows']:
        if query in ' '.join(str(v) for v in row.values()).casefold():
            groups.setdefault(row['section'], []).append(row)
    payload = [{'name': name, 'rows': rows} for name, rows in groups.items()]
    run('eww', 'update', 'shortcuts_groups=' + json.dumps(payload, ensure_ascii=False),
        'shortcuts_count=' + str(sum(len(g['rows']) for g in payload)),
        'shortcuts_warning=' + '\n'.join(data['warnings']))

if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'search':
        publish(' '.join(sys.argv[2:]))
    elif len(sys.argv) > 1 and sys.argv[1] == 'collect':
        rows, warnings = collect()
        print(json.dumps(dict(counts=dict(collections.Counter(r['section'] for r in rows)), warnings=warnings), ensure_ascii=False))
    else:
        import fcntl
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
                run('eww', 'update', 'shortcuts_groups=[]', 'shortcuts_count=0')
                run('eww', 'open', 'shortcuts')
                publish()
