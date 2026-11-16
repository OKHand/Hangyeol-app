import os
from pathlib import Path

root = Path(__file__).resolve().parent.parent
for name in ('HANGYEOL_ANDROID_KEYSTORE', 'HANGYEOL_ANDROID_PASSWORD_FILE'):
    if not os.environ.get(name) or not Path(os.environ[name]).is_file():
        raise RuntimeError('Protected Android signing identity was not restored')
file = root / 'android/app/build.gradle.kts'
text = file.read_text()
old = 'signingConfig = signingConfigs.getByName("debug")'
if text.count(old) != 1:
    raise RuntimeError('Unexpected release signing configuration')
text = text.replace(old, 'signingConfig = signingConfigs.getByName("hangyeolRelease")')
config = '''
    signingConfigs {
        create("hangyeolRelease") {
            storeFile = file(System.getenv("HANGYEOL_ANDROID_KEYSTORE"))
            storePassword = file(System.getenv("HANGYEOL_ANDROID_PASSWORD_FILE")).readText().trim()
            keyAlias = "hangyeol-online"
            keyPassword = storePassword
            storeType = "PKCS12"
        }
    }
'''
if text.count('android {') != 1:
    raise RuntimeError('Unexpected Android build layout')
file.write_text(text.replace('android {', 'android {' + config, 1))
properties = root / 'android/gradle.properties'
properties.write_text(properties.read_text() + '\norg.gradle.configuration-cache=false\n')
print('Release signing requires the restored fixed identity; debug signing removed.')
