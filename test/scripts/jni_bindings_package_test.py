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


if __name__ == '__main__':
    unittest.main()
