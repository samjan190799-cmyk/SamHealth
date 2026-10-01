#!/usr/bin/env bash
# Снимает скриншоты Apple Watch приложения Forma в симуляторе новейших часов
# (Apple Watch Ultra и Series — берётся самая свежая модель из установленного Xcode).
# Запускать на macOS-раннере после `xcodegen generate`.
#
# Результат: watch_screenshots/<модель>/<сцена>.png в нативном разрешении симулятора,
# которое совпадает с требованиями App Store Connect для этой модели часов.
set -euo pipefail

BUNDLE_ID="com.samvel.forma.watchkitapp"
SCENES=(list active rest)
OUT_DIR="${OUT_DIR:-watch_screenshots}"
DERIVED="build/watch_screenshots"

echo "=== Доступные часы в симуляторе ==="
xcrun simctl list devicetypes | grep -i "apple watch" || true

# Выбираем самые свежие Ultra и Series (по номеру поколения и размеру корпуса)
# и самый новый watchOS-рантайм, который их поддерживает.
pick_targets() {
  python3 - <<'PY'
import json, re, subprocess

def simctl(*args):
    return json.loads(subprocess.check_output(["xcrun", "simctl", "list", "-j", *args]))

types = simctl("devicetypes")["devicetypes"]
runtimes = [r for r in simctl("runtimes")["runtimes"]
            if r.get("isAvailable") and r["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.watchOS")]

def version_key(r):
    return tuple(int(x) for x in re.findall(r"\d+", r["version"]))

best = {}
for t in types:
    m = re.match(r"Apple Watch (Ultra|Series) (\d+) \((\d+)mm\)", t["name"])
    if not m:
        continue
    family, gen, mm = m.group(1), int(m.group(2)), int(m.group(3))
    if family not in best or (gen, mm) > best[family][0]:
        best[family] = ((gen, mm), t)

for family, (_, t) in sorted(best.items()):
    usable = [r for r in runtimes if t["identifier"] in [d["identifier"] for d in r.get("supportedDeviceTypes", [])]]
    if not usable:
        continue
    rt = max(usable, key=version_key)
    print(f'{t["name"]}|{t["identifier"]}|{rt["identifier"]}')
PY
}

TARGETS="$(pick_targets)"
if [ -z "$TARGETS" ]; then
  echo "watchOS-рантайм для новейших часов не найден, пробуем скачать..."
  xcodebuild -downloadPlatform watchOS
  TARGETS="$(pick_targets)"
fi
if [ -z "$TARGETS" ]; then
  echo "❌ Не удалось найти симулятор Apple Watch Ultra/Series"
  exit 1
fi
echo "=== Выбранные устройства ==="
echo "$TARGETS"

# Собираем приложение один раз: Debug, чтобы работал режим съёмки (-FormaScreenshotScene).
# Нужен рантайм watchOS любого из выбранных устройств — берём первый.
FIRST_NAME="$(echo "$TARGETS" | head -1 | cut -d'|' -f1)"
FIRST_TYPE="$(echo "$TARGETS" | head -1 | cut -d'|' -f2)"
FIRST_RUNTIME="$(echo "$TARGETS" | head -1 | cut -d'|' -f3)"
BUILD_UDID="$(xcrun simctl create "Forma build $FIRST_NAME" "$FIRST_TYPE" "$FIRST_RUNTIME")"

echo "=== Сборка FormaWatch (Debug, watchOS Simulator) ==="
set -o pipefail
xcodebuild \
  -project Forma.xcodeproj \
  -scheme FormaWatch \
  -configuration Debug \
  -destination "platform=watchOS Simulator,id=$BUILD_UDID" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build
xcrun simctl delete "$BUILD_UDID"

APP_PATH="$(find "$DERIVED/Build/Products" -maxdepth 2 -name 'FormaWatch.app' -path '*watchsimulator*' | head -1)"
if [ -z "$APP_PATH" ]; then
  echo "❌ FormaWatch.app не найден после сборки"
  exit 1
fi
echo "App: $APP_PATH"

mkdir -p "$OUT_DIR"

while IFS='|' read -r NAME TYPE_ID RUNTIME_ID; do
  [ -z "$NAME" ] && continue
  SLUG="$(echo "$NAME" | tr -c 'A-Za-z0-9\n' '_' | sed 's/_*$//')"
  echo "=== $NAME ==="

  UDID="$(xcrun simctl create "Forma $NAME" "$TYPE_ID" "$RUNTIME_ID")"
  xcrun simctl boot "$UDID"
  xcrun simctl bootstatus "$UDID" -b
  xcrun simctl install "$UDID" "$APP_PATH"

  mkdir -p "$OUT_DIR/$SLUG"
  for SCENE in "${SCENES[@]}"; do
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl launch "$UDID" "$BUNDLE_ID" -FormaScreenshotScene "$SCENE"
    sleep 8
    xcrun simctl io "$UDID" screenshot "$OUT_DIR/$SLUG/$SCENE.png"
    sips -g pixelWidth -g pixelHeight "$OUT_DIR/$SLUG/$SCENE.png" | tail -2
  done

  xcrun simctl shutdown "$UDID" || true
  xcrun simctl delete "$UDID" || true
done <<< "$TARGETS"

echo "=== Готово ==="
find "$OUT_DIR" -name '*.png' | sort
