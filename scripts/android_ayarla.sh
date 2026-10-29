#!/usr/bin/env bash
# flutter create ile oluşan Android dosyalarını oyuna göre ayarlar:
#  - uygulama adı "Kibrit Ülkesi"
#  - internet izni (yazı tipleri için)
#  - sadece dikey ekran
set -euo pipefail
M=android/app/src/main/AndroidManifest.xml

sed -i 's/android:label="[^"]*"/android:label="Kibrit Ülkesi"/' "$M"

if ! grep -q 'android.permission.INTERNET' "$M"; then
  sed -i '0,/<application/s//<uses-permission android:name="android.permission.INTERNET"\/>\n    <application/' "$M"
fi

if ! grep -q 'screenOrientation' "$M"; then
  sed -i 's/android:name=".MainActivity"/android:name=".MainActivity"\n            android:screenOrientation="portrait"/' "$M"
fi

echo "--- AndroidManifest.xml ---"
cat "$M"

# Sabit imza: release derlemesi depodaki anahtarla imzalansın.
python3 - <<'PY'
import os, re
for name in ("android/app/build.gradle.kts", "android/app/build.gradle"):
    if not os.path.exists(name):
        continue
    s = open(name).read()
    kts = name.endswith(".kts")
    if "sabit" not in s:
        block = ('    signingConfigs {\n'
                 '        create("sabit") {\n'
                 '            storeFile = file("../../android_imza/debug.keystore")\n'
                 '            storePassword = "android"\n'
                 '            keyAlias = "androiddebugkey"\n'
                 '            keyPassword = "android"\n'
                 '        }\n'
                 '    }\n\n') if kts else (
                 '    signingConfigs {\n'
                 '        sabit {\n'
                 '            storeFile file("../../android_imza/debug.keystore")\n'
                 '            storePassword "android"\n'
                 '            keyAlias "androiddebugkey"\n'
                 '            keyPassword "android"\n'
                 '        }\n'
                 '    }\n\n')
        s = s.replace("    buildTypes {", block + "    buildTypes {", 1)
        s = re.sub(r'signingConfig\s*=?\s*signingConfigs\.(getByName\("debug"\)|debug)',
                   'signingConfig = signingConfigs.getByName("sabit")' if kts
                   else 'signingConfig signingConfigs.sabit', s)
        open(name, "w").write(s)
    print("--- " + name)
    print(s)
PY
