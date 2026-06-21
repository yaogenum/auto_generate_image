import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class WorldModel {
    var profile: DigitalProfile
    var places: [WorldPlace]
    var contributions: [MediaContribution]
    var familyMembers: [FamilyMember]
    var selectedFamilyMemberID: String
    var conversations: [String: [FamilyMessage]]
    var moments: [FamilyMoment]
    var selectedPlaceID: String
    var avatarEnergy: Double
    var worldScaleMeters: Double
    var selfProxyMode: SelfProxyMode
    var contactEndpoints: [String: ContactConversationEndpoint]
    var pendingAgentIssues: [AgentIssue]
    var lastHumanTakeoverAt: Date
    var isFamilyChatExpanded: Bool = false
    var isWorldPanelExpanded: Bool = false
    var worldPanelSection: WorldPanelSection = .explore
    var isWorldUIHidden: Bool = false
    private var emittedSceneHintKeys: Set<String> = []

    private let profileKey = "CartoonWorld.profile.v1"
    private let contributionKey = "CartoonWorld.contributions.v1"
    private let familyMembersKey = "CartoonWorld.familyMembers.v1"
    private let selectedFamilyMemberKey = "CartoonWorld.selectedFamilyMemberID.v1"
    private let didInitFamilySelectionKey = "CartoonWorld.didInitFamilySelection.v1"
    private let conversationsKey = "CartoonWorld.familyConversations.v1"
    private let momentsKey = "CartoonWorld.familyMoments.v1"
    private let seededAssetManifestKey = "CartoonWorld.mediaSeedManifest.v2"
    private let seededNarrativeKey = "CartoonWorld.seededNarratives.v1"
    private let selfProxyModeKey = "CartoonWorld.selfProxyMode.v1"
    private let contactEndpointsKey = "CartoonWorld.contactEndpoints.v1"
    private let pendingAgentIssuesKey = "CartoonWorld.pendingAgentIssues.v1"
    private let lastHumanTakeoverKey = "CartoonWorld.lastHumanTakeoverAt.v1"

    init(
        profile: DigitalProfile? = nil,
        places: [WorldPlace] = WorldSeed.places,
        contributions: [MediaContribution]? = nil
    ) {
        self.profile = profile ?? Self.loadProfile() ?? .randomDefault()
        self.places = places
        self.contributions = contributions ?? Self.loadContributions()
        self.familyMembers = Self.loadFamilyMembers() ?? [FamilyMember.selfProfile(from: profile ?? .randomDefault())]
        self.selectedFamilyMemberID = Self.loadSelectedFamilyMemberID()
        self.conversations = Self.loadConversations()
        self.moments = Self.loadMoments()
        self.selectedPlaceID = places.first?.id ?? "the-bund"
        self.avatarEnergy = 0.72
        self.worldScaleMeters = 6_340_000
        self.selfProxyMode = Self.loadSelfProxyMode()
        self.contactEndpoints = Self.loadContactEndpoints()
        self.pendingAgentIssues = Self.loadPendingAgentIssues()
        self.lastHumanTakeoverAt = Self.loadLastHumanTakeoverAt()

        ensureSelfFamilyMember()
        bootstrapNarrativeDemoIfNeeded()
        defer {
            ensureScenePromptsIfNeeded(for: selectedFamilyMemberID)
        }

        bootstrapSeedContributionsIfNeeded()
    }

    var selectedFamilyMember: FamilyMember {
        if familyMembers.isEmpty {
            return FamilyMember.selfProfile(from: profile)
        }
        return familyMembers.first { $0.id == selectedFamilyMemberID }
            ?? familyMembers.first(where: { $0.isSelf })
            ?? familyMembers[0]
    }

    var messagesForSelectedMember: [FamilyMessage] {
        conversations[selectedFamilyMemberID] ?? []
    }

    var momentsForSelectedMember: [FamilyMoment] {
        moments.filter { $0.memberID == selectedFamilyMemberID }
            .sorted { $0.date > $1.date }
    }

    var allMoments: [FamilyMoment] {
        moments.sorted { $0.date > $1.date }
    }

    var networkRelationEdges: [FamilyRelationEdge] {
        guard let selfMember = familyMembers.first(where: { $0.isSelf }) else { return [] }
        return familyMembers
            .filter { !$0.isSelf }
            .map { member in
                FamilyRelationEdge(
                    id: "\(selfMember.id)->\(member.id)",
                    sourceMemberID: selfMember.id,
                    targetMemberID: member.id,
                    relationLabel: relationLabel(fromSelfTo: member)
                )
            }
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
        model.familyMembers = [
            FamilyMember.selfProfile(from: model.profile),
            FamilyMember(
                id: UUID().uuidString,
                name: "妈妈",
                relationship: "妈妈",
                phoneNumber: "13800000001",
                birthday: Calendar.current.date(from: DateComponents(year: 1980, month: 8, day: 18)),
                cadenceDay: 2,
                cadenceTime: "20:00",
                isSelf: false,
                avatarSeed: 4
            ),
            FamilyMember(
                id: UUID().uuidString,
                name: "弟弟",
                relationship: "弟弟",
                phoneNumber: "13800000002",
                birthday: Calendar.current.date(from: DateComponents(year: 2015, month: 3, day: 2)),
                cadenceDay: 5,
                cadenceTime: "21:00",
                isSelf: false,
                avatarSeed: 6
            )
        ]
        model.selfProxyMode = .issueReview
        model.contactEndpoints = [
            model.familyMembers[1].id: .localAgent,
            model.familyMembers[2].id: .remoteAgent
        ]
        model.selectedFamilyMemberID = model.familyMembers.first?.id ?? "self"
        model.pendingAgentIssues = [
            AgentIssue(
                id: UUID(),
                memberID: model.familyMembers[1].id,
                prompt: "妈妈问这周末能不能一起视频聊东京和大阪的旅行计划？",
                suggestedReply: "可以，周六晚上我让数字分身先同步路线，正式时间我们再一起确认。",
                createdAt: .now,
                status: .open
            )
        ]
        model.saveFamilyData()
        model.saveAgentRoutingData()
        return model
    }

    var effectiveSelfProxyMode: SelfProxyMode {
        if isSelfProxyFullyDelegated {
            return .autopilot
        }
        return selfProxyMode
    }

    var isSelfProxyFullyDelegated: Bool {
        Date().timeIntervalSince(lastHumanTakeoverAt) > 60 * 60 * 72
    }

    var openAgentIssues: [AgentIssue] {
        pendingAgentIssues
            .filter { $0.status == .open }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var openAgentIssueCount: Int {
        openAgentIssues.count
    }

    func bootstrapIfNeeded() {
        setDefaultSelfIfNeededOnFirstRun()
        saveProfile()
        saveFamilyData()
        saveAgentRoutingData()
        refreshFamilyScenePrompts()
    }

    private func setDefaultSelfIfNeededOnFirstRun() {
        guard !UserDefaults.standard.bool(forKey: didInitFamilySelectionKey) else { return }
        if let selfID = familyMembers.first(where: { $0.isSelf })?.id {
            selectedFamilyMemberID = selfID
            UserDefaults.standard.set(selfID, forKey: selectedFamilyMemberKey)
        } else if let first = familyMembers.first?.id {
            selectedFamilyMemberID = first
            UserDefaults.standard.set(first, forKey: selectedFamilyMemberKey)
        }
        UserDefaults.standard.set(true, forKey: didInitFamilySelectionKey)
    }

    func selectFamilyMember(id: String) {
        selectedFamilyMemberID = id
        UserDefaults.standard.set(id, forKey: selectedFamilyMemberKey)
    }

    func setSelfProxyMode(_ mode: SelfProxyMode, touchedByHuman: Bool = true) {
        selfProxyMode = mode
        if touchedByHuman {
            touchHumanPresence()
        } else {
            saveAgentRoutingData()
        }
    }

    func touchHumanPresence(at date: Date = .now) {
        lastHumanTakeoverAt = date
        saveAgentRoutingData()
    }

    func simulateLongAbsenceForDemo() {
        lastHumanTakeoverAt = .now.addingTimeInterval(-(60 * 60 * 24 * 5))
        saveAgentRoutingData()
    }

    func contactEndpoint(for memberID: String) -> ContactConversationEndpoint {
        if let explicit = contactEndpoints[memberID] {
            return explicit
        }
        if memberID == "self" {
            return .localAgent
        }
        return .localAgent
    }

    func setContactEndpoint(for memberID: String, to endpoint: ContactConversationEndpoint) {
        contactEndpoints[memberID] = endpoint
        saveAgentRoutingData()
    }

    func issues(for memberID: String? = nil) -> [AgentIssue] {
        let filtered = pendingAgentIssues.filter { issue in
            if let memberID {
                return issue.memberID == memberID
            }
            return true
        }
        return filtered.sorted { $0.createdAt > $1.createdAt }
    }

    func openIssueCount(for memberID: String) -> Int {
        issues(for: memberID).filter { $0.status == .open }.count
    }

    func register(displayName: String, identity: String, homeDistrict: String, motto: String) {
        profile.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.identity = identity.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.homeDistrict = homeDistrict.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.motto = motto.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.isRegistered = true
        syncSelfFamilyMember()
        saveProfile()
        saveFamilyData()
        touchHumanPresence()
    }

    func randomizeGuestIdentity() {
        profile = .randomDefault()
        syncSelfFamilyMember()
        saveProfile()
        saveFamilyData()
        touchHumanPresence()
    }

    func upsertFamilyMember(_ member: FamilyMember) {
        if let index = familyMembers.firstIndex(where: { $0.id == member.id }) {
            familyMembers[index] = member
        } else {
            familyMembers.append(member)
        }
        conversations[member.id] = conversations[member.id] ?? []
        ensureSelfFamilyMember()
        if selectedFamilyMemberID.isEmpty {
            selectedFamilyMemberID = member.id
        }
        saveFamilyData()
        saveAgentRoutingData()
    }

    func deleteFamilyMember(_ memberID: String) {
        guard !memberID.isEmpty else { return }
        let isSelf = familyMembers.first(where: { $0.id == memberID })?.isSelf == true
        guard !isSelf else { return }

        familyMembers.removeAll { $0.id == memberID }
        conversations[memberID] = nil
        moments.removeAll { $0.memberID == memberID }
        contactEndpoints.removeValue(forKey: memberID)
        pendingAgentIssues.removeAll { $0.memberID == memberID }
        if selectedFamilyMemberID == memberID {
            selectedFamilyMemberID = familyMembers.first { $0.isSelf }?.id ?? (familyMembers.first?.id ?? "self")
            UserDefaults.standard.set(selectedFamilyMemberID, forKey: selectedFamilyMemberKey)
        }
        saveFamilyData()
        saveAgentRoutingData()
    }

    func sendMessage(to memberID: String, text: String, isFromSelf: Bool = true) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        let message = FamilyMessage(
            id: UUID(),
            memberID: memberID,
            isFromSelf: isFromSelf,
            text: normalized,
            createdAt: .now
        )
        conversations[memberID, default: []].insert(message, at: 0)
        conversations[memberID]?.sort { $0.createdAt > $1.createdAt }
        saveFamilyData()

        if isFromSelf, memberID == "self" {
            handleDirectiveToSelf(normalized)
            return
        }

        if isFromSelf, let member = familyMembers.first(where: { $0.id == memberID }) {
            scheduleAutoReply(for: member, context: normalized)
        }
    }

    func simulateCommunication(to memberID: String, isVideo: Bool) {
        guard let member = familyMembers.first(where: { $0.id == memberID }), !member.isSelf else {
            appendSystemMessage(memberID, text: "不能对自己发起通话，先选择其他家庭成员。")
            return
        }

        let mode = isVideo ? "视频" : "语音"
        if member.phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appendSystemMessage(member.id, text: "\(member.name) 未设置联系方式，先在家人管理补充电话或 FaceTime 账号。")
            return
        }

        appendSystemMessage(member.id, text: "已发起演示\(mode)沟通（当前为模拟操作）。")
    }

    func selectFirstExternalFamilyMember() -> String? {
        if let selfID = familyMembers.first(where: { $0.isSelf })?.id,
           familyMembers.count == 1 {
            return selfID
        }

        return familyMembers.first(where: { !$0.isSelf })?.id
            ?? familyMembers.first?.id
    }

    func simulateIncomingMessage(from memberID: String) {
        guard let member = familyMembers.first(where: { $0.id == memberID }), !member.isSelf else { return }

        let inbound = suggestedInboundPrompt(for: member)
        let incoming = FamilyMessage(
            id: UUID(),
            memberID: memberID,
            isFromSelf: false,
            text: inbound,
            createdAt: .now
        )
        conversations[memberID, default: []].insert(incoming, at: 0)
        conversations[memberID]?.sort { $0.createdAt > $1.createdAt }
        saveFamilyData()

        switch effectiveSelfProxyMode {
        case .autopilot:
            let reply = suggestedReply(to: inbound, for: member)
            conversations[memberID, default: []].insert(
                FamilyMessage(
                    id: UUID(),
                    memberID: memberID,
                    isFromSelf: true,
                    text: reply,
                    createdAt: .now.addingTimeInterval(60)
                ),
                at: 0
            )
            saveFamilyData()
        case .human:
            appendSystemMessage(memberID, text: "当前由本人接管，数字分身先记录了这条消息，等待你亲自回复。")
        case .issueReview:
            createIssue(for: memberID, prompt: inbound, suggestedReply: suggestedReply(to: inbound, for: member))
            appendSystemMessage(memberID, text: "数字分身已将这条来信列为待确认 issue，等你确认后再代为回复。")
        }
    }

    func approveIssue(_ issueID: UUID) {
        guard let issueIndex = pendingAgentIssues.firstIndex(where: { $0.id == issueID }) else { return }
        let issue = pendingAgentIssues[issueIndex]
        pendingAgentIssues[issueIndex].status = .approved
        touchHumanPresence()
        conversations[issue.memberID, default: []].insert(
            FamilyMessage(
                id: UUID(),
                memberID: issue.memberID,
                isFromSelf: true,
                text: issue.suggestedReply,
                createdAt: .now
            ),
            at: 0
        )
        conversations[issue.memberID]?.sort { $0.createdAt > $1.createdAt }
        saveFamilyData()
        saveAgentRoutingData()
    }

    func deferIssueToHuman(_ issueID: UUID) {
        guard let issueIndex = pendingAgentIssues.firstIndex(where: { $0.id == issueID }) else { return }
        pendingAgentIssues[issueIndex].status = .deferred
        setSelfProxyMode(.human)
    }

    func dismissIssue(_ issueID: UUID) {
        guard let issueIndex = pendingAgentIssues.firstIndex(where: { $0.id == issueID }) else { return }
        pendingAgentIssues[issueIndex].status = .dismissed
        saveAgentRoutingData()
    }

    func appendSystemMessage(_ memberID: String, text: String) {
        let message = FamilyMessage(
            id: UUID(),
            memberID: memberID,
            isFromSelf: false,
            text: text,
            createdAt: .now
        )
        conversations[memberID, default: []].insert(message, at: 0)
        conversations[memberID]?.sort { $0.createdAt > $1.createdAt }
        saveFamilyData()
    }

    func ensureScenePromptsIfNeeded(for memberID: String, at date: Date = .now) {
        guard let member = familyMembers.first(where: { $0.id == memberID }) else { return }

        if member.isBirthdayToday(on: date) {
            upsertSceneHint(
                type: "birthday",
                memberID: memberID,
                date: date,
                text: "📅 今天是 \(member.name) 的生日，发张新照合影是个不错的互动方式。"
            )
        }

        if member.isWeeklyChatDue(on: date) {
            upsertSceneHint(
                type: "weekly",
                memberID: memberID,
                date: date,
                text: "🔔 今天是与 \(member.name) 的固定交流日，打开语音/视频通话更有仪式感。"
            )
        }
    }

    func addDefaultMomentsIfNeeded(for memberID: String) {
        let tip = "点开聊天，发送第一条消息即可开启家庭关系。"
        if conversations[memberID, default: []].contains(where: { $0.text == tip }) {
            return
        }

        appendSystemMessage(memberID, text: tip)
    }

    func refreshFamilyScenePrompts() {
        familyMembers.forEach { ensureScenePromptsIfNeeded(for: $0.id) }
    }

    func addFamilyMoment(title: String, note: String, memberID: String, place: WorldPlace) {
        let moment = FamilyMoment(
            id: UUID(),
            memberID: memberID,
            placeID: place.id,
            title: title,
            note: note,
            date: .now,
            city: place.city.rawValue,
            placeName: place.name
        )
        moments.insert(moment, at: 0)
        saveFamilyData()
    }

    func moments(for city: WorldCity) -> [FamilyMoment] {
        moments.filter { moment in
            if let placeID = moment.placeID, !placeID.isEmpty {
                return places.first(where: { $0.id == placeID })?.city == city
            }
            return moment.city == city.rawValue
        }
        .sorted { $0.date > $1.date }
    }

    func moments(for place: WorldPlace) -> [FamilyMoment] {
        moments.filter { moment in
            moment.placeID == place.id ||
            (moment.placeID == nil && moment.city == place.city.rawValue && moment.placeName == place.name)
        }
        .sorted { $0.date > $1.date }
    }

    func resolvedPlaceID(for moment: FamilyMoment) -> String? {
        if let placeID = moment.placeID, !placeID.isEmpty {
            return placeID
        }
        return places.first(where: { $0.name == moment.placeName && $0.city.rawValue == moment.city })?.id
    }

    func momentCount(for placeID: String, in city: WorldCity? = nil) -> Int {
        let scope = moments.filter { moment in
            guard let resolvedPlaceID = resolvedPlaceID(for: moment) else { return false }
            if let city {
                return places.contains(where: { $0.id == resolvedPlaceID && $0.city == city }) && resolvedPlaceID == placeID
            }
            return resolvedPlaceID == placeID
        }
        return scope.count
    }

    func momentsByPlaceCount(for city: WorldCity) -> [String: Int] {
        Dictionary(
            grouping: moments(for: city),
            by: { resolvedPlaceID(for: $0) ?? $0.placeName }
        ).mapValues { $0.count }
    }

    func familyMemberName(for memberID: String) -> String {
        familyMembers.first(where: { $0.id == memberID })?.name ?? "家人"
    }

    func relationLabel(fromSelfTo member: FamilyMember) -> String {
        if member.isSelf { return "自己" }
        let label = member.relationship.trimmingCharacters(in: .whitespacesAndNewlines)
        if label.isEmpty { return "家人" }
        if label.hasPrefix("我的") { return label }
        if label == "自己" { return "自己" }
        return "我的\(label)"
    }

    func momentsForSelectedCity(for city: WorldCity) -> [FamilyMoment] {
        moments(for: city)
    }

    func momentsForSelectedPlace() -> [FamilyMoment] {
        moments(for: selectedPlace)
    }

    func setRelationship(for memberID: String, to relationship: String) {
        guard let index = familyMembers.firstIndex(where: { $0.id == memberID }) else { return }
        familyMembers[index].relationship = relationship.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "家人"
            : relationship
        saveFamilyData()
    }

    func moveAvatar(to placeID: String) {
        selectedPlaceID = placeID
        avatarEnergy = min(1.0, avatarEnergy + 0.06)
    }

    func performDailyAction(_ action: String) {
        let energyDelta = action.contains("休息") || action.contains("咖啡") ? 0.12 : -0.07
        avatarEnergy = min(1.0, max(0.1, avatarEnergy + energyDelta))
    }

    func addContribution(
        placeID: String,
        title: String,
        mediaKind: MediaKind,
        rawData: Data?,
        mediaURL: String? = nil,
        summary: String? = nil,
        initialStatus: CartoonizationStatus = .queued
    ) {
        let normalizedTitle = title.isEmpty ? "新的真实世界素材" : title
        let thumbnail = Self.makeThumbnailData(from: rawData)
        let contribution = MediaContribution(
            id: UUID(),
            placeID: placeID,
            title: normalizedTitle,
            mediaKind: mediaKind,
            mediaURL: mediaURL,
            summary: summary,
            status: initialStatus,
            createdAt: .now,
            palette: Self.cartoonPalette(from: rawData),
            thumbnailData: thumbnail
        )

        guard !contributions.contains(where: { existing in
            existing.placeID == contribution.placeID
                && existing.title == contribution.title
                && existing.mediaKind == contribution.mediaKind
                && (existing.mediaURL ?? existing.title) == (contribution.mediaURL ?? contribution.title)
        }) else {
            return
        }

        contributions.insert(contribution, at: 0)
        saveContributions()

        if initialStatus == .queued {
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(650))
                self?.advanceContribution(contribution.id, to: .stylizing)
                try? await Task.sleep(for: .milliseconds(900))
                self?.advanceContribution(contribution.id, to: .integrated)
            }
        }
    }

    func contributionImageData(for contribution: MediaContribution) -> Data? {
        guard let mediaURL = contribution.mediaURL, !mediaURL.isEmpty else {
            return nil
        }

        if let directURL = URL(string: mediaURL), directURL.scheme?.isEmpty == false {
            if directURL.isFileURL {
                return try? Data(contentsOf: directURL)
            }
            return nil
        }

        let trimmedPath = mediaURL
            .replacingOccurrences(of: "./", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let data = Self.dataForResourcePath(trimmedPath) {
            return data
        }

        return nil
    }

    private func bootstrapSeedContributionsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: seededAssetManifestKey) else { return }

        let seedItems = Self.loadSeedContributionItems()
        guard !seedItems.isEmpty else {
            return
        }

        var seeded = 0
        for item in seedItems {
            guard item.detectedCity != nil,
                  let placeID = item.detectedPlaceID(among: places) else {
                continue
            }

            let mediaKind = item.detectedMediaKind
            let title = item.preferredTitle
            let summary = item.preferredSummary
            let mediaURL = item.normalizedMediaURL

            addContribution(
                placeID: placeID,
                title: title,
                mediaKind: mediaKind,
                rawData: nil,
                mediaURL: mediaURL,
                summary: summary,
                initialStatus: .integrated
            )

            seeded += 1
        }

        if seeded > 0 {
            UserDefaults.standard.set(true, forKey: seededAssetManifestKey)
            saveContributions()
        }
    }

    private func bootstrapNarrativeDemoIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: seededNarrativeKey) else { return }

        if familyMembers.filter({ !$0.isSelf }).isEmpty {
            familyMembers.append(
                FamilyMember(
                    id: "seed-mom",
                    name: "妈妈",
                    relationship: "妈妈",
                    phoneNumber: "13800000001",
                    birthday: Calendar.current.date(from: DateComponents(year: 1984, month: 7, day: 12)),
                    cadenceDay: 6,
                    cadenceTime: "20:30",
                    isSelf: false,
                    avatarSeed: 4
                )
            )
            familyMembers.append(
                FamilyMember(
                    id: "seed-sister",
                    name: "姐姐",
                    relationship: "姐姐",
                    phoneNumber: "13800000002",
                    birthday: Calendar.current.date(from: DateComponents(year: 1992, month: 10, day: 8)),
                    cadenceDay: 3,
                    cadenceTime: "21:00",
                    isSelf: false,
                    avatarSeed: 1
                )
            )
        }

        if contactEndpoints["seed-mom"] == nil {
            contactEndpoints["seed-mom"] = .localAgent
        }
        if contactEndpoints["seed-sister"] == nil {
            contactEndpoints["seed-sister"] = .remoteAgent
        }

        let storySeeds: [PlaceStorySeed] = [
            PlaceStorySeed(placeID: "the-bund", memberID: "seed-mom", title: "外滩夜景合照", note: "陪妈妈沿江散步，顺手把黄浦江夜景做成了第一条地图记忆。", chatLead: "今晚外滩风有点大，你那张夜景照发我，我想存进家庭相册。"),
            PlaceStorySeed(placeID: "tokyo-tower", memberID: "seed-sister", title: "东京塔报平安", note: "和姐姐约定每到一个新城市都拍一张地标打卡照。", chatLead: "东京塔这张很适合放进 Moments，顺便把夜景路线也记一下。"),
            PlaceStorySeed(placeID: "osaka-castle", memberID: "seed-mom", title: "大阪城晨跑", note: "清晨绕着护城河慢跑，给妈妈发了实时照片和位置。", chatLead: "大阪城这一站看起来很舒服，记得把路线和早餐店也一并记上。"),
            PlaceStorySeed(placeID: "nagoya-castle", memberID: "seed-sister", title: "名古屋城庭院散步", note: "和家人约了周末视频，先把名古屋城边的绿地保存成旅行时刻。", chatLead: "名古屋这一段适合做成慢节奏 Moments，我想看你拍到的城墙细节。"),
            PlaceStorySeed(placeID: "victoria-harbour", memberID: "seed-mom", title: "维港晚风", note: "跟家人同步了维港夜色，也把聊天里的旅行计划挂到了地标下。", chatLead: "维港这条就留给全家周末看吧，晚上视频的时候一起回顾。")
        ]

        for seed in storySeeds {
            guard let place = places.first(where: { $0.id == seed.placeID }) else { continue }
            guard familyMembers.contains(where: { $0.id == seed.memberID }) else { continue }

            if !moments.contains(where: { $0.title == seed.title && resolvedPlaceID(for: $0) == seed.placeID }) {
                moments.insert(
                    FamilyMoment(
                        id: UUID(),
                        memberID: seed.memberID,
                        placeID: place.id,
                        title: seed.title,
                        note: seed.note,
                        date: .now.addingTimeInterval(seed.timeOffset),
                        city: place.city.rawValue,
                        placeName: place.name
                    ),
                    at: 0
                )
            }

            if !(conversations[seed.memberID] ?? []).contains(where: { $0.text == seed.chatLead }) {
                conversations[seed.memberID, default: []].insert(
                    FamilyMessage(
                        id: UUID(),
                        memberID: seed.memberID,
                        isFromSelf: false,
                        text: seed.chatLead,
                        createdAt: .now.addingTimeInterval(seed.timeOffset + 600)
                    ),
                    at: 0
                )
            }
        }

        UserDefaults.standard.set(true, forKey: seededNarrativeKey)
        saveFamilyData()
        saveAgentRoutingData()
    }

    private func contributionImageData(for mediaURL: String?, city: WorldCity) -> Data? {
        guard let mediaURL, !mediaURL.isEmpty else { return nil }

        if let url = URL(string: mediaURL), url.scheme?.isEmpty == false, !url.isFileURL {
            return nil
        }

        let trimmedPath = mediaURL
            .replacingOccurrences(of: "./", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let candidates: [String] = [
            trimmedPath,
            "images/source/\(trimmedPath)",
            "images/\(trimmedPath)",
            "source/\(trimmedPath)",
            "\(city.rawValue)/\(trimmedPath)"
        ]

        for path in candidates where !path.isEmpty {
            if let data = Self.dataForResourcePath(path) {
                return data
            }
        }

        if let url = Bundle.main.url(forResource: trimmedPath, withExtension: nil),
           let data = try? Data(contentsOf: url) {
            return data
        }

        return nil
    }

    private func advanceContribution(_ id: UUID, to status: CartoonizationStatus) {
        guard let index = contributions.firstIndex(where: { $0.id == id }) else { return }
        contributions[index].status = status
        saveContributions()
    }

    private func ensureSelfFamilyMember() {
        if !familyMembers.contains(where: { $0.isSelf }) {
            familyMembers.insert(FamilyMember.selfProfile(from: profile), at: 0)
        }

        for i in familyMembers.indices where familyMembers[i].isSelf {
            familyMembers[i].syncDisplayName(profile.displayName, avatarSeed: profile.avatarSeed)
        }

        if !familyMembers.contains(where: { $0.id == selectedFamilyMemberID }) {
            selectedFamilyMemberID = familyMembers.first(where: { $0.isSelf })?.id ?? "self"
            UserDefaults.standard.set(selectedFamilyMemberID, forKey: selectedFamilyMemberKey)
        }
        if familyMembers.isEmpty {
            familyMembers = [FamilyMember.selfProfile(from: profile)]
        }
    }

    private func upsertSceneHint(type: String, memberID: String, date: Date, text: String) {
        let key = sceneHintKey(type: type, memberID: memberID, date: date)
        if emittedSceneHintKeys.contains(key) {
            return
        }
        if conversations[memberID, default: []].contains(where: { $0.text == text }) {
            emittedSceneHintKeys.insert(key)
            return
        }
        appendSystemMessage(memberID, text: text)
        emittedSceneHintKeys.insert(key)
    }

    private func sceneHintKey(type: String, memberID: String, date: Date) -> String {
        let dayStart = Calendar.current.startOfDay(for: date)
        return "\(type)::\(memberID)::\(dayStart.timeIntervalSince1970)"
    }

    private func scheduleAutoReply(for member: FamilyMember, context: String) {
        let endpoint = contactEndpoint(for: member.id)
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(endpoint == .humanUser ? 250 : 900))
            await MainActor.run {
                guard let self else { return }
                switch endpoint {
                case .localAgent:
                    self.appendSystemMessage(member.id, text: "本机 Agent 代 \(member.name) 回复：\(self.syntheticAgentReply(for: member, context: context))")
                case .remoteAgent:
                    self.appendSystemMessage(member.id, text: "线上 Agent 代 \(member.name) 回复：\(self.syntheticRemoteAgentReply(for: member, context: context))")
                case .humanUser:
                    self.appendSystemMessage(member.id, text: "\(member.name) 当前由真人控制，数字分身只代收消息，等待对方上线后确认回复。")
                case .humanOffline:
                    self.createIssue(
                        for: member.id,
                        prompt: "\(member.name) 离线时收到你的消息：\(context)",
                        suggestedReply: self.syntheticRemoteAgentReply(for: member, context: context)
                    )
                    self.appendSystemMessage(member.id, text: "\(member.name) 当前未登录，数字分身已代收并生成待确认事项。")
                }
            }
        }
    }

    private func handleDirectiveToSelf(_ text: String) {
        switch effectiveSelfProxyMode {
        case .autopilot:
            appendSystemMessage("self", text: "数字分身已接管：收到你的指令“\(text)”，后续会先由我对外响应。")
        case .human:
            appendSystemMessage("self", text: "当前是本人处理模式。数字分身已记录你的指令“\(text)”，但不会自动代答。")
        case .issueReview:
            createIssue(for: "self", prompt: text, suggestedReply: "我会先整理这个问题，再把建议回复发给家人确认。")
            appendSystemMessage("self", text: "数字分身已把这条要求列为待确认 issue，等你确认后再对外执行。")
        }
    }

    private func createIssue(for memberID: String, prompt: String, suggestedReply: String) {
        let issue = AgentIssue(
            id: UUID(),
            memberID: memberID,
            prompt: prompt,
            suggestedReply: suggestedReply,
            createdAt: .now,
            status: .open
        )
        pendingAgentIssues.insert(issue, at: 0)
        saveAgentRoutingData()
    }

    private func suggestedInboundPrompt(for member: FamilyMember) -> String {
        let options = [
            "\(member.name) 想确认这周末要不要一起视频聊一下最近的旅行计划？",
            "\(member.name) 问你能不能把刚刚那条 Moments 也同步到家庭相册里？",
            "\(member.name) 想知道你这周是否方便安排一次固定聊天。"
        ]
        return options.randomElement() ?? "\(member.name) 发来了一条新消息。"
    }

    private func suggestedReply(to inbound: String, for member: FamilyMember) -> String {
        if inbound.contains("视频") {
            return "可以，我让数字分身先把时间和路线同步好，等你确认后我们再正式连线。"
        }
        if inbound.contains("家庭相册") || inbound.contains("Moments") {
            return "没问题，我会先把对应地标和 Moments 整理好，再同步到家庭相册。"
        }
        return "收到，我先让数字分身把这件事记下来，晚一点给你一个明确安排。"
    }

    private func syntheticAgentReply(for member: FamilyMember, context: String) -> String {
        if context.contains("Help") || context.contains("help") {
            return "我先替 \(member.name) 记下了这件事，稍后给你更完整的安排。"
        }
        if context.contains("东京") || context.contains("大阪") || context.contains("香港") || context.contains("名古屋") {
            return "这段旅行信息我先收到了，\(member.name) 的数字分身会把地标和 Moments 一起归档。"
        }
        return "收到，我先代表 \(member.name) 回应你，这条消息已经进入我们的家庭分身会话流。"
    }

    private func syntheticRemoteAgentReply(for member: FamilyMember, context: String) -> String {
        if context.contains("视频") || context.contains("语音") {
            return "我先替 \(member.name) 同步了通话意向，等他确认档期后会回推正式时间。"
        }
        return "\(member.name) 的线上分身已收到这条消息，先帮他把问题整理成待办并保持对话连续。"
    }

    private func syncSelfFamilyMember() {
        for i in familyMembers.indices where familyMembers[i].isSelf {
            familyMembers[i].syncDisplayName(profile.displayName, avatarSeed: profile.avatarSeed)
        }
    }

    private func saveProfile() {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: profileKey)
    }

    private func saveContributions() {
        guard let data = try? JSONEncoder().encode(contributions) else { return }
        UserDefaults.standard.set(data, forKey: contributionKey)
    }

    private func saveFamilyData() {
        guard let members = try? JSONEncoder().encode(familyMembers) else { return }
        UserDefaults.standard.set(members, forKey: familyMembersKey)

        guard let chatData = try? JSONEncoder().encode(conversations) else { return }
        UserDefaults.standard.set(chatData, forKey: conversationsKey)

        guard let momentData = try? JSONEncoder().encode(moments) else { return }
        UserDefaults.standard.set(momentData, forKey: momentsKey)
    }

    private func saveAgentRoutingData() {
        UserDefaults.standard.set(selfProxyMode.rawValue, forKey: selfProxyModeKey)
        UserDefaults.standard.set(lastHumanTakeoverAt.timeIntervalSince1970, forKey: lastHumanTakeoverKey)

        guard let endpoints = try? JSONEncoder().encode(contactEndpoints) else { return }
        UserDefaults.standard.set(endpoints, forKey: contactEndpointsKey)

        guard let issues = try? JSONEncoder().encode(pendingAgentIssues) else { return }
        UserDefaults.standard.set(issues, forKey: pendingAgentIssuesKey)
    }

    private static func loadProfile() -> DigitalProfile? {
        guard let data = UserDefaults.standard.data(forKey: "CartoonWorld.profile.v1") else { return nil }
        return try? JSONDecoder().decode(DigitalProfile.self, from: data)
    }

    private static func loadContributions() -> [MediaContribution] {
        guard let data = UserDefaults.standard.data(forKey: "CartoonWorld.contributions.v1") else { return [] }
        return (try? JSONDecoder().decode([MediaContribution].self, from: data)) ?? []
    }

    private static func loadFamilyMembers() -> [FamilyMember]? {
        guard let data = UserDefaults.standard.data(forKey: "CartoonWorld.familyMembers.v1") else { return nil }
        return (try? JSONDecoder().decode([FamilyMember].self, from: data))
    }

    private static func loadSelectedFamilyMemberID() -> String {
        UserDefaults.standard.string(forKey: "CartoonWorld.selectedFamilyMemberID.v1") ?? "self"
    }

    private static func loadConversations() -> [String: [FamilyMessage]] {
        guard let data = UserDefaults.standard.data(forKey: "CartoonWorld.familyConversations.v1") else { return [:] }
        return (try? JSONDecoder().decode([String: [FamilyMessage]].self, from: data)) ?? [:]
    }

    private static func loadMoments() -> [FamilyMoment] {
        guard let data = UserDefaults.standard.data(forKey: "CartoonWorld.familyMoments.v1") else { return [] }
        return (try? JSONDecoder().decode([FamilyMoment].self, from: data)) ?? []
    }

    private static func loadSelfProxyMode() -> SelfProxyMode {
        let rawValue = UserDefaults.standard.string(forKey: "CartoonWorld.selfProxyMode.v1") ?? SelfProxyMode.autopilot.rawValue
        return SelfProxyMode(rawValue: rawValue) ?? .autopilot
    }

    private static func loadContactEndpoints() -> [String: ContactConversationEndpoint] {
        guard let data = UserDefaults.standard.data(forKey: "CartoonWorld.contactEndpoints.v1") else { return [:] }
        return (try? JSONDecoder().decode([String: ContactConversationEndpoint].self, from: data)) ?? [:]
    }

    private static func loadPendingAgentIssues() -> [AgentIssue] {
        guard let data = UserDefaults.standard.data(forKey: "CartoonWorld.pendingAgentIssues.v1") else { return [] }
        return (try? JSONDecoder().decode([AgentIssue].self, from: data)) ?? []
    }

    private static func loadLastHumanTakeoverAt() -> Date {
        let value = UserDefaults.standard.double(forKey: "CartoonWorld.lastHumanTakeoverAt.v1")
        if value > 0 {
            return Date(timeIntervalSince1970: value)
        }
        return .now
    }

    private static func loadSeedContributionItems() -> [SeedContributionItem] {
        guard let data = dataForResourcePath("images/素材元数据.json")
                ?? dataForResourcePath("素材元数据.json") else {
            return []
        }

        return (try? JSONDecoder().decode(SeedContributionManifest.self, from: data).items) ?? []
    }

    private static func dataForResourcePath(_ path: String) -> Data? {
        let cleaned = path
            .replacingOccurrences(of: "./", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let candidates = [
            cleaned,
            "images/\(cleaned)",
            "images/source/\(cleaned)"
        ]

        for candidate in candidates {
            if let url = Bundle.main.resourceURL?.appendingPathComponent(candidate),
               FileManager.default.fileExists(atPath: url.path),
               let data = try? Data(contentsOf: url) {
                return data
            }
        }

        return nil
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

private struct PlaceStorySeed {
    let placeID: String
    let memberID: String
    let title: String
    let note: String
    let chatLead: String
    let timeOffset: TimeInterval

    init(placeID: String, memberID: String, title: String, note: String, chatLead: String, timeOffset: TimeInterval = 0) {
        self.placeID = placeID
        self.memberID = memberID
        self.title = title
        self.note = note
        self.chatLead = chatLead
        self.timeOffset = timeOffset
    }
}

private struct SeedContributionManifest: Decodable {
    let items: [SeedContributionItem]
}

private struct SeedContributionItem: Decodable {
    let imageName: String
    let scene: String
    let traits: String?
    let source: String?
    let imageURL: String?
    let localFile: String?

    enum CodingKeys: String, CodingKey {
        case imageName = "图片名称"
        case scene = "场景"
        case traits = "特点"
        case source = "来源"
        case imageURL = "图片URL"
        case localFile = "本地文件"
    }

    var combinedText: String {
        [imageName, scene, traits, source, imageURL, localFile]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
    }

    var preferredTitle: String {
        let trimmedScene = scene.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedScene.isEmpty {
            return trimmedScene.replacingOccurrences(of: "·", with: "· ")
        }
        return imageName
    }

    var preferredSummary: String {
        let focus = traits?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "城市地标素材"
        let origin = source?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "本地素材"
        return "\(focus) · \(origin)"
    }

    var normalizedMediaURL: String? {
        let candidate = (localFile?.isEmpty == false ? localFile : imageURL) ?? imageURL
        return candidate?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var detectedMediaKind: MediaKind {
        let lowercasedName = imageName.lowercased()
        if lowercasedName.hasSuffix(".mp4") || lowercasedName.hasSuffix(".mov") {
            return .video
        }
        return .image
    }

    var detectedCity: WorldCity? {
        if scene.contains("上海") || combinedText.contains("shanghai") {
            return .shanghai
        }
        if scene.contains("东京") || combinedText.contains("tokyo") {
            return .tokyo
        }
        if scene.contains("大阪") || combinedText.contains("osaka") {
            return .osaka
        }
        if scene.contains("名古屋") || combinedText.contains("nagoya") {
            return .nagoya
        }
        if scene.contains("香港") || combinedText.contains("hongkong") || combinedText.contains("hong kong") {
            return .hongKong
        }
        return nil
    }

    func detectedPlaceID(among places: [WorldPlace]) -> String? {
        guard let city = detectedCity else { return nil }
        let scopedPlaces = places.filter { $0.city == city }
        let text = combinedText

        let keywordMap: [(String, [String])] = [
            ("tokyo-tower", ["tokyo tower", "东京铁塔", "东京塔"]),
            ("skytree", ["sky tree", "skytree", "晴空塔", "浅草"]),
            ("shibuya-crossing", ["shibuya", "涩谷"]),
            ("shinjuku-gyoen", ["shinjuku", "新宿"]),
            ("sensoji", ["sensoji", "asakusa", "浅草寺"]),
            ("ueno-park", ["ueno", "上野"]),
            ("akihabara", ["akihabara", "秋叶原"]),
            ("ginza", ["ginza", "银座"]),
            ("odaiba", ["odaiba", "台场", "rainbow bridge"]),
            ("meiji-jingu", ["meiji", "明治神宫", "harajuku", "原宿"]),
            ("osaka-castle", ["osaka castle", "大阪城", "castle"]),
            ("umeda-sky", ["umeda", "sky building", "梅田"]),
            ("dotonbori", ["dotonbori", "道顿堀", "namba", "难波"]),
            ("osaka-station-city", ["osaka station", "jr osaka", "station city"]),
            ("shinsekai", ["shinsekai", "新世界", "tsutenkaku", "通天阁"]),
            ("tennoji", ["tennoji", "天王寺", "abeno"]),
            ("usj", ["universal", "usj", "环球影城"]),
            ("nagoya-castle", ["nagoya castle", "名古屋城", "castle"]),
            ("nagoya-station", ["nagoya station", "jr nagoya", "名古屋站"]),
            ("sakae", ["sakae", "荣", "mirai tower", "tv tower", "oasis 21"]),
            ("osu", ["osu", "大须"]),
            ("atsuta-jingu", ["atsuta", "热田神宫"]),
            ("port-of-nagoya", ["port of nagoya", "港", "aquarium"]),
            ("victoria-harbour", ["victoria harbour", "维多利亚港", "harbour", "harbor"]),
            ("victoria-peak", ["victoria peak", "太平山顶", "peak"]),
            ("central-hk", ["central", "中环"]),
            ("tsim-sha-tsui", ["tsim sha tsui", "尖沙咀"]),
            ("mong-kok", ["mong kok", "旺角"]),
            ("causeway-bay", ["causeway bay", "铜锣湾"]),
            ("wan-chai", ["wan chai", "湾仔"]),
            ("west-kowloon", ["west kowloon", "西九"]),
            ("hk-airport", ["airport", "机场"])
        ]

        for (placeID, keywords) in keywordMap where scopedPlaces.contains(where: { $0.id == placeID }) {
            if keywords.contains(where: { text.contains($0.lowercased()) }) {
                return placeID
            }
        }

        let fallbackByCity: [WorldCity: String] = [
            .shanghai: "the-bund",
            .tokyo: "tokyo-station",
            .osaka: "osaka-castle",
            .nagoya: "nagoya-castle",
            .hongKong: "victoria-harbour"
        ]

        return fallbackByCity[city]
    }
}

enum WorldSeed {
    static let places: [WorldPlace] = shanghai + tokyo + osaka + nagoya + hongKong

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

    static let osaka: [WorldPlace] = [
        WorldPlace(
            id: "osaka-castle",
            name: "大阪城",
            city: .osaka,
            district: "中央区",
            latitude: 34.6873,
            longitude: 135.5259,
            role: .landmark,
            description: "大阪世界的主地标，护城河、石垣和天守阁会成为旅行 Moments 的核心舞台。",
            dailyActivities: ["沿护城河散步", "拍摄天守阁", "记录晨跑路线"]
        ),
        WorldPlace(
            id: "umeda-sky",
            name: "梅田空中庭园",
            city: .osaka,
            district: "北区",
            latitude: 34.7055,
            longitude: 135.4896,
            role: .landmark,
            description: "适合俯瞰大阪天际线，强化城市高空观景和晚间相册聚合。",
            dailyActivities: ["看城市夜景", "同步高空视角", "记录风景照片"]
        ),
        WorldPlace(
            id: "dotonbori",
            name: "道顿堀",
            city: .osaka,
            district: "中央区",
            latitude: 34.6687,
            longitude: 135.5013,
            role: .lifestyle,
            description: "霓虹、美食和河道构成高热度街区，适合家人互动与旅行日志展示。",
            dailyActivities: ["拍霓虹招牌", "找章鱼烧", "记录夜间聊天"]
        ),
        WorldPlace(
            id: "shinsaibashi",
            name: "心斋桥",
            city: .osaka,
            district: "中央区",
            latitude: 34.6737,
            longitude: 135.5019,
            role: .neighborhood,
            description: "购物街区与生活圈混合，适合放置轻量日常和家人礼物清单。",
            dailyActivities: ["逛商店街", "挑伴手礼", "更新旅行笔记"]
        ),
        WorldPlace(
            id: "osaka-station-city",
            name: "大阪站城",
            city: .osaka,
            district: "北区",
            latitude: 34.7025,
            longitude: 135.4959,
            role: .transport,
            description: "跨城与城市内部通勤节点，适合作为东京和名古屋之间的连接站。",
            dailyActivities: ["换乘列车", "整理行程", "同步出发时间"]
        ),
        WorldPlace(
            id: "shinsekai",
            name: "新世界",
            city: .osaka,
            district: "浪速区",
            latitude: 34.6525,
            longitude: 135.5063,
            role: .lifestyle,
            description: "通天阁和老街氛围适合做复古卡通街区与家人聊天案例。",
            dailyActivities: ["逛老街", "拍通天阁", "记录街边小吃"]
        ),
        WorldPlace(
            id: "tennoji",
            name: "天王寺",
            city: .osaka,
            district: "天王寺区",
            latitude: 34.6466,
            longitude: 135.5136,
            role: .park,
            description: "公园、动物园和高层塔楼共存，适合安排轻松散步和家庭聚会时刻。",
            dailyActivities: ["公园散步", "拍黄昏塔楼", "安排周末视频"]
        ),
        WorldPlace(
            id: "usj",
            name: "日本环球影城",
            city: .osaka,
            district: "此花区",
            latitude: 34.6654,
            longitude: 135.4323,
            role: .lifestyle,
            description: "高互动娱乐地标，可承接家庭出游和节庆 Moments。",
            dailyActivities: ["体验园区", "拍主题街景", "收集节庆纪念"]
        ),
        WorldPlace(
            id: "nakanoshima",
            name: "中之岛",
            city: .osaka,
            district: "北区",
            latitude: 34.6925,
            longitude: 135.4958,
            role: .park,
            description: "河岸办公与绿地区交织，适合放置更安静的城市生活记录。",
            dailyActivities: ["河岸慢走", "记录午后光线", "更新 Moments"]
        ),
        WorldPlace(
            id: "osaka-bay",
            name: "大阪港湾",
            city: .osaka,
            district: "港区",
            latitude: 34.6551,
            longitude: 135.4295,
            role: .transport,
            description: "作为城市边缘的海港界面，适合旅行换乘与远景图集。",
            dailyActivities: ["看港口船只", "整理素材合集", "更新旅行路线"]
        )
    ]

    static let nagoya: [WorldPlace] = [
        WorldPlace(
            id: "nagoya-castle",
            name: "名古屋城",
            city: .nagoya,
            district: "中区",
            latitude: 35.1856,
            longitude: 136.8997,
            role: .landmark,
            description: "名古屋世界的第一主地标，适合汇聚你和家人的旅行记录与照片合集。",
            dailyActivities: ["逛城墙与庭院", "拍金鯱屋顶", "整理家人聊天"]
        ),
        WorldPlace(
            id: "nagoya-station",
            name: "名古屋站",
            city: .nagoya,
            district: "中村区",
            latitude: 35.1709,
            longitude: 136.8815,
            role: .transport,
            description: "高铁与城市交通核心，用来串联东京、大阪、名古屋旅行线。",
            dailyActivities: ["换乘新干线", "记录到达时间", "同步路线卡片"]
        ),
        WorldPlace(
            id: "sakae",
            name: "荣商圈",
            city: .nagoya,
            district: "中区",
            latitude: 35.1681,
            longitude: 136.9086,
            role: .lifestyle,
            description: "商圈、塔楼和 Oasis 21 汇聚，是展示名古屋城市夜景与互动的主节点。",
            dailyActivities: ["逛街区", "拍塔楼夜景", "记录购物清单"]
        ),
        WorldPlace(
            id: "osu",
            name: "大须商店街",
            city: .nagoya,
            district: "中区",
            latitude: 35.1588,
            longitude: 136.9042,
            role: .neighborhood,
            description: "更生活化的街区，适合展现小店、手办和街边小吃类素材。",
            dailyActivities: ["扫街拍照", "找小吃", "更新手账"]
        ),
        WorldPlace(
            id: "atsuta-jingu",
            name: "热田神宫",
            city: .nagoya,
            district: "热田区",
            latitude: 35.1258,
            longitude: 136.9088,
            role: .park,
            description: "森林与神宫结合，适合安静的 Moments 与家人固定聊天提醒。",
            dailyActivities: ["林间散步", "收集木纹", "安排固定通话"]
        ),
        WorldPlace(
            id: "hisaya-odori",
            name: "久屋大通公园",
            city: .nagoya,
            district: "中区",
            latitude: 35.1715,
            longitude: 136.9080,
            role: .park,
            description: "城市中心绿轴，可承接休息、聚会与公共活动类记录。",
            dailyActivities: ["草地休息", "拍公园活动", "补充 Moments"]
        ),
        WorldPlace(
            id: "port-of-nagoya",
            name: "名古屋港",
            city: .nagoya,
            district: "港区",
            latitude: 35.0898,
            longitude: 136.8781,
            role: .transport,
            description: "港口与海湾场景适合放置远景素材与家人旅行计划。",
            dailyActivities: ["看海湾", "记录远景照片", "整理下一站路线"]
        ),
        WorldPlace(
            id: "mirai-tower",
            name: "中部电力 MIRAI TOWER",
            city: .nagoya,
            district: "中区",
            latitude: 35.1706,
            longitude: 136.9087,
            role: .landmark,
            description: "城市视野地标，可作为名古屋照片合集的高点展示位。",
            dailyActivities: ["登塔看城", "收集塔楼视角", "同步夜景"]
        ),
        WorldPlace(
            id: "oasis-21",
            name: "Oasis 21",
            city: .nagoya,
            district: "东区",
            latitude: 35.1704,
            longitude: 136.9095,
            role: .landmark,
            description: "未来感屋顶和开放广场适合作为地图面板里的现代城市标识。",
            dailyActivities: ["拍未来感屋顶", "记录广场活动", "更新城市卡片"]
        ),
        WorldPlace(
            id: "legoland-japan",
            name: "乐高乐园日本",
            city: .nagoya,
            district: "港区",
            latitude: 35.0470,
            longitude: 136.8477,
            role: .lifestyle,
            description: "更偏亲子和家庭出游的节点，用来放家庭 Moments 很自然。",
            dailyActivities: ["拍亲子瞬间", "记录出游路线", "整理家庭相册"]
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
