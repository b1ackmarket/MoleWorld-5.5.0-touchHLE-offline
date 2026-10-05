#!/bin/bash
# make-troll-ipa.sh — 摩尔庄园HD touchHLE 巨魔(TrollStore)专用打包
# 关键点:巨魔安装会把 bundle 内散落 armv7 guest dylib thin 成 arm64 空壳。
# 方案:散落 dylib 清零,5 个原始 armv6/v7 库打进 touchHLE_dylibs.zip(bundle 根),
#      paths.rs 散落读取必然失败→走 zip 兜底读到完整库。主程序包成单 arch fat(arm64)。
#
# 用法:
#   bash dev-scripts/make-troll-ipa.sh [输出目录]
#   游戏主程序(解包后的 MoleWorld.app)放在仓库根 01-cracked/Payload/MoleWorld.app,
#   或通过环境变量 MOLE_GAME_APP 指定绝对路径。
set -euo pipefail

# touchHLE 源码目录(脚本位于 dev-scripts/ 下,上级即源码根)
BASE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASE"

# 输出目录:参数 1,缺省为当前目录
OUTDIR="${1:-$BASE}"

EXE="target/aarch64-apple-ios/release/touchHLE"
GAME_APP="${MOLE_GAME_APP:-$BASE/../../01-cracked/Payload/MoleWorld.app}"
ICON_SRC="res/icon.png"
APPNAME="MoleWorldHD"
STAGE="$BASE/_troll_stage"
APP="$STAGE/Payload/$APPNAME.app"

[ -f "$EXE" ] || { echo "缺少 $EXE,先跑 dev-scripts/build-ios.sh"; exit 1; }
[ -d "$GAME_APP" ] || { echo "缺少游戏主程序 $GAME_APP"; echo "请把解包后的 MoleWorld.app 放到仓库根 01-cracked/Payload/,或设 MOLE_GAME_APP"; exit 1; }
[ -f "$ICON_SRC" ] || { echo "缺少图标 $ICON_SRC"; exit 1; }

rm -rf "$STAGE" && mkdir -p "$APP"

# 1) 主可执行:thin->单 arch fat(arm64),必须在签名前(lipo 清签名)
cp "$EXE" "$APP/$APPNAME.thin"
lipo -create "$APP/$APPNAME.thin" -output "$APP/$APPNAME"
rm -f "$APP/$APPNAME.thin"
chmod +x "$APP/$APPNAME"

# 2) touchHLE 运行时资源
cp -R touchHLE_fonts "$APP/"
cp touchHLE_default_options.txt "$APP/"

# 2.5) 5 个 guest dylib(保留原始 armv6/v7)打进 touchHLE_dylibs.zip,放 bundle 根。
#      注意 zip 条目名必须是 basename(paths.rs by_name(name) 取 basename)。
#      【刻意】不把散落 dylib 拷进 bundle——巨魔安装会精简散落 Mach-O。
for f in touchHLE_dylibs/*.dylib; do
	(cd touchHLE_dylibs && zip -X -q "$APP/touchHLE_dylibs.zip" "$(basename "$f")")
done
echo "--- touchHLE_dylibs.zip 条目 ---"
unzip -l "$APP/touchHLE_dylibs.zip"

# 3) 游戏打成 MoleWorld.ipa(store zip,Payload/MoleWorld.app),放 .app 根
rm -rf "$BASE/_game_stage" && mkdir -p "$BASE/_game_stage/Payload"
cp -R "$GAME_APP" "$BASE/_game_stage/Payload/MoleWorld.app"
find "$BASE/_game_stage/Payload/MoleWorld.app" \( -name "*.decoded.plist" -o -name ".DS_Store" \) -delete || true
( cd "$BASE/_game_stage" && zip -r -X -0 -q "$APP/MoleWorld.ipa" Payload )
rm -rf "$BASE/_game_stage"

# 4) 图标(现代机型 @3x 必须有 AppIcon60x60@3x.png)
sips -z 120 120 "$ICON_SRC" --out "$APP/AppIcon60x60@2x.png"        >/dev/null
sips -z 180 180 "$ICON_SRC" --out "$APP/AppIcon60x60@3x.png"        >/dev/null
sips -z 76  76  "$ICON_SRC" --out "$APP/AppIcon76x76~ipad.png"      >/dev/null
sips -z 152 152 "$ICON_SRC" --out "$APP/AppIcon76x76@2x~ipad.png"   >/dev/null
sips -z 167 167 "$ICON_SRC" --out "$APP/AppIcon83.5x83.5@2x~ipad.png" >/dev/null
sips -z 1024 1024 "$ICON_SRC" --out "$APP/AppIcon1024.png"          >/dev/null

# 5) Info.plist
cat > "$APP/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>          <string>MoleWorldHD</string>
	<key>CFBundleIdentifier</key>          <string>org.touchhle.moleworldhd</string>
	<key>CFBundleName</key>                <string>MoleWorldHD</string>
	<key>CFBundleDisplayName</key>         <string>摩尔庄园HD</string>
	<key>CFBundleVersion</key>             <string>5.5.0</string>
	<key>CFBundleShortVersionString</key>  <string>5.5.0</string>
	<key>CFBundlePackageType</key>         <string>APPL</string>
	<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
	<key>LSRequiresIPhoneOS</key>          <true/>
	<key>MinimumOSVersion</key>            <string>13.0</string>
	<key>UIRequiresFullScreen</key>        <true/>
	<key>UIFileSharingEnabled</key>        <true/>
	<key>LSSupportsOpeningDocumentsInPlace</key> <true/>
	<key>CFBundleSupportedPlatforms</key>  <array><string>iPhoneOS</string></array>
	<key>UIDeviceFamily</key>              <array><integer>1</integer><integer>2</integer></array>
	<key>UILaunchScreen</key>              <dict/>
	<key>UISupportedInterfaceOrientations</key>
	<array>
		<string>UIInterfaceOrientationLandscapeRight</string>
		<string>UIInterfaceOrientationLandscapeLeft</string>
	</array>
	<key>UISupportedInterfaceOrientations~ipad</key>
	<array>
		<string>UIInterfaceOrientationLandscapeRight</string>
		<string>UIInterfaceOrientationLandscapeLeft</string>
	</array>
	<key>CFBundleIconFiles</key>
	<array>
		<string>AppIcon60x60</string>
		<string>AppIcon76x76</string>
	</array>
	<key>CFBundleIcons</key>
	<dict>
		<key>CFBundlePrimaryIcon</key>
		<dict>
			<key>CFBundleIconFiles</key>
			<array><string>AppIcon60x60</string></array>
		</dict>
	</dict>
	<key>CFBundleIcons~ipad</key>
	<dict>
		<key>CFBundlePrimaryIcon</key>
		<dict>
			<key>CFBundleIconFiles</key>
			<array><string>AppIcon60x60</string><string>AppIcon76x76</string></array>
		</dict>
	</dict>
</dict>
</plist>
PLIST

# 5.5) ad-hoc 签名。bundle 内除主程序外无其他 Mach-O(游戏在 zip 里、guest 库在 zip 里),
#      签主程序即可;--deep 封 bundle。
cat > "$STAGE/entitlements.plist" <<'ENT'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
</dict>
</plist>
ENT
codesign --force --deep --sign - --entitlements "$STAGE/entitlements.plist" --generate-entitlement-der "$APP"
echo "--- 签名核对 ---"
codesign -dv "$APP/MoleWorldHD" 2>&1 | grep -iE "Signature|Identifier|format" | head -4 || true
codesign --verify --verbose=2 "$APP/MoleWorldHD" 2>&1 | head -3 && echo "OK 主程序签名通过" || echo "(verify 警告;ad-hoc 巨魔通常接受)"

# 6) 打包成 IPA
rm -f "$OUTDIR/摩尔庄园HD-ios-TrollStore.ipa"
( cd "$STAGE" && zip -r -X -q "$OUTDIR/摩尔庄园HD-ios-TrollStore.ipa" Payload )
rm -rf "$STAGE"
echo "✓ 已生成 $OUTDIR/摩尔庄园HD-ios-TrollStore.ipa"
ls -la "$OUTDIR/摩尔庄园HD-ios-TrollStore.ipa"
