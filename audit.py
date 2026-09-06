#!/usr/bin/env python3
"""Compare a fresh normalized capture with the repository snapshot."""
import argparse
import contextlib
import hashlib
import io
from pathlib import Path
import tempfile
from types import SimpleNamespace
import manage


def inventory(root):
    return {str(p.relative_to(root)): (hashlib.sha256(p.read_bytes()).hexdigest(), p.stat().st_mode & 0o777)
            for p in root.rglob('*') if p.is_file()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--home', type=Path, default=Path.home())
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='hyprland-audit-') as temporary:
        output = Path(temporary) / 'snapshot'
        with contextlib.redirect_stdout(io.StringIO()):
            manage.capture(SimpleNamespace(home=args.home.resolve(), output=output, assets=None))
        live = inventory(output / 'home')
        saved = inventory(manage.REPO / 'snapshot/home')
        differences = []
        for rel in sorted(live.keys() | saved.keys()):
            if rel not in saved:
                differences.append(f'MISSING FROM REPO: {rel}')
            elif rel not in live:
                differences.append(f'ONLY IN REPO: {rel}')
            elif live[rel] != saved[rel]:
                differences.append(f'CONTENT OR MODE DIFFERS: {rel}')
        if differences:
            print('\n'.join(differences))
            return 1
        print(f'OK: {len(live)} managed files match the current desktop (normalized paths and helper migration).')
        return 0


if __name__ == '__main__':
    raise SystemExit(main())
