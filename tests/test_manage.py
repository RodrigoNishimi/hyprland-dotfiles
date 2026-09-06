import importlib.util
import json
from pathlib import Path
import tempfile
import os
import subprocess
from types import SimpleNamespace
import unittest

spec = importlib.util.spec_from_file_location('manage', Path(__file__).resolve().parents[1] / 'manage.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class Installation(unittest.TestCase):
    def test_original_machine_snapshot_uses_current_assets_and_supported_refresh_rate(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            m.install(SimpleNamespace(home=home, source=m.REPO / 'snapshot', dry_run=False,
                                      monitors='original', gpu='original'))
            wallpaper = home / '.config/hypr/hyprpaper.conf'
            monitors = home / '.config/hypr/conf/monitors.lua'
            self.assertIn(str(home / '.local/share/hyprland-dotfiles/wallpapers/tropical-beach.jpeg'),
                          wallpaper.read_text())
            self.assertIn('1920x1080@60', monitors.read_text())
            self.assertNotIn('1920x1080@144', monitors.read_text())

    def test_full_snapshot_build_and_hyprland_validation(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            m.install(SimpleNamespace(home=home, source=m.REPO / 'snapshot', dry_run=False, monitors='auto'))
            env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / '.config'))
            subprocess.run(['lua', str(home / '.config/eww/lua/build.lua')], env=env, check=True)
            result = subprocess.run(['Hyprland', '--verify-config', '-c', str(home / '.config/hypr/hyprland.lua')], env=env, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertTrue((home / '.config/eww/bar.yuck').stat().st_size > 0)

    def test_install_preserves_unmanaged_files_and_original_symlink_target(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            home, source = base / 'other user', base / 'source'
            (home / '.config/hypr').mkdir(parents=True)
            (home / '.config/hypr/unmanaged').write_text('keep')
            original = base / 'old-repo'
            original.write_text('original')
            (home / '.zshrc').symlink_to(original)
            (source / 'home/.config/hypr/conf').mkdir(parents=True)
            (source / 'home/.config/hypr/conf/monitors.lua').write_text('original monitors')
            (source / 'home/.zshrc').write_text('@@HOME@@ @@ASSETS@@')
            (source / 'manifest.json').write_text(json.dumps({'roots': ['.config/hypr', '.zshrc']}))
            args = SimpleNamespace(home=home, source=source, dry_run=True, monitors='auto')
            m.install(args)
            self.assertTrue((home / '.zshrc').is_symlink())
            args.dry_run = False
            m.install(args)
            m.install(args)
            self.assertEqual(original.read_text(), 'original')
            self.assertEqual((home / '.config/hypr/unmanaged').read_text(), 'keep')
            self.assertIn(str(home), (home / '.zshrc').read_text())
            self.assertNotIn('@@', (home / '.zshrc').read_text())
            self.assertIn('preferred', (home / '.config/hypr/conf/monitors.lua').read_text())
            self.assertFalse((home / '.local/state/hyprland-dotfiles/backups').exists())

    def test_rejects_escape_and_overlapping_paths(self):
        for roots in [['../outside'], ['/etc'], ['.'], ['.config', '.config/hypr']]:
            with self.assertRaises(ValueError):
                m.safe_roots(roots)

    def test_capture_dereferences_config_and_excludes_backups(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            home = base / 'home'
            home.mkdir()
            original = base / 'original'
            original.write_text(str(home) + '/test')
            (home / '.zshrc').symlink_to(original)
            (home / '.config/eww').mkdir(parents=True)
            (home / '.config/eww/old.bak').write_text('exclude')
            output = base / 'snapshot'
            m.capture(SimpleNamespace(home=home, output=output, assets=None))
            self.assertFalse((output / 'home/.zshrc').is_symlink())
            self.assertEqual((output / 'home/.zshrc').read_text(), '@@HOME@@/test')
            self.assertFalse((output / 'home/.config/eww/old.bak').exists())


if __name__ == '__main__':
    unittest.main()
