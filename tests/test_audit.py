from pathlib import Path
import tempfile
import unittest

import audit


class Audit(unittest.TestCase):
    def test_inventory_ignores_the_same_transient_files_as_capture(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'config').write_text('managed')
            (root / '__pycache__').mkdir()
            (root / '__pycache__/script.pyc').write_bytes(b'cache')
            (root / 'config.bak').write_text('old')
            self.assertEqual(set(audit.inventory(root)), {'config'})
