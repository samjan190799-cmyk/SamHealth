#!/usr/bin/env bash
# Запускает юнит-тесты (схема FormaTests) в симуляторе iPhone на macOS-раннере.
# Запускать после `xcodegen generate`.
#
# Результат: test_results/unit_tests.log, test_results/summary.txt, test_results/FormaTests.xcresult
set -euo pipefail

OUT_DIR="${OUT_DIR:-test_results}"
DERIVED="build/unit_tests"
mkdir -p "$OUT_DIR"

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

echo "=== Загрузка Swift-пакетов ==="
# CDN рекламных SDK (Pangle/PAGAdSDK) периодически обрывает загрузку — несколько попыток
for attempt in 1 2 3 4; do
  if xcodebuild -resolvePackageDependencies -project Forma.xcodeproj -scheme FormaTests -derivedDataPath "$DERIVED"; then
    break
  fi
  if [ "$attempt" -eq 4 ]; then
    echo "❌ Swift-пакеты не скачались после 4 попыток"
    exit 1
  fi
  echo "⚠️ Не удалось скачать Swift-пакеты (попытка $attempt), повтор через 30 секунд..."
  sleep 30
done

echo "=== Юнит-тесты ==="
rm -rf "$OUT_DIR/FormaTests.xcresult"
set +e
xcodebuild test \
  -project Forma.xcodeproj \
  -scheme FormaTests \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$DERIVED" \
  -resultBundlePath "$OUT_DIR/FormaTests.xcresult" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO 2>&1 | tee "$OUT_DIR/unit_tests.log"
STATUS=${PIPESTATUS[0]}
set -e

echo "=== Итог ==="
{
  grep -E "Test Case '.*' (passed|failed)" "$OUT_DIR/unit_tests.log" || true
  grep -E "error: |Executed [0-9]+ tests" "$OUT_DIR/unit_tests.log" || true
} | tee "$OUT_DIR/summary.txt"

xcrun simctl shutdown "$UDID" || true
exit "$STATUS"
