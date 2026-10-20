"""Strict CI restoration must use the hosted source recorded in the lockfile."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class DependencySourceTest(unittest.TestCase):
    def test_android_release_source_matches_locked_hosted_packages(self):
        workflow = (ROOT / '.github/workflows/android-release.yml').read_text()
        source = re.search(r'^      PUB_HOSTED_URL: (\S+)\s*$', workflow, re.M)
        self.assertIsNotNone(source, 'Release job must explicitly select its hosted source')
        locked_sources = set(re.findall(
            r'^      url: "(https://[^"\n]+)"\n    source: hosted$',
            (ROOT / 'pubspec.lock').read_text(), re.M,
        ))
        self.assertEqual(locked_sources, {source.group(1)})


if __name__ == '__main__':
    unittest.main()
