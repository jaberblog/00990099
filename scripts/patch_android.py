"""Patch the generated android/ project for flutter_vless."""
import glob
import re

# 1) minSdk -> 24
for path in glob.glob("android/app/build.gradle*"):
    s = open(path, encoding="utf-8").read()
    s = re.sub(r"minSdk(Version)?\s*=?\s*(flutter\.minSdkVersion|\d+)",
               lambda m: "minSdk = 24" if path.endswith(".kts") else "minSdkVersion 24", s)
    open(path, "w", encoding="utf-8").write(s)
    print("patched", path)

# 2) Manifest: extractNativeLibs + app label
mf = "android/app/src/main/AndroidManifest.xml"
s = open(mf, encoding="utf-8").read()
if "extractNativeLibs" not in s:
    s = s.replace("<application", '<application android:extractNativeLibs="true"', 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="VLESS VPN"', s, count=1)
open(mf, "w", encoding="utf-8").write(s)
print("patched", mf)
