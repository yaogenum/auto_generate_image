import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class WorldModel {
    var profile: DigitalProfile
    var places: [WorldPlace]
    var contributions: [MediaContribution]
    var selectedPlaceID: String
    var avatarEnergy: Double
    var worldScaleMeters: Double

    private let profileKey = "CartoonWorld.profile.v1"
    private let contributionKey = "CartoonWorld.contributions.v1"

    init(
        profile: DigitalProfile? = nil,
        places: [WorldPlace] = WorldSeed.places,
        contributions: [MediaContribution]? = nil
    ) {
        self.profile = profile ?? Self.loadProfile() ?? .randomDefault()
        self.places = places
        self.contributions = contributions ?? Self.loadContributions()
        self.selectedPlaceID = places.first?.id ?? "the-bund"
        self.avatarEnergy = 0.72
        self.worldScaleMeters = 6_340_000
    }

    var selectedPlace: WorldPlace {
        places.first(where: { $0.id == selectedPlaceID }) ?? places[0]
    }

    var contributionsForSelectedPlace: [MediaContribution] {
        contributions
            .filter { $0.placeID == selectedPlaceID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var currentMood: AvatarMood {
        if avatarEnergy > 0.78 {
            AvatarMood(label: "探索欲旺盛", symbolName: "sparkles", color: .yellow)
        } else if avatarEnergy > 0.45 {
            AvatarMood(label: "城市漫游中", symbolName: "figure.walk", color: .mint)
        } else {
            AvatarMood(label: "需要补给", symbolName: "cup.and.saucer.fill", color: .brown)
        }
    }

    static var preview: WorldModel {
        let model = WorldModel(contributions: [
            MediaContribution(
                id: UUID(),
                placeID: "the-bund",
                title: "外滩傍晚街景",
                mediaKind: .image,
                status: .integrated,
                createdAt: .now,
                palette: ["#4AD4AE", "#FFB547", "#7A6FF0"],
                thumbnailData: nil
            )
        ])
        model.profile.isRegistered = true
        return model
    }

    func bootstrapIfNeeded() {
        saveProfile()
    }

    func register(displayName: String, identity: String, homeDistrict: String, motto: String) {
        profile.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.identity = identity.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.homeDistrict = homeDistrict.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.motto = motto.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.isRegistered = true
        saveProfile()
    }

    func randomizeGuestIdentity() {
        profile = .randomDefault()
        saveProfile()
    }

    func moveAvatar(to placeID: String) {
        selectedPlaceID = placeID
        avatarEnergy = min(1.0, avatarEnergy + 0.06)
    }

    func performDailyAction(_ action: String) {
        let energyDelta = action.contains("休息") || action.contains("咖啡") ? 0.12 : -0.07
        avatarEnergy = min(1.0, max(0.1, avatarEnergy + energyDelta))
    }

    func addContribution(placeID: String, title: String, mediaKind: MediaKind, rawData: Data?) {
        let thumbnail = Self.makeThumbnailData(from: rawData)
        let contribution = MediaContribution(
            id: UUID(),
            placeID: placeID,
            title: title.isEmpty ? "新的真实世界素材" : title,
            mediaKind: mediaKind,
            status: .queued,
            createdAt: .now,
            palette: Self.cartoonPalette(from: rawData),
            thumbnailData: thumbnail
        )
        contributions.insert(contribution, at: 0)
        saveContributions()

        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(650))
            self?.advanceContribution(contribution.id, to: .stylizing)
            try? await Task.sleep(for: .milliseconds(900))
            self?.advanceContribution(contribution.id, to: .integrated)
        }
    }

    private func advanceContribution(_ id: UUID, to status: CartoonizationStatus) {
        guard let index = contributions.firstIndex(where: { $0.id == id }) else { return }
        contributions[index].status = status
        saveContributions()
    }

    private func saveProfile() {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: profileKey)
    }

    private func saveContributions() {
        guard let data = try? JSONEncoder().encode(contributions) else { return }
        UserDefaults.standard.set(data, forKey: contributionKey)
    }

    private static func loadProfile() -> DigitalProfile? {
        guard let data = UserDefaults.standard.data(forKey: "CartoonWorld.profile.v1") else { return nil }
        return try? JSONDecoder().decode(DigitalProfile.self, from: data)
    }

    private static func loadContributions() -> [MediaContribution] {
        guard let data = UserDefaults.standard.data(forKey: "CartoonWorld.contributions.v1") else { return [] }
        return (try? JSONDecoder().decode([MediaContribution].self, from: data)) ?? []
    }

    private static func cartoonPalette(from data: Data?) -> [String] {
        guard let data, let image = UIImage(data: data) else {
            return ["#5FE0C0", "#FFD166", "#EF476F"]
        }

        let size = CGSize(width: 24, height: 24)
        let renderer = UIGraphicsImageRenderer(size: size)
        let smallImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let cgImage = smallImage.cgImage,
              let provider = cgImage.dataProvider,
              let pixelData = provider.data,
              let bytes = CFDataGetBytePtr(pixelData) else {
            return ["#5FE0C0", "#FFD166", "#EF476F"]
        }

        var buckets: [(r: Int, g: Int, b: Int)] = []
        let bytesPerPixel = 4
        for index in stride(from: 0, to: min(CFDataGetLength(pixelData), 24 * 24 * bytesPerPixel), by: bytesPerPixel * 29) {
            buckets.append((Int(bytes[index]), Int(bytes[index + 1]), Int(bytes[index + 2])))
        }

        return buckets.prefix(4).map { color in
            String(format: "#%02X%02X%02X", color.r, color.g, color.b)
        }
    }

    private static func makeThumbnailData(from data: Data?) -> Data? {
        guard let data, let image = UIImage(data: data) else { return nil }
        let target = CGSize(width: 320, height: 220)
        let renderer = UIGraphicsImageRenderer(size: target)
        let thumbnail = renderer.image { context in
            UIColor(red: 0.08, green: 0.13, blue: 0.18, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: target))
            image.draw(in: CGRect(origin: .zero, size: target))
            UIColor.white.withAlphaComponent(0.26).setStroke()
            context.cgContext.setLineWidth(4)
            context.cgContext.stroke(CGRect(x: 8, y: 8, width: target.width - 16, height: target.height - 16))
        }
        return thumbnail.jpegData(compressionQuality: 0.72)
    }
}

enum WorldSeed {
    static let places: [WorldPlace] = shanghai + tokyo + hongKong

    static let shanghai: [WorldPlace] = [
        WorldPlace(
            id: "the-bund",
            name: "外滩",
            city: .shanghai,
            district: "黄浦区",
            latitude: 31.2400,
            longitude: 121.4900,
            role: .landmark,
            description: "上海卡通世界的起始核心区，真实城市天际线会被转译成圆润积木楼群。",
            dailyActivities: ["沿江散步", "采集建筑纹理", "和游客交换故事"]
        ),
        WorldPlace(
            id: "lianhua-road",
            name: "莲花路生活圈",
            city: .shanghai,
            district: "闵行区",
            latitude: 31.1310,
            longitude: 121.4017,
            role: .lifestyle,
            description: "适合模拟日常生活：通勤、吃饭、购物、邻里互动都会成为数字人的生活事件。",
            dailyActivities: ["坐地铁通勤", "买一杯咖啡", "整理背包"]
        ),
        WorldPlace(
            id: "luchiazui",
            name: "陆家嘴",
            city: .shanghai,
            district: "浦东新区",
            latitude: 31.2363,
            longitude: 121.5025,
            role: .landmark,
            description: "高层建筑以夸张比例立在地图上，是未来 3D 城市资产密度最高的区域。",
            dailyActivities: ["观察城市经济", "登高看云", "解锁摩天楼任务"]
        ),
        WorldPlace(
            id: "xujiahui",
            name: "徐家汇",
            city: .shanghai,
            district: "徐汇区",
            latitude: 31.1836,
            longitude: 121.4330,
            role: .neighborhood,
            description: "购物、学校、公园和老建筑混合，适合构建数字人的学习和社交系统。",
            dailyActivities: ["逛商场", "学习技能", "拍摄街角照片"]
        ),
        WorldPlace(
            id: "people-square",
            name: "人民广场",
            city: .shanghai,
            district: "黄浦区",
            latitude: 31.2304,
            longitude: 121.4737,
            role: .transport,
            description: "城市交通与任务分发中心，可作为未来多人在线集合点。",
            dailyActivities: ["换乘地铁", "接取城市任务", "查看地图公告"]
        ),
        WorldPlace(
            id: "century-park",
            name: "世纪公园",
            city: .shanghai,
            district: "浦东新区",
            latitude: 31.2167,
            longitude: 121.5504,
            role: .park,
            description: "绿色区域会以低多边形树木和柔和草地表现，提供恢复体力和社交活动。",
            dailyActivities: ["野餐休息", "晨跑", "收集植物图鉴"]
        ),
        WorldPlace(
            id: "yu-garden",
            name: "豫园",
            city: .shanghai,
            district: "黄浦区",
            latitude: 31.2272,
            longitude: 121.4920,
            role: .landmark,
            description: "江南园林与老城厢生活交汇，可作为传统建筑素材和节庆任务区域。",
            dailyActivities: ["逛九曲桥", "采集飞檐纹样", "完成节庆委托"]
        ),
        WorldPlace(
            id: "jingan-temple",
            name: "静安寺",
            city: .shanghai,
            district: "静安区",
            latitude: 31.2233,
            longitude: 121.4456,
            role: .landmark,
            description: "高楼之间的金色地标，适合作为城市精神值和祈愿系统节点。",
            dailyActivities: ["点亮地标", "收集钟声", "观察街区人流"]
        ),
        WorldPlace(
            id: "tianzifang",
            name: "田子坊",
            city: .shanghai,
            district: "黄浦区",
            latitude: 31.2107,
            longitude: 121.4686,
            role: .neighborhood,
            description: "弄堂、手作店和小餐馆密集，适合真实照片转为卡通街巷资产。",
            dailyActivities: ["拍弄堂照片", "拜访小店", "制作纪念品"]
        ),
        WorldPlace(
            id: "shanghai-tower",
            name: "上海中心",
            city: .shanghai,
            district: "浦东新区",
            latitude: 31.2335,
            longitude: 121.5055,
            role: .landmark,
            description: "城市最高点，未来可作为整座上海世界的瞭望塔和地图解锁入口。",
            dailyActivities: ["登高同步地图", "观察云层", "解锁城市视野"]
        ),
        WorldPlace(
            id: "hongqiao-hub",
            name: "虹桥枢纽",
            city: .shanghai,
            district: "闵行区",
            latitude: 31.1945,
            longitude: 121.3188,
            role: .transport,
            description: "高铁、机场和地铁汇聚，可作为跨城旅行和东京传送的现实锚点。",
            dailyActivities: ["办理出发", "查看跨城任务", "整理行李"]
        ),
        WorldPlace(
            id: "dishui-lake",
            name: "滴水湖",
            city: .shanghai,
            district: "浦东新区",
            latitude: 30.9096,
            longitude: 121.9291,
            role: .park,
            description: "临港水域场景，适合扩展海风、骑行、未来城市和港口玩法。",
            dailyActivities: ["湖边骑行", "收集海风", "拍摄日落"]
        ),
        WorldPlace(
            id: "wukang-road",
            name: "武康路",
            city: .shanghai,
            district: "徐汇区",
            latitude: 31.2076,
            longitude: 121.4389,
            role: .neighborhood,
            description: "梧桐街道和历史建筑密集，适合日常漫游和照片卡通化融合。",
            dailyActivities: ["漫步梧桐街", "采集老建筑", "寻找咖啡馆"]
        ),
        WorldPlace(
            id: "shanghai-disney",
            name: "上海迪士尼度假区",
            city: .shanghai,
            district: "浦东新区",
            latitude: 31.1443,
            longitude: 121.6570,
            role: .lifestyle,
            description: "高密度娱乐区域，适合节日活动、拍照任务和游客互动事件。",
            dailyActivities: ["参加巡游", "收集徽章", "拍摄城堡"]
        ),
        WorldPlace(
            id: "longhua-temple",
            name: "龙华寺",
            city: .shanghai,
            district: "徐汇区",
            latitude: 31.1732,
            longitude: 121.4525,
            role: .landmark,
            description: "古塔与寺院构成安静地标，可作为历史记忆和城市修复任务点。",
            dailyActivities: ["修复古塔纹理", "听钟声", "整理历史碎片"]
        )
    ]

    static let tokyo: [WorldPlace] = [
        WorldPlace(
            id: "tokyo-station",
            name: "东京站",
            city: .tokyo,
            district: "千代田区",
            latitude: 35.6812,
            longitude: 139.7671,
            role: .transport,
            description: "东京世界的交通核心，可作为新干线、地铁和跨城任务集散地。",
            dailyActivities: ["换乘列车", "接取跨城委托", "查看站内商店"]
        ),
        WorldPlace(
            id: "shibuya-crossing",
            name: "涩谷十字路口",
            city: .tokyo,
            district: "涩谷区",
            latitude: 35.6595,
            longitude: 139.7005,
            role: .lifestyle,
            description: "高人流城市舞台，适合做动态人群、霓虹广告和街头任务。",
            dailyActivities: ["穿越路口", "拍霓虹照片", "完成街头采访"]
        ),
        WorldPlace(
            id: "tokyo-tower",
            name: "东京塔",
            city: .tokyo,
            district: "港区",
            latitude: 35.6586,
            longitude: 139.7454,
            role: .landmark,
            description: "东京经典高塔地标，可作为地图视野同步和夜景拍摄节点。",
            dailyActivities: ["同步夜景", "登塔观城", "收集红白塔纹理"]
        ),
        WorldPlace(
            id: "skytree",
            name: "东京晴空塔",
            city: .tokyo,
            district: "墨田区",
            latitude: 35.7101,
            longitude: 139.8107,
            role: .landmark,
            description: "东京东部最高地标，适合云端探索和远景解锁。",
            dailyActivities: ["登高看云", "解锁东东京", "拍摄天际线"]
        ),
        WorldPlace(
            id: "sensoji",
            name: "浅草寺",
            city: .tokyo,
            district: "台东区",
            latitude: 35.7148,
            longitude: 139.7967,
            role: .landmark,
            description: "传统街区与寺院入口，适合祭典、商店街和历史纹样素材。",
            dailyActivities: ["逛仲见世", "采集灯笼纹样", "参加祭典"]
        ),
        WorldPlace(
            id: "ueno-park",
            name: "上野公园",
            city: .tokyo,
            district: "台东区",
            latitude: 35.7156,
            longitude: 139.7745,
            role: .park,
            description: "博物馆、湖面和樱花区域，可作为恢复体力和图鉴收集场景。",
            dailyActivities: ["赏樱散步", "参观博物馆", "收集植物图鉴"]
        ),
        WorldPlace(
            id: "akihabara",
            name: "秋叶原",
            city: .tokyo,
            district: "千代田区",
            latitude: 35.6984,
            longitude: 139.7730,
            role: .lifestyle,
            description: "电子、动漫和霓虹招牌密集，适合数字人装备、小游戏和素材市场。",
            dailyActivities: ["逛电器街", "升级装备", "拍摄招牌"]
        ),
        WorldPlace(
            id: "ginza",
            name: "银座",
            city: .tokyo,
            district: "中央区",
            latitude: 35.6717,
            longitude: 139.7649,
            role: .neighborhood,
            description: "高级商业街区，适合时装、橱窗和夜间城市生活事件。",
            dailyActivities: ["浏览橱窗", "参加展览", "收集时装灵感"]
        ),
        WorldPlace(
            id: "shinjuku-gyoen",
            name: "新宿御苑",
            city: .tokyo,
            district: "新宿区",
            latitude: 35.6852,
            longitude: 139.7101,
            role: .park,
            description: "城市中央大型庭园，可作为休息、摄影和季节事件场景。",
            dailyActivities: ["庭园散步", "拍季节照片", "恢复能量"]
        ),
        WorldPlace(
            id: "harajuku",
            name: "原宿竹下通",
            city: .tokyo,
            district: "涩谷区",
            latitude: 35.6717,
            longitude: 139.7020,
            role: .lifestyle,
            description: "潮流街区，适合个性服装、头像装扮和街拍素材。",
            dailyActivities: ["换装打卡", "街拍采集", "寻找甜品"]
        ),
        WorldPlace(
            id: "odaiba",
            name: "台场",
            city: .tokyo,
            district: "港区",
            latitude: 35.6267,
            longitude: 139.7730,
            role: .lifestyle,
            description: "临海娱乐区，适合港湾、摩天轮、夜景和海风任务。",
            dailyActivities: ["看海散步", "拍摄彩虹桥", "参加夜间活动"]
        ),
        WorldPlace(
            id: "meiji-jingu",
            name: "明治神宫",
            city: .tokyo,
            district: "涩谷区",
            latitude: 35.6764,
            longitude: 139.6993,
            role: .park,
            description: "森林神社区域，适合安静探索、仪式任务和自然音效素材。",
            dailyActivities: ["森林漫步", "收集木纹", "完成祈愿"]
        )
    ]

    static let hongKong: [WorldPlace] = [
        WorldPlace(
            id: "central-hk",
            name: "中环",
            city: .hongKong,
            district: "中西区",
            latitude: 22.2819,
            longitude: 114.1589,
            role: .neighborhood,
            description: "香港世界的城市核心，高楼、天桥、坡道和电车构成高密度生活场景。",
            dailyActivities: ["穿过天桥", "采集高楼纹理", "寻找茶餐厅"]
        ),
        WorldPlace(
            id: "victoria-harbour",
            name: "维多利亚港",
            city: .hongKong,
            district: "港岛/九龙",
            latitude: 22.2930,
            longitude: 114.1694,
            role: .landmark,
            description: "海港与天际线交汇，是香港数字世界的主视觉锚点和夜景任务区。",
            dailyActivities: ["沿海散步", "拍摄天际线", "同步夜景"]
        ),
        WorldPlace(
            id: "victoria-peak",
            name: "太平山顶",
            city: .hongKong,
            district: "中西区",
            latitude: 22.2759,
            longitude: 114.1455,
            role: .landmark,
            description: "俯瞰港岛和维港的高点，可作为香港地图解锁和视野同步节点。",
            dailyActivities: ["登山看城", "解锁视野", "收集云层"]
        ),
        WorldPlace(
            id: "tsim-sha-tsui",
            name: "尖沙咀",
            city: .hongKong,
            district: "油尖旺区",
            latitude: 22.2976,
            longitude: 114.1722,
            role: .lifestyle,
            description: "购物、博物馆、海滨和游客路线密集，适合街拍和跨海任务。",
            dailyActivities: ["逛海滨", "拍霓虹招牌", "查看展览"]
        ),
        WorldPlace(
            id: "mong-kok",
            name: "旺角",
            city: .hongKong,
            district: "油尖旺区",
            latitude: 22.3193,
            longitude: 114.1694,
            role: .lifestyle,
            description: "高密度街市与霓虹招牌区域，适合夜间生活、店铺互动和素材采集。",
            dailyActivities: ["逛街市", "拍招牌", "寻找小吃"]
        ),
        WorldPlace(
            id: "causeway-bay",
            name: "铜锣湾",
            city: .hongKong,
            district: "湾仔区",
            latitude: 22.2800,
            longitude: 114.1850,
            role: .lifestyle,
            description: "商业、购物和街头人流集中，适合数字人的消费、社交和街拍任务。",
            dailyActivities: ["逛商场", "参加街头活动", "收集橱窗灵感"]
        ),
        WorldPlace(
            id: "wan-chai",
            name: "湾仔",
            city: .hongKong,
            district: "湾仔区",
            latitude: 22.2762,
            longitude: 114.1751,
            role: .neighborhood,
            description: "新旧建筑混合的港岛街区，适合老街、市场和会议展览玩法。",
            dailyActivities: ["穿梭老街", "采集街市声音", "查看会展任务"]
        ),
        WorldPlace(
            id: "hk-airport",
            name: "香港国际机场",
            city: .hongKong,
            district: "离岛区",
            latitude: 22.3080,
            longitude: 113.9185,
            role: .transport,
            description: "跨城旅行入口，可承担上海、东京、香港之间的航线与传送功能。",
            dailyActivities: ["办理登机", "接取跨城委托", "整理旅行素材"]
        ),
        WorldPlace(
            id: "hong-kong-station",
            name: "香港站",
            city: .hongKong,
            district: "中西区",
            latitude: 22.2849,
            longitude: 114.1583,
            role: .transport,
            description: "机场快线与中环交通枢纽，可作为港岛快速移动和任务汇合点。",
            dailyActivities: ["换乘港铁", "领取任务", "查看路线"]
        ),
        WorldPlace(
            id: "lantau-island",
            name: "大屿山",
            city: .hongKong,
            district: "离岛区",
            latitude: 22.2550,
            longitude: 113.9410,
            role: .park,
            description: "山海、缆车和离岛自然场景，适合扩展徒步、海风和郊野玩法。",
            dailyActivities: ["乘坐缆车", "山径散步", "收集海风"]
        ),
        WorldPlace(
            id: "west-kowloon",
            name: "西九文化区",
            city: .hongKong,
            district: "油尖旺区",
            latitude: 22.3027,
            longitude: 114.1600,
            role: .park,
            description: "海滨草地与文化设施结合，适合展览、音乐和休息恢复事件。",
            dailyActivities: ["看海休息", "参加展览", "收集艺术灵感"]
        ),
        WorldPlace(
            id: "sha-tin",
            name: "沙田",
            city: .hongKong,
            district: "沙田区",
            latitude: 22.3820,
            longitude: 114.1880,
            role: .neighborhood,
            description: "新市镇、河道和住宅生活圈，适合日常模拟、骑行和社区任务。",
            dailyActivities: ["沿河骑行", "拜访社区", "整理生活素材"]
        )
    ]
}
