from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
BINDINGS = ROOT / 'lib/utils/android/bindings.g.dart'


class JniBindingsPackageTest(unittest.TestCase):
    def test_generated_android_helper_bindings_use_the_app_package(self):
        bindings = BINDINGS.read_text()

        self.assertIn(
            "r'com/aritxonly/hyperpiliplus/AndroidHelper$ToDart'",
            bindings,
        )
        self.assertIn(
            "r'Lcom/aritxonly/hyperpiliplus/AndroidHelper$ToDart;'",
            bindings,
        )
        self.assertNotIn('com/example/piliplus', bindings)

    def test_native_sources_do_not_import_the_original_app_package(self):
        source_root = ROOT / 'android/app/src/main'
        for pattern in ('*.java', '*.kt'):
            for source in source_root.rglob(pattern):
                with self.subTest(source=source.relative_to(ROOT)):
                    self.assertNotRegex(
                        source.read_text(),
                        r'(?m)^import\s+(?:static\s+)?com\.example\.piliplus\.',
                    )


if __name__ == '__main__':
    unittest.main()
