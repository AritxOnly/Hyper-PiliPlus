#!/usr/bin/env python3
"""Generate Android flavor metadata without putting a four-part version in pubspec."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]


def version_metadata(pubspec, config):
    match = re.search(r'^version:\s*(\d+\.\d+\.\d+)(?:\+\d+)?\s*$', pubspec, re.M)
    if not match or match[1] != config['upstreamVersion']:
        raise ValueError('upstreamVersion must match pubspec.yaml; reset revision on upstream upgrades')
    major, minor, patch = map(int, match[1].split('.'))
    revision = config['revision']
    if type(revision) is not int or not (0 <= revision <= 99):
        raise ValueError('revision must be an integer from 0 to 99')
    if not (0 <= major <= 199 and 0 <= minor <= 99 and 0 <= patch <= 999):
        raise ValueError('upstream version exceeds Android versionCode encoding limits')
    name = f'{major}.{minor}.{patch}.{revision}'
    code = major * 10_000_000 + minor * 100_000 + patch * 100 + revision
    if code <= 0:
        raise ValueError('Android versionCode must be positive')
    return name, code


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT / 'pili_release.json')
    parser.add_argument('--github-output', type=Path)
    args = parser.parse_args()
    name, code = version_metadata((ROOT / 'pubspec.yaml').read_text(),
                                  json.loads((ROOT / 'tool/release.json').read_text()))
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    data = {'pili.name': name, 'pili.code': code, 'pili.hash': commit, 'pili.time': int(time.time())}
    args.output.write_text(json.dumps(data) + '\n')
    if args.github_output:
        with args.github_output.open('a') as output:
            output.write(f'version={name}\ncode={code}\ntag=v{name}\n')
    print(f'Android version: {name} ({code})')


if __name__ == '__main__':
    main()
