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
