"""Prepare only generated Android runners for a separate offline demo package."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET

project = Path(__file__).resolve().parent.parent
app = project / 'android/app'
gradle = app / 'build.gradle.kts'
source = gradle.read_text()
source, count = re.subn(r'applicationId\s*=\s*"[^"]+"', 'applicationId = "com.hangyeolseed.offline_demo_v2"', source)
if count != 1:
    raise RuntimeError('Expected one generated application ID')
gradle.write_text(source)
android = 'http://schemas.android.com/apk/res/android'
tools = 'http://schemas.android.com/tools'
ET.register_namespace('android', android)
ET.register_namespace('tools', tools)
for manifest in (app / 'src').glob('*/AndroidManifest.xml'):
    tree = ET.parse(manifest)
    root = tree.getroot()
    for permission in list(root.findall('uses-permission')):
        root.remove(permission)
    # Remove transitive plugin permissions too, so no network request can leave the APK.
    if manifest.parent.name == 'main':
        for name in ['INTERNET', 'ACCESS_NETWORK_STATE']:
            ET.SubElement(root, 'uses-permission', {f'{{{android}}}name': f'android.permission.{name}', f'{{{tools}}}node': 'remove'})
    if manifest.parent.name == 'main':
        for name in ['ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION']:
            ET.SubElement(root, 'uses-permission', {f'{{{android}}}name': f'android.permission.{name}'})
    application = root.find('application')
    if application is not None:
        application.attrib.pop(f'{{{android}}}usesCleartextTraffic', None)
        if manifest.parent.name == 'main':
            application.set(f'{{{android}}}label', '한결씨드 체험 2')
            application.set(f'{{{android}}}allowBackup', 'false')
    tree.write(manifest, encoding='utf-8', xml_declaration=True)
wrapper = project / 'android/gradle/wrapper/gradle-wrapper.properties'
# Same Gradle version; the binary-only distribution avoids downloading docs and source.
if wrapper.exists():
    source = wrapper.read_text().replace('services.gradle.org/distributions/', 'downloads.gradle.org/distributions/').replace('-all.zip', '-bin.zip')
    wrapper.write_text(source)
print('Separate offline package prepared; network and location permissions removed.')
