import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('keybinds', Path(__file__).parents[1] / 'scripts/keybinds.py')
k = importlib.util.module_from_spec(spec)
spec.loader.exec_module(k)

class FavoritesTest(unittest.TestCase):
    def test_custom_tmux_defaults_and_persistent_removal(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            (home / '.tmux.conf').write_text('set -g prefix C-Space\nbind r source-file ~/.tmux.conf\nbind-key -n M-H select-pane -L\nif-shell "command -v zsh" \'bind-key H display-popup -E zsh\'\n# bind x ignored\n')
            with patch.object(k, 'HOME', home), patch.object(k, 'FAVORITES', home / 'favorites.json', create=True):
                rows = [dict(section='Tmux', context='prefix', key='C-Space → r', description='reload', source='runtime'), dict(section='Tmux', context='root', key='M-H', description='left', source='runtime'), dict(section='Tmux', context='prefix', key='C-Space → H', description='popup', source='runtime'), dict(section='Tmux', context='prefix', key='C-Space → x', description='default', source='runtime')]
                self.assertTrue(callable(getattr(k, 'build_payload', None)), 'Filtro de favoritos ainda não implementado')
                payload = k.build_payload(rows, '', True)
                self.assertEqual([r['key'] for r in payload[0]['rows']], ['C-Space → r', 'M-H', 'C-Space → H'])
                identity = payload[0]['rows'][0]['id']
                k.toggle_favorite(identity, rows)
                self.assertEqual([r['key'] for r in k.build_payload(rows, '', True)[0]['rows']], ['M-H', 'C-Space → H'])
                rows[0]['key'] = 'C-a → r'
                self.assertFalse(k.build_payload(rows, '', False)[0]['rows'][0]['favorite'])

    def test_escaped_tmux_key_is_favorited(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            (home / '.tmux.conf').write_text(r'bind-key \{ run-shell tmux-relative-numbers')
            with patch.object(k, 'HOME', home), patch.object(k, 'FAVORITES', home / 'favorites.json'):
                rows = [dict(section='Tmux', context='prefix', key=r'C-Space → \{', description='numbers', source='runtime')]
                self.assertEqual(len(k.build_payload(rows, '', True)), 1)

    def test_large_catalog_published_without_large_arguments(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            cache = home / 'catalog.json'
            cache.write_text(k.json.dumps({'rows': [dict(section='Zsh', context='Emacs', key='^R', description='x' * 140000, source='config')], 'warnings': []}))
            # The fake CLI captures the command boundary; payload must travel by file.
            calls = []
            with patch.object(k, 'HOME', home), patch.object(k, 'CACHE', cache), patch.object(k, 'VIEW', home / 'view.json', create=True), patch.object(k, 'FAVORITES', home / 'favorites.json'), patch.object(k, 'run', side_effect=lambda *args: calls.append(args) or ''):
                k.publish('', False)
                self.assertTrue(all(len(arg.encode()) < 131072 for call in calls for arg in call))
                self.assertEqual(len(k.json.loads((home / 'view.json').read_text())[0]['rows'][0]['description']), 140000)

    def test_add_favorite_and_search_in_favorites(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            with patch.object(k, 'HOME', home), patch.object(k, 'FAVORITES', home / 'favorites.json', create=True):
                rows = [dict(section='Zsh', context='Emacs', key='^R', description='Buscar histórico', source='config')]
                self.assertTrue(callable(getattr(k, 'build_payload', None)), 'Filtro de favoritos ainda não implementado')
                self.assertEqual(k.build_payload(rows, '', True), [])
                identity = k.build_payload(rows, '', False)[0]['rows'][0]['id']
                k.toggle_favorite(identity, rows)
                self.assertEqual(len(k.build_payload(rows, 'HISTÓRICO', True)[0]['rows']), 1)
                self.assertEqual(k.build_payload(rows, 'ausente', True), [])
                k.toggle_favorite(identity, rows)
                self.assertEqual(k.build_payload(rows, '', True), [])

if __name__ == '__main__':
    unittest.main()
