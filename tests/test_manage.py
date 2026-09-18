import importlib.util
import json
from pathlib import Path
import tempfile
import os
import subprocess
import shutil
from types import SimpleNamespace
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('manage', Path(__file__).resolve().parents[1] / 'manage.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class Installation(unittest.TestCase):
    @unittest.skipIf(os.geteuid() == 0, 'install.sh intentionally rejects root')
    def test_wrapper_validates_snapshot_before_installing_packages(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            repo, home, fake_bin = base / 'repo', base / 'home', base / 'bin'
            (repo / 'snapshot/home').mkdir(parents=True)
            home.mkdir()
            fake_bin.mkdir()
            for name in ['install.sh', 'manage.py', 'packages.txt']:
                shutil.copy2(m.REPO / name, repo / name)
            (repo / 'snapshot/manifest.json').write_text(json.dumps({'roots': ['missing']}))
            marker = base / 'side-effects'
            for name in ['paru', 'sudo']:
                executable = fake_bin / name
                executable.write_text('#!/bin/sh\necho called >> "$TEST_MARKER"\n')
                executable.chmod(0o755)
            (fake_bin / 'pacman').symlink_to('/bin/true')
            result = subprocess.run(['bash', str(repo / 'install.sh')], capture_output=True,
                                    text=True, env=dict(os.environ, HOME=str(home),
                                    PATH=str(fake_bin) + os.pathsep + os.environ['PATH'],
                                    TEST_MARKER=str(marker)))
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Missing source: missing', result.stderr)
            self.assertFalse(marker.exists(), 'packages/services changed before validation')

    def test_snapshot_installable_using_only_git_visible_files(self):
        # Local ignored files must not hide a broken fresh clone.
        files = subprocess.check_output(
            ['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard', 'snapshot'],
            cwd=m.REPO).decode().split('\0')
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            for rel in filter(None, files):
                target = base / rel
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(m.REPO / rel, target)
            m.install(SimpleNamespace(home=base / 'home', source=base / 'snapshot',
                                      dry_run=True, monitors='auto'))

    def test_conflicting_destination_fails_before_any_file_is_changed(self):
        for dry_run in [True, False]:
            with self.subTest(dry_run=dry_run), tempfile.TemporaryDirectory() as tmp:
                base = Path(tmp)
                source, home = base / 'source', base / 'home'
                (source / 'home/.config/eww').mkdir(parents=True)
                (source / 'home/.zshrc').write_text('new')
                (source / 'home/.config/eww/eww.yuck').write_text('new')
                (source / 'manifest.json').write_text(json.dumps(
                    {'roots': ['.zshrc', '.config/eww']}))
                (home / '.config/eww/eww.yuck').mkdir(parents=True)
                (home / '.zshrc').write_text('old')
                with self.assertRaises(ValueError):
                    m.install(SimpleNamespace(home=home, source=source,
                                              dry_run=dry_run, monitors='original'))
                self.assertEqual((home / '.zshrc').read_text(), 'old')

    def test_rejects_equivalent_manifest_roots(self):
        with self.assertRaises(ValueError):
            m.safe_roots(['.config/eww', './.config//eww/'])

    def test_rewrite_preserves_line_endings_and_unmodified_bytes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'config').write_bytes(b'path=@@HOME@@/test\r\n')
            (root / 'unchanged').write_bytes(b'keep\r\nexactly\r\n')
            m.rewrite(root, [('@@HOME@@', '/home/test')])
            self.assertEqual((root / 'config').read_bytes(), b'path=/home/test/test\r\n')
            self.assertEqual((root / 'unchanged').read_bytes(), b'keep\r\nexactly\r\n')

    def test_capture_accepts_empty_foreign_package_inventory(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            home = base / 'home'
            home.mkdir()
            (home / '.zshrc').write_text('config')
            fake_bin = base / 'bin'
            fake_bin.mkdir()
            pacman = fake_bin / 'pacman'
            pacman.write_text('#!/bin/sh\ncase "$1" in\n'
                              ' -Qqm) exit 1 ;;\n'
                              ' *) echo "example-package" ;;\nesac\n')
            pacman.chmod(0o755)
            with patch.dict(os.environ, PATH=str(fake_bin)):
                output = base / 'snapshot'
                m.capture(SimpleNamespace(home=home, output=output, assets=None))
            self.assertEqual((output / 'foreign.txt').read_text(), '')
            self.assertTrue((output / 'manifest.json').is_file())

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
        for roots in [['../outside'], ['/etc'], ['.'], ['.config', '.config/hypr'],
                      '.config/hypr', [None], {'roots': []}]:
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
