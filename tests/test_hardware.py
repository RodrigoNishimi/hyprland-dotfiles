import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('desktop_hardware', REPO / 'snapshot/home/.config/hypr/scripts/desktop-tools.py')
desktop = importlib.util.module_from_spec(spec)
spec.loader.exec_module(desktop)


@unittest.skipIf(os.geteuid() == 0, 'installer rejects root')
class HardwareInstall(unittest.TestCase):
    def run_install(self, *args, kernels='linux\nlinux-lts\n', fail=False):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        base = Path(temp.name)
        repo, home, binaries = base / 'repo', base / 'home', base / 'bin'
        repo.mkdir()
        home.mkdir()
        binaries.mkdir()
        for name in ['install.sh', 'manage.py', 'packages.txt']:
            shutil.copy2(REPO / name, repo / name)
        shutil.copytree(REPO / 'snapshot', repo / 'snapshot')
        log = base / 'commands'
        for name, body in {
            'pacman': 'printf "%s" "$TEST_KERNELS"',
            'sudo': 'printf "%s\\n" "$*" >> "$TEST_LOG"; exit "$TEST_FAIL"',
            'lua': 'exit 0', 'fc-cache': 'exit 0',
        }.items():
            exe = binaries / name
            exe.write_text('#!/bin/sh\n' + body + '\n')
            exe.chmod(0o755)
        result = subprocess.run(['bash', str(repo / 'install.sh'), *args], text=True,
            capture_output=True, env=dict(os.environ, HOME=str(home),
            PATH=str(binaries) + ':' + os.environ['PATH'], TEST_KERNELS=kernels,
            TEST_LOG=str(log), TEST_FAIL=str(int(fail))))
        return result, home, log.read_text() if log.exists() else ''

    def test_drivers_only_installs_headers_for_all_installed_kernels_without_dotfiles(self):
        result, home, log = self.run_install('--hardware', 'ryzen5600-rtx5070', '--drivers-only')
        self.assertEqual(result.returncode, 0, result.stderr)
        for package in ['amd-ucode', 'nvidia-open-dkms', 'nvidia-utils', 'linux-headers', 'linux-lts-headers']:
            self.assertIn(package, log.split())
        self.assertIn('pacman -Syu --needed', log)
        self.assertEqual(list(home.iterdir()), [])

    def test_dry_run_shows_hardware_plan_without_writes(self):
        result, home, log = self.run_install('--hardware', 'ryzen5600-rtx5070', '--dry-run')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('nvidia-open-dkms', result.stdout)
        self.assertIn('1920x1080@300', result.stdout)
        self.assertEqual(log, '')
        self.assertEqual(list(home.iterdir()), [])

    def test_skip_packages_applies_monitor_and_nvidia_environment(self):
        result, home, log = self.run_install('--hardware', 'ryzen5600-rtx5070', '--skip-packages')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(log, '')
        self.assertIn('1920x1080@300', (home / '.config/hypr/conf/monitors.lua').read_text())
        config = json.loads((home / '.config/hypr/monitor-profiles.json').read_text())
        self.assertEqual(config['default_mode'], '1920x1080@300')
        self.assertEqual(config['layouts'], {})
        self.assertIn('export __GLX_VENDOR_LIBRARY_NAME="nvidia"', (home / '.config/uwsm/env').read_text())
        env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / '.config'))
        checked = subprocess.run(['Hyprland', '--verify-config', '-c', str(home / '.config/hypr/hyprland.lua')],
                                 env=env, capture_output=True, text=True)
        self.assertEqual(checked.returncode, 0, checked.stdout + checked.stderr)

    def test_rejects_conflicting_options_before_changes(self):
        for args in [('--drivers-only',), ('--hardware', 'unknown'),
                     ('--hardware', 'ryzen5600-rtx5070', '--drivers-only', '--skip-packages'),
                     ('--hardware', 'ryzen5600-rtx5070', '--monitors', 'original')]:
            with self.subTest(args=args):
                result, home, log = self.run_install(*args)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(log, '')
                self.assertEqual(list(home.iterdir()), [])

    def test_no_supported_kernel_fails_before_install(self):
        result, home, log = self.run_install('--hardware', 'ryzen5600-rtx5070', '--drivers-only', kernels='custom-kernel\n')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(log, '')
        self.assertEqual(list(home.iterdir()), [])

    def test_driver_failure_does_not_apply_desktop(self):
        result, home, log = self.run_install('--hardware', 'ryzen5600-rtx5070', fail=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('pacman -Syu', log)
        self.assertNotIn('mkinitcpio', log)
        self.assertEqual(list(home.iterdir()), [])

    def test_drivers_only_propagates_package_failure(self):
        result, home, log = self.run_install('--hardware', 'ryzen5600-rtx5070', '--drivers-only', fail=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('mkinitcpio', log)
        self.assertEqual(list(home.iterdir()), [])


class HardwareMonitor(unittest.TestCase):
    def test_login_and_reload_use_hardware_mode_but_saved_layout_takes_precedence(self):
        with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ,
                XDG_CONFIG_HOME=tmp + '/config', XDG_RUNTIME_DIR=tmp + '/run'), \
                patch.object(desktop, 'query', return_value=[{'name': 'DP-2', 'description': 'Monitor'}]), \
                patch.object(desktop, 'evaluate') as evaluate:
            path = Path(tmp) / 'config/hypr/monitor-profiles.json'
            path.parent.mkdir(parents=True)
            config = {'default_mode': '1920x1080@300'}
            path.write_text(json.dumps(config))
            desktop.monitors('apply', force=True)
            self.assertIn('1920x1080@300', evaluate.call_args.args[0])
            key = desktop.topology([{'name': 'DP-2', 'description': 'Monitor'}])
            config['layouts'] = {key: [{'output': 'DP-2', 'mode': '1920x1080@144'}]}
            path.write_text(json.dumps(config))
            desktop.monitors('apply', force=True)
            self.assertIn('1920x1080@144', evaluate.call_args.args[0])
