import Foundation

// DTOs mirroring the ESP32 API
struct StatusDto: Codable {
    let distanceCm: Int
    let objectPresent: Bool
    let alertTransition: Bool
    let manualTransition: Bool?
    let thresholdCm: Int?
    let timestampMs: Int64?
    let zones: [Int]?
    let periodicRefresh: Int?
    let photoOnAlert: Int?
}

struct DistanceSampleDto: Codable {
    let timestampMs: Int64
    let distanceCm: Int
}

struct HistoryDto: Codable {
    let samples: [DistanceSampleDto]
}

struct HealthDto: Codable {
    let ok: Bool
    let deviceName: String?
}

struct ThresholdRequestDto: Codable {
    let thresholdCm: Int
}
