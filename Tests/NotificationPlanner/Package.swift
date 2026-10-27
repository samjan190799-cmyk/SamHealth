// swift-tools-version:5.9
import PackageDescription

// Проверка плана напоминаний без Xcode и без устройства:
//   cd Tests/NotificationPlanner && swift test
// Исходник подключён символьной ссылкой на Sources/NotificationPlanner.swift.
let package = Package(
    name: "NotificationPlanner",
    targets: [
        .target(name: "NotificationPlannerKit"),
        .testTarget(name: "NotificationPlannerKitTests", dependencies: ["NotificationPlannerKit"])
    ]
)
