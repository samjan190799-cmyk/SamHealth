#!/usr/bin/env bash
# Записывает видео анимации награды (AchievementCelebrationOverlay) в симуляторе iPhone
# и вырезает из него кадры. Запускать на macOS-раннере после `xcodegen generate`.
#
# Результат: achievement_preview/<категория>.mp4 и achievement_preview/<категория>_frames/*.png
set -euo pipefail

BUNDLE_ID="com.samvel.forma"
CATEGORIES=(${CATEGORIES:-steps streaks water})
OUT_DIR="${OUT_DIR:-achievement_preview}"
DERIVED="build/achievement_preview"
RECORD_SECONDS="${RECORD_SECONDS:-7}"

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
    # самый новый «Pro», затем остальные
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
echo "App: $APP_PATH"
xcrun simctl install "$UDID" "$APP_PATH"

mkdir -p "$OUT_DIR"

for CATEGORY in "${CATEGORIES[@]}"; do
  echo "=== Запись: $CATEGORY ==="
  VIDEO="$OUT_DIR/$CATEGORY.mp4"
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true

  xcrun simctl io "$UDID" recordVideo --codec h264 --force "$VIDEO" &
  REC_PID=$!
  sleep 1
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -FormaScreenshotScene "achievement:$CATEGORY"
  sleep "$RECORD_SECONDS"
  kill -INT "$REC_PID"
  wait "$REC_PID" || true
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true

  ls -l "$VIDEO"
done

echo "=== Кадры ==="
if ! command -v ffmpeg >/dev/null 2>&1; then
  brew install ffmpeg
fi
for CATEGORY in "${CATEGORIES[@]}"; do
  FRAMES="$OUT_DIR/${CATEGORY}_frames"
  mkdir -p "$FRAMES"
  # 4 кадра в секунду, масштаб до 390 пикселей по ширине — достаточно, чтобы оценить анимацию
  ffmpeg -loglevel error -y -i "$OUT_DIR/$CATEGORY.mp4" -vf "fps=4,scale=390:-1" "$FRAMES/frame_%02d.png"
  ls "$FRAMES" | wc -l
done

xcrun simctl shutdown "$UDID" || true
echo "=== Готово ==="
find "$OUT_DIR" -type f | sort | head -80
