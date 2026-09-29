// swift-tools-version:5.9
import PackageDescription

// Автономный пакет для проверки геометрии замера блюда без Xcode и без устройства:
//   cd Tests/PlateDepth && swift test
// Исходник алгоритма подключён символьной ссылкой на Sources/PlateDepthAnalyzer.swift,
// поэтому тесты всегда проверяют ровно тот код, который уходит в приложение.
let package = Package(
    name: "PlateDepth",
    targets: [
        .target(name: "PlateDepthKit"),
        .testTarget(name: "PlateDepthKitTests", dependencies: ["PlateDepthKit"])
    ]
)
