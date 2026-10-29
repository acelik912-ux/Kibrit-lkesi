"""APK'nın depodaki sabit anahtarla imzalandığını doğrular."""
import subprocess, sys
apk = sys.argv[1]
der = subprocess.run(
    ["keytool", "-exportcert", "-alias", "androiddebugkey", "-keystore",
     "android_imza/debug.keystore", "-storepass", "android"],
    capture_output=True, check=True).stdout
ok = der in open(apk, "rb").read()
print(apk, "sabit imza:", "EVET" if ok else "HAYIR")
sys.exit(0 if ok else 1)
