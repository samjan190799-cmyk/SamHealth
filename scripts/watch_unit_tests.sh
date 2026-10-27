#!/usr/bin/env bash
# Запускает тесты логики приложения часов в симуляторе Apple Watch (самая свежая модель из установленного Xcode).
# Запускать на macOS-раннере после `xcodegen generate`.
#
# Результат: watch_test_results/unit_tests.log, summary.txt, FormaWatchTests.xcresult
set -euo pipefail

OUT_DIR="${OUT_DIR:-watch_test_results}"
DERIVED="build/watch_unit_tests"
mkdir -p "$OUT_DIR"

pick_target() {
  python3 - <<'PY'
import json, re, subprocess

def simctl(*args):
    return json.loads(subprocess.check_output(["xcrun", "simctl", "list", "-j", *args]))

types = simctl("devicetypes")["devicetypes"]
runtimes = [r for r in simctl("runtimes")["runtimes"]
            if r.get("isAvailable") and r["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.watchOS")]

def version_key(r):
    return tuple(int(x) for x in re.findall(r"\d+", r["version"]))

best = None
for t in types:
    m = re.match(r"Apple Watch (Ultra|Series) (\d+) \((\d+)mm\)", t["name"])
    if not m:
        continue
    key = (int(m.group(2)), int(m.group(3)), m.group(1) == "Series")
    usable = [r for r in runtimes if t["identifier"] in [d["identifier"] for d in r.get("supportedDeviceTypes", [])]]
    if usable and (best is None or key > best[0]):
        best = (key, t, max(usable, key=version_key))
if best:
    print(f'{best[1]["name"]}|{best[1]["identifier"]}|{best[2]["identifier"]}')
PY
}

TARGET="$(pick_target)"
if [ -z "$TARGET" ]; then
  echo "watchOS-рантайм не найден, пробуем скачать..."
  xcodebuild -downloadPlatform watchOS
  TARGET="$(pick_target)"
fi
if [ -z "$TARGET" ]; then
  echo "❌ Не найден симулятор Apple Watch"
  exit 1
fi
NAME="${TARGET%%|*}"; REST="${TARGET#*|}"; TYPE_ID="${REST%%|*}"; RUNTIME_ID="${REST#*|}"
echo "Часы: $NAME ($RUNTIME_ID)"

UDID="$(xcrun simctl create "Forma Watch Tests" "$TYPE_ID" "$RUNTIME_ID")"
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b

echo "=== Загрузка Swift-пакетов ==="
for attempt in 1 2 3 4; do
  if xcodebuild -resolvePackageDependencies -project Forma.xcodeproj -scheme FormaWatch -derivedDataPath "$DERIVED"; then
    break
  fi
  if [ "$attempt" -eq 4 ]; then
    echo "❌ Swift-пакеты не скачались после 4 попыток"
    exit 1
  fi
  echo "⚠️ Не удалось скачать Swift-пакеты (попытка $attempt), повтор через 30 секунд..."
  sleep 30
done

echo "=== Тесты на часах: $NAME ==="
rm -rf "$OUT_DIR/FormaWatchTests.xcresult"
set +e
xcodebuild test \
  -project Forma.xcodeproj \
  -scheme FormaWatch \
  -destination "platform=watchOS Simulator,id=$UDID" \
  -only-testing:FormaWatchTests \
  -derivedDataPath "$DERIVED" \
  -resultBundlePath "$OUT_DIR/FormaWatchTests.xcresult" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO 2>&1 | tee "$OUT_DIR/unit_tests.log"
STATUS=${PIPESTATUS[0]}
set -e

echo "=== Итог ($NAME) ==="
{
  echo "Часы: $NAME"
  grep -E "Test Case '.*' (passed|failed)" "$OUT_DIR/unit_tests.log" || true
  grep -E "error: |Executed [0-9]+ tests" "$OUT_DIR/unit_tests.log" || true
} | tee "$OUT_DIR/summary.txt"

xcrun simctl shutdown "$UDID" || true
exit "$STATUS"
