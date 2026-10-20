"""Execute production geometry on the JVM without Android or an emulator."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class BackdropGeometryTest(unittest.TestCase):
    def test_cropped_pixels_keep_their_window_coordinates(self):
        source = ROOT / 'android/app/src/main/java/com/aritxonly/hyperpiliplus/FlutterBackdropGeometry.java'
        fixture = ROOT / 'test/native/FlutterBackdropGeometryTest.java'
        cases = {
            'symmetric bleed': (100, 400, 228, 144, 0),
            'bottom clipped at screen edge': (1776, 624, 2160, 192, -168),
            'top clipped': (0, 500, 24, 200, 126),
            'left clipped': (0, 600, 48, 200, 152),
            'right clipped': (700, 380, 900, 120, -70),
            'surface offset in window': (1826, 624, 2210, 192, -168),
            'bar moves before next capture': (1776, 624, 2100, 192, -108),
            'odd pixel extent': (100, 401, 228, 144, 1),
        }
        with tempfile.TemporaryDirectory(prefix='backdrop-geometry-') as directory:
            subprocess.run(['javac', '-d', directory, str(source), str(fixture)], check=True)
            for name, values in cases.items():
                with self.subTest(name=name):
                    subprocess.run([
                        'java', '-cp', directory,
                        'com.aritxonly.hyperpiliplus.FlutterBackdropGeometryTest',
                        *map(str, values),
                    ], check=True)


if __name__ == '__main__':
    unittest.main()
