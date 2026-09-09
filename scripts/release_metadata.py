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


def next_available_revision(pubspec, config, tags):
    # Validate the configured base revision before inspecting remote release tags.
    version_metadata(pubspec, config)
    prefix = f"v{config['upstreamVersion']}."
    existing_revisions = []
    for tag in tags:
        if not tag.startswith(prefix):
            continue
        suffix = tag.removeprefix(prefix)
        if suffix.isdecimal():
            existing_revisions.append(int(suffix))
    revision = max(config['revision'], max(existing_revisions, default=-1) + 1)
    if revision > 99:
        raise ValueError('no flavor revision remains for this upstream version')
    return revision


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT / 'pili_release.json')
    parser.add_argument('--github-output', type=Path)
    parser.add_argument('--next-available-tag', action='store_true')
    args = parser.parse_args()
    pubspec = (ROOT / 'pubspec.yaml').read_text()
    config = json.loads((ROOT / 'tool/release.json').read_text())
    if args.next_available_tag:
        tags = subprocess.check_output(['git', 'tag', '--list'], cwd=ROOT, text=True).splitlines()
        config = {**config, 'revision': next_available_revision(pubspec, config, tags)}
    name, code = version_metadata(pubspec, config)
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    data = {'pili.name': name, 'pili.code': code, 'pili.hash': commit, 'pili.time': int(time.time())}
    args.output.write_text(json.dumps(data) + '\n')
    if args.github_output:
        with args.github_output.open('a') as output:
            output.write(f'version={name}\ncode={code}\ntag=v{name}\n')
    print(f'Android version: {name} ({code})')


if __name__ == '__main__':
    main()
