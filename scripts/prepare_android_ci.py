#!/usr/bin/env python3
"""Apply upstream material_ui Android patches to the resolved CI package only."""
import json
from pathlib import Path
import subprocess
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parents[1]
PATCHES = (
    'modal_barrier_material.patch', 'navigation_drawer.patch', 'popup_menu.patch',
    'fab.patch', 'text_field.patch', 'scaffold.patch', 'refresh_indicator.patch',
    'tabs.patch', 'bottom_sheet_android.patch',
)


def main():
    config = ROOT / '.dart_tool/package_config.json'
    packages = json.loads(config.read_text())['packages']
    package = next(item for item in packages if item['name'] == 'material_ui')
    uri = urlparse(package['rootUri'])
    if uri.scheme not in ('', 'file'):
        raise ValueError('material_ui must resolve to a local directory')
    directory = (config.parent / unquote(uri.path)).resolve()
    for name in PATCHES:
        patch = ROOT / 'lib/scripts/material' / name
        # No destructive cache clearing, and no guessing which cached version to patch.
        subprocess.run(['git', 'apply', '--check', str(patch)], cwd=directory, check=True)
        subprocess.run(['git', 'apply', str(patch)], cwd=directory, check=True)
    print('Applied upstream Android material_ui patches')


if __name__ == '__main__':
    main()
