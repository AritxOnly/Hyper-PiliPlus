from pathlib import Path
import re
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
ANDROID = ROOT / 'android/app/src/main'
ATTR = '{http://schemas.android.com/apk/res/android}'


class LauncherIconTest(unittest.TestCase):
    def test_aliases_and_previews_share_fixed_colors_and_original_geometry(self):
        model = (ROOT / 'lib/models/common/app_icon_style.dart').read_text()
        palettes = re.findall(
            r'^  (\w+)\([^\n]*?, 0x([0-9A-F]{8}), 0x([0-9A-F]{8})\)',
            model, re.M,
        )
        self.assertEqual(len(palettes), 6)
        manifest = ET.parse(ANDROID / 'AndroidManifest.xml').getroot()
        app = manifest.find('application')
        main = app.find(f"activity[@{ATTR}name='.MainActivity']")
        self.assertNotEqual(main.get(ATTR + 'enabled'), 'false')
        self.assertFalse(main.findall(
            f"intent-filter/category[@{ATTR}name='android.intent.category.LAUNCHER']"
        ))
        aliases = app.findall('activity-alias')
        self.assertEqual(len(aliases), len(palettes) + 1)
        enabled = [a for a in aliases if a.get(ATTR + 'enabled') == 'true']
        self.assertEqual([a.get(ATTR + 'name') for a in enabled], ['.LauncherSystem'])
        original = ET.parse(ANDROID / 'res/drawable/ic_launcher_foreground.xml')
        outline = original.find('path').get(ATTR + 'pathData')
        preview = (ROOT / 'lib/pages/setting/widgets/app_icon_dialog.dart').read_text()
        self.assertIn(outline, preview)
        colors = {
            e.get('name'): e.text.upper()
            for e in ET.parse(ANDROID / 'res/values/launcher_icon_colors.xml').getroot()
        }
        for alias in aliases:
            self.assertEqual(alias.get(ATTR + 'targetActivity'), '.MainActivity')
            self.assertEqual(alias.get(ATTR + 'exported'), 'true')
            self.assertIsNotNone(alias.find(
                f"intent-filter/category[@{ATTR}name='android.intent.category.LAUNCHER']"
            ))
            self.assertIsNotNone(alias.find(
                f"meta-data[@{ATTR}name='android.app.shortcuts']"
            ))
        for name, fg, bg in palettes:
            with self.subTest(style=name):
                alias = next(a for a in aliases if a.get(ATTR + 'name') == '.Launcher' + name.title())
                self.assertEqual(alias.get(ATTR + 'icon'), f'@mipmap/ic_launcher_{name}')
                icon = ET.parse(ANDROID / f'res/mipmap-anydpi-v26/ic_launcher_{name}.xml')
                self.assertIsNone(icon.find('monochrome'))
                self.assertEqual(colors[f'launcher_{name}_foreground'], '#' + fg)
                self.assertEqual(colors[f'launcher_{name}_background'], '#' + bg)
                vector = ET.parse(ANDROID / f'res/drawable/ic_launcher_{name}_foreground.xml')
                self.assertEqual(vector.find('path').get(ATTR + 'pathData'), outline)
                self.assertEqual(vector.find('path').get(ATTR + 'fillColor'),
                                 f'@color/launcher_{name}_foreground')
                self.assertEqual(icon.find('background').get(ATTR + 'drawable'),
                                 f'@color/launcher_{name}_background')


if __name__ == '__main__':
    unittest.main()
