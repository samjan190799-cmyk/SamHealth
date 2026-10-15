#!/usr/bin/env bash
# Снимает скриншоты всех вкладок Forma в симуляторе iPhone (светлая и тёмная тема,
# несколько экранов прокрутки). Нужен для сравнения стиля разделов «до/после».
# Запускать на macOS-раннере после `xcodegen generate`.
#
# Результат: tab_screenshots/<тема>/<NN_вкладка>/page_<n>.png
set -euo pipefail

BUNDLE_ID="com.samvel.forma"
OUT_DIR="${OUT_DIR:-tab_screenshots}"
DERIVED="build/tab_screenshots"
THEMES=(${THEMES:-dark light})
TABS=(${TABS:-0 1 2 3 4})
PAGES="${PAGES:-4}"
TAB_NAMES=(home workouts nutrition habits settings)

echo "=== Выбор симулятора iPhone ==="
PICK_PY="$(mktemp)"
cat > "$PICK_PY" <<'PY'
import json, re, subprocess

def simctl(*args):
    return json.loads(subprocess.check_output(["xcrun", "simctl", "list", "-j", *args]))

runtimes = [r for r in simctl("runtimes")["runtimes"]
            if r.get("isAvailable") and r["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS")]
runtimes.sort(key=lambda r: tuple(int(x) for x in re.findall(r"\d+", r["version"])), reverse=True)
devices = simctl("devices", "available")["devices"]

for rt in runtimes:
    candidates = [d for d in devices.get(rt["identifier"], []) if re.match(r"iPhone \d+ Pro( Max)?$|iPhone \d+$", d["name"])]
    candidates.sort(key=lambda d: (("Pro" in d["name"]) and ("Max" not in d["name"]), int(re.findall(r"\d+", d["name"])[0])), reverse=True)
    if candidates:
        print(candidates[0]["udid"], candidates[0]["name"].replace(" ", "_"))
        break
PY
read -r UDID NAME < <(python3 "$PICK_PY")
if [ -z "${UDID:-}" ]; then
  echo "❌ Не найден симулятор iPhone"
  exit 1
fi
echo "Симулятор: ${NAME//_/ } ($UDID)"

xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4 || true

echo "=== Сборка Forma (Debug, iOS Simulator) ==="
set -o pipefail
xcodebuild \
  -project Forma.xcodeproj \
  -scheme Forma \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build

APP_PATH="$(find "$DERIVED/Build/Products" -maxdepth 2 -name 'Forma.app' -path '*iphonesimulator*' | head -1)"
if [ -z "$APP_PATH" ]; then
  echo "❌ Forma.app не найден после сборки"
  exit 1
fi
xcrun simctl install "$UDID" "$APP_PATH"

for THEME in "${THEMES[@]}"; do
  for TAB in "${TABS[@]}"; do
    DIR="$OUT_DIR/$THEME/$(printf '%02d' "$TAB")_${TAB_NAMES[$TAB]}"
    mkdir -p "$DIR"
    for ((PAGE = 0; PAGE < PAGES; PAGE++)); do
      xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
      xcrun simctl launch "$UDID" "$BUNDLE_ID" \
        -FormaScreenshotScene "tab:$TAB" \
        -FormaScreenshotPage "$PAGE" \
        -app_theme "$THEME" \
        -app_language ru \
        -healthkit_auto_prompted_v3 YES >/dev/null
      sleep 7
      xcrun simctl io "$UDID" screenshot "$DIR/page_$PAGE.png" >/dev/null 2>&1
      echo "✓ $THEME / ${TAB_NAMES[$TAB]} / page $PAGE"
    done
  done
done

xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl shutdown "$UDID" || true
echo "=== Готово ==="
find "$OUT_DIR" -name '*.png' | wc -l
