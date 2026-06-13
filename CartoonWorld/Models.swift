import CoreLocation
import Foundation
import SwiftUI

struct DigitalProfile: Codable, Equatable {
    var id: UUID
    var isRegistered: Bool
    var displayName: String
    var identity: String
    var homeDistrict: String
    var motto: String
    var avatarSeed: Int

    static func randomDefault() -> DigitalProfile {
        let names = ["小云旅人", "像素阿辰", "海派圆圆", "霓虹小舟", "梧桐行者", "数字阿岚"]
        let identities = ["城市观察者", "实景采集员", "地图建造师", "生活探险家"]

        return DigitalProfile(
            id: UUID(),
            isRegistered: false,
            displayName: names.randomElement() ?? "数字居民",
            identity: identities.randomElement() ?? "城市观察者",
            homeDistrict: "黄浦区",
            motto: "把真实生活变成可爱的世界砖块",
            avatarSeed: Int.random(in: 0...6)
        )
    }
}

struct WorldPlace: Identifiable, Hashable {
    let id: String
    let name: String
    let city: WorldCity
    let district: String
    let latitude: Double
    let longitude: Double
    let role: PlaceRole
    let description: String
    let dailyActivities: [String]

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum WorldCity: String, CaseIterable, Codable, Hashable {
    case shanghai = "上海"
    case tokyo = "东京"
    case hongKong = "香港"
}

enum PlaceRole: String, CaseIterable, Hashable {
    case landmark = "地标"
    case neighborhood = "街区"
    case park = "公园"
    case transport = "交通"
    case lifestyle = "生活"

    var color: Color {
        switch self {
        case .landmark: .orange
        case .neighborhood: .cyan
        case .park: .green
        case .transport: .indigo
        case .lifestyle: .pink
        }
    }

    var symbolName: String {
        switch self {
        case .landmark: "building.2.crop.circle"
        case .neighborhood: "house.and.flag"
        case .park: "leaf"
        case .transport: "tram.fill"
        case .lifestyle: "figure.walk.motion"
        }
    }
}

struct MediaContribution: Identifiable, Codable, Equatable {
    var id: UUID
    var placeID: String
    var title: String
    var mediaKind: MediaKind
    var status: CartoonizationStatus
    var createdAt: Date
    var palette: [String]
    var thumbnailData: Data?
}

enum MediaKind: String, Codable, CaseIterable {
    case image = "照片"
    case video = "视频"
}

enum CartoonizationStatus: String, Codable, CaseIterable {
    case queued = "排队中"
    case stylizing = "卡通化中"
    case integrated = "已融入地图"
}

struct AvatarMood {
    let label: String
    let symbolName: String
    let color: Color
}
