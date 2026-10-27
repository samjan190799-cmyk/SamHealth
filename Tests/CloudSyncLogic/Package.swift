// swift-tools-version:5.9
import PackageDescription

// Проверка правил синхронизации через iCloud без Xcode, iCloud и устройства:
//   cd Tests/CloudSyncLogic && swift test
// Исходник подключён символьной ссылкой на Sources/CloudSyncLogic.swift,
// поэтому тесты проверяют ровно тот код, который уходит в приложение.
let package = Package(
    name: "CloudSyncLogic",
    targets: [
        .target(name: "CloudSyncKit"),
        .testTarget(name: "CloudSyncKitTests", dependencies: ["CloudSyncKit"])
    ]
)
