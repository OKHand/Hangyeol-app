from pathlib import Path
import re
import xml.etree.ElementTree as ET
root = Path(__file__).resolve().parent.parent
file = root / 'android/app/build.gradle.kts'
text, count = re.subn(r'applicationId\s*=\s*"[^"]+"', 'applicationId = "com.hangyeolseed.platform_online"', file.read_text())
if count != 1:
    raise RuntimeError('Expected one generated Android application ID')
file.write_text(text)
android = 'http://schemas.android.com/apk/res/android'
ET.register_namespace('android', android)
for file in (root / 'android/app/src').glob('*/AndroidManifest.xml'):
    tree = ET.parse(file)
    manifest = tree.getroot()
    for permission in list(manifest.findall('uses-permission')):
        if permission.get(f'{{{android}}}name') in ['android.permission.ACCESS_FINE_LOCATION','android.permission.ACCESS_COARSE_LOCATION']:
            manifest.remove(permission)
    app = manifest.find('application')
    if app is not None:
        app.set(f'{{{android}}}usesCleartextTraffic', 'false')
        if file.parent.name == 'main':
            app.set(f'{{{android}}}label', '한결씨드 온라인')
            app.set(f'{{{android}}}allowBackup', 'false')
    tree.write(file, encoding='utf-8', xml_declaration=True)
print('Separate HTTPS-only online Android package prepared.')

# Register an external browser channel; never embed Google's sign-in page.
file = root / 'android/app/build.gradle.kts'
file.write_text(file.read_text() + '\ndependencies { implementation("androidx.browser:browser:1.9.0") }\n')
activities = list((root / 'android/app/src/main').rglob('MainActivity.kt'))
if len(activities) != 1:
    raise RuntimeError('Expected one Android activity')
activities[0].write_text((root / 'tool/native/MainActivity.kt').read_text(), encoding='utf-8')
file = root / 'android/app/src/main/AndroidManifest.xml'
tree = ET.parse(file)
manifest = tree.getroot()
queries = manifest.find('queries')
if queries is None:
    queries = ET.SubElement(manifest, 'queries')
for package in ['com.android.chrome','com.chrome.beta','com.chrome.dev','com.chrome.canary']:
    ET.SubElement(queries, 'package', {f'{{{android}}}name':package})
tree.write(file, encoding='utf-8', xml_declaration=True)
