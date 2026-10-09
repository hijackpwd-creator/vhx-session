#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
app="build/package/var/jb/Applications/VHXSessionTest.app"
mkdir -p "$app" build/package/DEBIAN dist

python3 - "$app/Info.plist" <<'PY'
import plistlib,sys
info = {
    'CFBundleIdentifier': 'local.vhx.sessiontest',
    'CFBundleName': 'VHXSessionTest',
    'CFBundleDisplayName': 'VHX Session Test',
    'CFBundleExecutable': 'VHXSessionTest',
    'CFBundlePackageType': 'APPL',
    'CFBundleInfoDictionaryVersion': '6.0',
    'CFBundleVersion': '1',
    'CFBundleShortVersionString': '1.0',
    'MinimumOSVersion': '15.0',
    'LSRequiresIPhoneOS': True,
    'UIDeviceFamily': [1,2],
    'UISupportedInterfaceOrientations': ['UIInterfaceOrientationPortrait'],
    'UILaunchScreen': {},
    'NSAppTransportSecurity': {'NSAllowsArbitraryLoads': True},
    'NSLocalNetworkUsageDescription': 'Test NSURLSession requests to your local server.'
}
with open(sys.argv[1], 'wb') as f:
    plistlib.dump(info,f)
PY

xcrun --sdk iphoneos clang -arch arm64 -miphoneos-version-min=15.0 \
  -fobjc-arc -fblocks -O2 -Wall -Wextra -Werror \
  -framework UIKit -framework Foundation main.m -o "$app/VHXSessionTest"
ldid -Hsha256 -S "$app/VHXSessionTest"
chmod 755 "$app/VHXSessionTest"
xcrun lipo "$app/VHXSessionTest" -verify_arch arm64
ldid -h "$app/VHXSessionTest" > dist/signature-info.txt
xcrun otool -l "$app/VHXSessionTest" > dist/macho-load-commands.txt
cp packaging/control packaging/postinst packaging/postrm build/package/DEBIAN/
chmod 755 build/package/DEBIAN/postinst build/package/DEBIAN/postrm
chmod 644 build/package/DEBIAN/control
dpkg-deb --root-owner-group -Zgzip --build build/package dist/vhx-session-test_1.0.0_iphoneos-arm64.deb
cp README_zh.md dist/
(cd dist && shasum -a 256 vhx-session-test_1.0.0_iphoneos-arm64.deb > SHA256SUMS.txt)
