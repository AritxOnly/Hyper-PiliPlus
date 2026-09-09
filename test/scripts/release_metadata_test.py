import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('release_metadata', ROOT / 'scripts/release_metadata.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ReleaseMetadataTest(unittest.TestCase):
    def metadata(self, upstream='2.1.3', revision=0):
        return module.version_metadata(f'version: {upstream}+1\n',
                                       {'upstreamVersion': upstream, 'revision': revision})

    def test_initial(self):
        self.assertEqual(self.metadata(), ('2.1.3.0', 20100300))
        self.assertGreater(self.metadata()[1], 5348)

    def test_monotonic(self):
        self.assertLess(self.metadata(revision=99)[1], self.metadata('2.1.4')[1])
        self.assertLess(self.metadata('2.1.999', 99)[1], self.metadata('2.2.0')[1])
        self.assertLess(self.metadata('2.99.999', 99)[1], self.metadata('3.0.0')[1])

    def test_upstream_upgrade_requires_explicit_reset(self):
        with self.assertRaises(ValueError):
            module.version_metadata('version: 2.1.4+1', {'upstreamVersion': '2.1.3', 'revision': 5})

    def test_invalid_revision(self):
        for revision in [-1, 100, '0', True, 0.1]:
            with self.subTest(revision=revision), self.assertRaises(ValueError):
                self.metadata(revision=revision)

    def test_android_code_limit(self):
        self.assertLess(self.metadata('199.99.999', 99)[1], 2100000000)
        for upstream in ['200.0.0', '2.100.0', '2.1.1000', '2.1.3.0']:
            with self.subTest(upstream=upstream), self.assertRaises(ValueError):
                self.metadata(upstream)

    def test_next_revision_uses_the_first_version_after_existing_releases(self):
        pubspec = 'version: 2.1.3+1\n'
        config = {'upstreamVersion': '2.1.3', 'revision': 2}
        self.assertEqual(
            module.next_available_revision(
                pubspec,
                config,
                ['v2.1.2.99', 'v2.1.3.0', 'v2.1.3.2', 'v2.1.3.02', 'v2.1.3.bad'],
            ),
            3,
        )

    def test_next_revision_keeps_a_configured_unreleased_revision(self):
        self.assertEqual(
            module.next_available_revision(
                'version: 2.1.3+1\n',
                {'upstreamVersion': '2.1.3', 'revision': 4},
                ['v2.1.3.1'],
            ),
            4,
        )

    def test_next_revision_rejects_exhausted_upstream_version(self):
        with self.assertRaises(ValueError):
            module.next_available_revision(
                'version: 2.1.3+1\n',
                {'upstreamVersion': '2.1.3', 'revision': 0},
                ['v2.1.3.99'],
            )


if __name__ == '__main__':
    unittest.main()
