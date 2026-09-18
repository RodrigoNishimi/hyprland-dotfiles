import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]


@unittest.skipIf(os.geteuid() == 0, 'installer intentionally rejects root')
class ExtraPackages(unittest.TestCase):
    def run_installer(self, *args):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            repo, home, bin_dir = base / 'repo', base / 'home', base / 'bin'
            (repo / 'snapshot/home').mkdir(parents=True)
            (home / '.tmux/plugins/tpm').mkdir(parents=True)
            bin_dir.mkdir()
            for name in ['install.sh', 'manage.py']:
                shutil.copy2(REPO / name, repo / name)
            (repo / 'snapshot/manifest.json').write_text(json.dumps({'roots': []}))
            (repo / 'packages.txt').write_text('core-package\nshared-package\n')
            (repo / 'packages-extra.txt').write_text(
                '# Optional packages\nextra-package # AUR\nshared-package\n\n')
            marker = base / 'packages-called'
            # Replace only external package/service/build operations.
            for name in ['pacman', 'sudo', 'lua', 'fc-cache']:
                executable = bin_dir / name
                executable.write_text('#!/bin/sh\nexit 0\n')
                executable.chmod(0o755)
            helper = bin_dir / 'paru'
            helper.write_text('#!/bin/sh\nprintf "%s\\n" "$@" > "$TEST_PACKAGES"\n')
            helper.chmod(0o755)
            result = subprocess.run(
                ['bash', str(repo / 'install.sh'), *args], capture_output=True, text=True,
                env=dict(os.environ, HOME=str(home), TEST_PACKAGES=str(marker),
                         PATH=str(bin_dir) + os.pathsep + os.environ['PATH']))
            packages = marker.read_text().splitlines() if marker.exists() else None
            return result, packages

    def test_extra_installs_both_lists_without_comments_or_duplicates(self):
        result, packages = self.run_installer('--extra')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(packages, ['-S', '--needed', 'core-package',
                                    'shared-package', 'extra-package'])

    def test_default_installs_only_required_packages(self):
        result, packages = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(packages, ['-S', '--needed', 'core-package', 'shared-package'])

    def test_dry_run_and_skip_packages_never_install_extras(self):
        for flag in ['--dry-run', '--skip-packages']:
            with self.subTest(flag=flag):
                result, packages = self.run_installer('--extra', flag)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIsNone(packages)
                if flag == '--dry-run':
                    self.assertIn('packages-extra.txt', result.stdout)
