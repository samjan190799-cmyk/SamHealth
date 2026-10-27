// swift-tools-version:5.9
import PackageDescription

// Проверка расчёта энергии без Xcode и без устройства:
//   cd Tests/EnergyModel && swift test
// Исходник подключён символьной ссылкой на Sources/EnergyModel.swift.
let package = Package(
    name: "EnergyModel",
    targets: [
        .target(name: "EnergyModelKit"),
        .testTarget(name: "EnergyModelKitTests", dependencies: ["EnergyModelKit"])
    ]
)
