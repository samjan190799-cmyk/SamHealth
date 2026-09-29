// swift-tools-version:5.9
import PackageDescription

// Проверка чистой логики тренировки без Xcode и без устройства:
//   cd Tests/WorkoutLogic && swift test
// Исходник подключён символьной ссылкой на Sources/WorkoutLogic.swift,
// поэтому тесты проверяют ровно тот код, который уходит в приложение.
let package = Package(
    name: "WorkoutLogic",
    targets: [
        .target(name: "WorkoutLogicKit"),
        .testTarget(name: "WorkoutLogicKitTests", dependencies: ["WorkoutLogicKit"])
    ]
)
