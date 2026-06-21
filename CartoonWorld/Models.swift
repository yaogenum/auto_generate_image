import CoreLocation
import Foundation
import SwiftUI

enum CommunicationCadence: String, Codable {
    case none = "未设置"
    case weekly = "每周固定"
}

struct FamilyMember: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var relationship: String
    var phoneNumber: String
    var birthday: Date?
    var cadenceDay: Int
    var cadenceTime: String
    var isSelf: Bool
    var avatarSeed: Int

    static func selfProfile(from profile: DigitalProfile) -> FamilyMember {
        FamilyMember(
            id: "self",
            name: profile.displayName,
            relationship: "自己",
            phoneNumber: "",
            birthday: nil,
            cadenceDay: 1,
            cadenceTime: "20:00",
            isSelf: true,
            avatarSeed: profile.avatarSeed
        )
    }

    static func empty() -> FamilyMember {
        FamilyMember(
            id: UUID().uuidString,
            name: "新家人",
            relationship: "家人",
            phoneNumber: "",
            birthday: nil,
            cadenceDay: 2,
            cadenceTime: "20:00",
            isSelf: false,
            avatarSeed: Int.random(in: 0...6)
        )
    }

    func isBirthdayToday(on date: Date = .now) -> Bool {
        guard let birthday else { return false }
        let calendar = Calendar.current
        let target = calendar.dateComponents([.month, .day], from: birthday)
        let today = calendar.dateComponents([.month, .day], from: date)
        return target.month == today.month && target.day == today.day
    }

    func isWeeklyChatDue(on date: Date = .now) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let mondayBased = weekday == 1 ? 7 : weekday - 1
        return cadenceDay == mondayBased
    }

    var weeklyChatLabel: String {
        let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
        let dayIndex = (1...7).contains(cadenceDay) ? cadenceDay - 1 : 0
        return "每周\(weekdays[dayIndex]) \(cadenceTime)"
    }

    var hasContact: Bool {
        !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    mutating func syncDisplayName(_ name: String, avatarSeed: Int) {
        self.name = name
        self.avatarSeed = avatarSeed
    }

    var relationForSelfNarrative: String {
        if isSelf {
            return "自己"
        }
        let safeRelationship = relationship.trimmingCharacters(in: .whitespacesAndNewlines)
        if safeRelationship.isEmpty {
            return "家人"
        }
        return "我的\(safeRelationship)"
    }
}

enum FamilyRolePreset: String, CaseIterable {
    case selfRole = "自己"
    case mother = "妈妈"
    case father = "爸爸"
    case grandmother = "奶奶"
    case grandpa = "爷爷"
    case elderBrother = "哥哥"
    case elderSister = "姐姐"
    case youngerBrother = "弟弟"
    case youngerSister = "妹妹"
    case spouse = "配偶"
    case son = "儿子"
    case daughter = "女儿"
    case friend = "好友"
    case roommate = "同住者"

    static let familyDefaults: [FamilyRolePreset] = [.mother, .father, .grandmother, .grandpa, .elderBrother, .elderSister, .youngerBrother, .youngerSister]
    static let socialDefaults: [FamilyRolePreset] = [.spouse, .son, .daughter, .friend, .roommate]

    var title: String { rawValue }
}

enum FamilyContactLayout: String, CaseIterable {
    case topology = "拓扑"
    case list = "列表"

    var title: String { rawValue }
}

struct FamilyMessage: Identifiable, Codable, Equatable {
    var id: UUID
    var memberID: String
    var isFromSelf: Bool
    var text: String
    var createdAt: Date
}

enum ContactConversationEndpoint: String, Codable, CaseIterable {
    case localAgent = "本机Agent"
    case remoteAgent = "线上Agent"
    case humanUser = "真人用户"
    case humanOffline = "真人未登录"

    var shortLabel: String { rawValue }

    var detail: String {
        switch self {
        case .localAgent:
            "当前由本机会话里的 Agent 数字分身代答，适合本地模拟。"
        case .remoteAgent:
            "对应联系人背后是云端 Agent 或联系人数字分身。"
        case .humanUser:
            "对应联系人是真实用户，默认等待对方真人回复。"
        case .humanOffline:
            "对应联系人未登录，消息先由数字分身代收并生成待确认事项。"
        }
    }
}

enum SelfProxyMode: String, Codable, CaseIterable {
    case autopilot = "分身代答"
    case human = "本人处理"
    case issueReview = "待本人确认"

    var detail: String {
        switch self {
        case .autopilot:
            "默认由你的数字分身先对外回答。"
        case .human:
            "外部消息直接切回本人处理，分身只做记录。"
        case .issueReview:
            "分身先生成建议回复，再列成 issue 交给本人确认。"
        }
    }
}

enum AgentIssueStatus: String, Codable, CaseIterable {
    case open = "待确认"
    case approved = "已发送"
    case deferred = "本人接管"
    case dismissed = "已忽略"
}

struct AgentIssue: Identifiable, Codable, Equatable {
    var id: UUID
    var memberID: String
    var prompt: String
    var suggestedReply: String
    var createdAt: Date
    var status: AgentIssueStatus
}

struct FamilyMoment: Identifiable, Codable, Equatable {
    var id: UUID
    var memberID: String
    var placeID: String?
    var title: String
    var note: String
    var date: Date
    var city: String
    var placeName: String
}

struct FamilyRelationEdge: Identifiable {
    let id: String
    let sourceMemberID: String
    let targetMemberID: String
    let relationLabel: String
}

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

enum WorldDisplayMode: String, CaseIterable, Hashable {
    case real3D
    case cartoon

    var title: String {
        switch self {
        case .real3D: "真实3D"
        case .cartoon: "卡通沙盘"
        }
    }

    var symbolName: String {
        switch self {
        case .real3D: "globe.asia.australia.fill"
        case .cartoon: "sparkles"
        }
    }

    var shortTitle: String {
        switch self {
        case .real3D: "3D"
        case .cartoon: "沙盘"
        }
    }

    var toggled: WorldDisplayMode {
        switch self {
        case .real3D: .cartoon
        case .cartoon: .real3D
        }
    }
}

enum WorldPanelSection: String, CaseIterable {
    case explore = "探索"
    case moments = "Moments"
    case relations = "关系网络"

    var title: String { rawValue }
}

enum WorldCity: String, CaseIterable, Codable, Hashable {
    case shanghai = "上海"
    case tokyo = "东京"
    case osaka = "大阪"
    case nagoya = "名古屋"
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
    var mediaURL: String?
    var summary: String?
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
