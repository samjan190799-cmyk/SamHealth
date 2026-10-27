// swift-tools-version:5.9
import PackageDescription

// Проверка расчёта итогов недели без Xcode и без устройства:
//   cd Tests/WeeklySummary && swift test
// Исходник подключён символьной ссылкой на Sources/WeeklySummaryLogic.swift,
// поэтому тесты проверяют ровно тот код, который уходит в приложение.
let package = Package(
    name: "WeeklySummary",
    targets: [
        .target(name: "WeeklySummaryKit"),
        .testTarget(name: "WeeklySummaryKitTests", dependencies: ["WeeklySummaryKit"])
    ]
)
