import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'snapshot/home/.config/hypr/scripts/desktop-tools.py'
spec = importlib.util.spec_from_file_location('desktop_tools', SCRIPT)
desktop = importlib.util.module_from_spec(spec)
spec.loader.exec_module(desktop)


def monitor(name, **values):
    return dict(name=name, description=name, width=1920, height=1080, scale=1,
                x=0, y=0, refreshRate=60, transform=0, disabled=False,
                mirrorOf='none', **values)


class MonitorProfiles(unittest.TestCase):
    def test_cancelled_profile_picker_has_no_monitor_side_effects(self):
        with patch.object(desktop.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, '', '')), \
                patch.object(desktop, 'query') as query:
            self.assertIsNone(desktop.pick_monitor_profile())
            query.assert_not_called()

    def test_laptop_profile_never_disables_every_screen_on_desktop(self):
        plan = desktop.monitor_plan([monitor('DP-1'), monitor('HDMI-A-1')], 'notebook')
        self.assertTrue(any(not item.get('disabled') for item in plan))

    def test_presentation_mirrors_external_to_internal_regardless_of_query_order(self):
        plan = desktop.monitor_plan([monitor('HDMI-A-1'), monitor('eDP-1')], 'presentation')
        self.assertEqual(plan[0]['output'], 'eDP-1')
        self.assertEqual(plan[1]['mirror'], 'eDP-1')

    def test_desk_reenables_outputs_and_clears_previous_mirroring(self):
        plan = desktop.monitor_plan([monitor('eDP-1'), monitor('DP-1')], 'desk')
        self.assertEqual(len(plan), 2)
        self.assertTrue(all(p['disabled'] is False and p['mirror'] == '' for p in plan))

    def test_saved_layout_preserves_scale_position_rotation_and_mode(self):
        monitors = [monitor('DP-1')]
        monitors[0].update(width=3840, height=2160, scale=2, x=-1920, y=0, transform=1)
        layout = desktop.capture_layout(monitors)
        self.assertEqual(layout[0]['position'], '-1920x0')
        self.assertEqual(layout[0]['scale'], 2)
        self.assertEqual(layout[0]['transform'], 1)
        self.assertEqual(layout[0]['mode'], '3840x2160@60')

    def test_topology_ignores_order_but_distinguishes_different_screens(self):
        a, b = monitor('eDP-1'), monitor('DP-1')
        self.assertEqual(desktop.topology([a, b]), desktop.topology([b, a]))
        other = dict(b, description='Other screen')
        self.assertNotEqual(desktop.topology([a, b]), desktop.topology([a, other]))

    def test_hotplug_feedback_does_not_reapply_identical_plan_but_reload_does(self):
        with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ,
                XDG_CONFIG_HOME=tmp + '/config', XDG_RUNTIME_DIR=tmp + '/run'), \
                patch.object(desktop, 'query', return_value=[monitor('eDP-1')]), \
                patch.object(desktop, 'evaluate') as evaluate:
            desktop.monitors('apply')
            desktop.monitors('apply')
            self.assertEqual(evaluate.call_count, 1)
            desktop.monitors('apply', force=True)
            self.assertEqual(evaluate.call_count, 2)

    def test_profile_selection_persists_and_unplug_uses_safe_fallback(self):
        with patch.object(desktop, 'notify'), tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, HOME=tmp,
                XDG_CONFIG_HOME=tmp + '/.config', XDG_RUNTIME_DIR=tmp + '/run'):
            screens = [monitor('eDP-1'), monitor('DP-1')]
            with patch.object(desktop, 'query', return_value=screens), patch.object(desktop, 'evaluate') as evaluate:
                desktop.monitors('presentation')
                saved = json.loads((Path(tmp) / '.config/hypr/monitor-profiles.json').read_text())
                self.assertEqual(saved['selected'][desktop.topology(screens)], 'presentation')
                desktop.monitors('apply', force=True)
                self.assertIn('mirror', evaluate.call_args.args[0])
            with patch.object(desktop, 'query', return_value=[screens[0]]), patch.object(desktop, 'evaluate') as evaluate:
                desktop.monitors('apply', force=True)
                self.assertNotIn('["disabled"] = true', evaluate.call_args.args[0])


class DesktopActions(unittest.TestCase):
    def test_cancelled_ocr_does_not_change_clipboard(self):
        calls = []
        def run(argv, **kwargs):
            calls.append(argv[0])
            return subprocess.CompletedProcess(argv, 1, '', '')
        with patch.object(desktop.subprocess, 'run', side_effect=run):
            desktop.ocr()
        self.assertEqual(calls, ['slurp'])

    def test_ocr_copies_recognized_text_with_explicit_mime_type(self):
        copied = []
        def run(argv, **kwargs):
            if argv[0] == 'slurp':
                return subprocess.CompletedProcess(argv, 0, '10,20 300x100\n', '')
            if '--list-langs' in argv:
                return subprocess.CompletedProcess(argv, 0, 'eng\npor\nosd\n', '')
            if argv[0] == 'tesseract':
                self.assertIn('por+eng', argv)
                return subprocess.CompletedProcess(argv, 0, 'Olá mundo\n\f', '')
            if argv[0] == 'wl-copy':
                copied.append((argv, kwargs['input']))
            return subprocess.CompletedProcess(argv, 0, '', '')
        with patch.object(desktop.subprocess, 'run', side_effect=run), patch.object(desktop, 'notify'):
            desktop.ocr()
        self.assertEqual(copied, [(['wl-copy', '--type', 'text/plain;charset=utf-8'], 'Olá mundo')])

    def test_empty_ocr_preserves_clipboard(self):
        calls = []
        def run(argv, **kwargs):
            calls.append(argv[0])
            result = '0,0 100x100' if argv[0] == 'slurp' else ''
            if '--list-langs' in argv:
                result = 'eng\npor\n'
            return subprocess.CompletedProcess(argv, 0, result, '')
        with patch.object(desktop.subprocess, 'run', side_effect=run), patch.object(desktop, 'notify'):
            desktop.ocr()
        self.assertNotIn('wl-copy', calls)

    def test_existing_scratchpad_is_toggled_without_launching_another_app(self):
        with patch.object(desktop, 'query', return_value=[{'class': 'local.scratch.terminal'}]), \
                patch.object(desktop, 'evaluate') as evaluate, patch.object(desktop.subprocess, 'Popen') as launch:
            desktop.scratch('terminal')
            launch.assert_not_called()
            self.assertIn('quick-terminal', evaluate.call_args.args[0])

    def test_first_notes_launch_preserves_existing_notes_and_waits_for_window(self):
        with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, HOME=tmp, XDG_DATA_HOME=tmp + '/data'):
            notes = Path(tmp) / 'data/quick-notes/notes.md'
            notes.parent.mkdir(parents=True)
            notes.write_text('My existing note')
            with patch.object(desktop, 'query', side_effect=[[], [{'class': 'local.scratch.notes'}]]), \
                    patch.object(desktop, 'evaluate') as evaluate, patch.object(desktop.subprocess, 'Popen') as launch:
                desktop.scratch('notes')
                self.assertIn(str(notes), launch.call_args.args[0])
                self.assertIn('quick-notes', evaluate.call_args.args[0])
            self.assertEqual(notes.read_text(), 'My existing note')


if __name__ == '__main__':
    unittest.main()
