import SwiftUI
import Foundation

private enum FamilyDebugToggle: String {
    case trueValue = "1"
    case falseValue = "0"
    case yes = "true"
    case no = "false"
    case enabled = "enabled"
    case disabled = "disabled"

    var boolValue: Bool {
        switch self {
        case .trueValue, .yes, .enabled: true
        default: false
        }
    }
}

private func debugValue(_ key: String) -> String? {
    ProcessInfo.processInfo.environment[key]?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .nilIfEmpty
    ?? ProcessInfo.processInfo.arguments
        .first(where: { $0.hasPrefix("--\(key)=") })?
        .split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        .dropFirst()
        .joined()
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private func debugBool(_ key: String) -> Bool? {
    guard let raw = debugValue(key)?.lowercased() else { return nil }
    guard let toggle = FamilyDebugToggle(rawValue: raw) else { return nil }
    return toggle.boolValue
}

private func debugEnumMatch<T>(_ key: String, candidates: [T]) -> T? where T: RawRepresentable, T.RawValue == String {
    guard let raw = debugValue(key)?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
    let normalized = raw.lowercased()

    if let direct = candidates.first(where: { String(describing: $0.rawValue) == raw }) {
        return direct
    }
    if let directLower = candidates.first(where: { String(describing: $0.rawValue).lowercased() == normalized }) {
        return directLower
    }
    return nil
}

struct ContentView: View {
    @Environment(WorldModel.self) private var world
    @State private var selectedTab: AppTab = .family
    @State private var initialFamilyLayout: FamilyContactLayout = .topology
    @State private var initialFamilyExpanded: Bool = false
    @State private var initialFamilyCallTrayExpanded: Bool = false
    @State private var initialCity: WorldCity? = nil
    @State private var initialDisplayMode: WorldDisplayMode? = nil
    @State private var initialPanelSection: WorldPanelSection? = nil
    @State private var initialPanelExpanded: Bool? = nil
    @State private var initialUIHidden: Bool? = nil
    @State private var initialSelectedPlaceID: String? = nil
    @State private var isAutoDemoRunning = false
    @State private var autoDemoTask: Task<Void, Never>? = nil

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                FamilyHubView(
                    initialLayout: initialFamilyLayout,
                    initialExpanded: initialFamilyExpanded,
                    initialCallTrayExpanded: initialFamilyCallTrayExpanded
                )
                .navigationTitle("家人")
            }
            .tabItem { Label("家人", systemImage: "person.2.fill") }
            .tag(AppTab.family)

            NavigationStack {
                WorldMapView(
                    initialCity: initialCity,
                    initialDisplayMode: initialDisplayMode,
                    initialPanelSection: initialPanelSection,
                    initialPanelExpanded: initialPanelExpanded,
                    initialUIHidden: initialUIHidden,
                    initialSelectedPlaceID: initialSelectedPlaceID,
                    jumpToFamily: { memberID in
                        selectedTab = .family
                        world.selectFamilyMember(id: memberID)
                    }
                )
                .navigationTitle("卡通世界")
                .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label("世界", systemImage: "map") }
            .tag(AppTab.world)

            NavigationStack {
                MediaImportView()
                    .navigationTitle("融入地图")
            }
            .tabItem { Label("上传", systemImage: "photo.badge.plus") }
            .tag(AppTab.upload)

            NavigationStack {
                ProfileView()
                    .navigationTitle("数字人")
            }
            .tabItem { Label("身份", systemImage: "person.crop.circle") }
            .tag(AppTab.profile)
        }
        .tint(.mint)
        .onAppear {
            if let overrideTab = debugTab {
                selectedTab = overrideTab
            }
            if let layout = debugFamilyLayout {
                initialFamilyLayout = layout
            }
            if let expanded = debugFamilyExpanded {
                initialFamilyExpanded = expanded
            }
            if let callTrayExpanded = debugFamilyCallTrayExpanded {
                initialFamilyCallTrayExpanded = callTrayExpanded
            }
            if let city = debugWorldCity {
                initialCity = city
            }
            if let mode = debugWorldDisplayMode {
                initialDisplayMode = mode
            }
            if let section = debugWorldPanelSection {
                initialPanelSection = section
            }
            if let panelExpanded = debugWorldPanelExpanded {
                initialPanelExpanded = panelExpanded
            }
            if let uiHidden = debugWorldUIHidden {
                initialUIHidden = uiHidden
            }
            if let place = debugWorldSelectedPlace {
                initialSelectedPlaceID = place
            }
            world.bootstrapIfNeeded()
            if let endpoint = debugFamilyContactEndpoint,
               let memberID = world.selectFirstExternalFamilyMember() {
                world.selectFamilyMember(id: memberID)
                world.setContactEndpoint(for: memberID, to: endpoint)
            }
            launchAutoDemoIfNeeded()
        }
        .onDisappear {
            autoDemoTask?.cancel()
            autoDemoTask = nil
            isAutoDemoRunning = false
        }
    }

    private func launchAutoDemoIfNeeded() {
        guard autoDemoEnabled, !isAutoDemoRunning else { return }
        isAutoDemoRunning = true
        autoDemoTask = Task { @MainActor in
            await runAutoDemoFlow()
        }
    }

    @MainActor
    private func runAutoDemoFlow() async {
        guard world.familyMembers.count > 1 else {
            isAutoDemoRunning = false
            return
        }

        let delay = UInt64((debugAutoDemoStepDelayMs ?? 900) * 1_000_000)
        let familyMemberID = world.selectFirstExternalFamilyMember() ?? world.familyMembers.first(where: { !$0.isSelf })?.id ?? world.selectedFamilyMemberID

        selectedTab = .family
        initialFamilyLayout = .list
        initialFamilyExpanded = true
        await sleepAsync(delay)

        if let memberID = world.familyMembers.first(where: { $0.id == familyMemberID })?.id {
            world.selectFamilyMember(id: memberID)
            await sleepAsync(delay)
        }

        world.isFamilyChatExpanded = true
        await sleepAsync(delay)

        let targetID = world.selectedFamilyMemberID
        if !targetID.isEmpty {
            world.sendMessage(to: targetID, text: "今天我先做一次自动化演示，后续用数字分身同步你这边的家人记录。")
            await sleepAsync(delay)
            world.simulateIncomingMessage(from: targetID)
            await sleepAsync(delay)
            world.simulateCommunication(to: targetID, isVideo: false)
            await sleepAsync(delay)
            world.simulateCommunication(to: targetID, isVideo: true)
        }

        await sleepAsync(delay * 2)
        selectedTab = .world
        await sleepAsync(delay)

        UserDefaults.standard.set(WorldCity.tokyo.rawValue, forKey: "CartoonWorld.world.selectedCity")
        UserDefaults.standard.set(WorldDisplayMode.real3D.rawValue, forKey: "CartoonWorld.world.displayMode")
        if let tokyoTower = world.places.first(where: { $0.id == "tokyo-tower" }) {
            world.selectedPlaceID = tokyoTower.id
        }
        world.isWorldPanelExpanded = true
        world.worldPanelSection = .explore
        world.isWorldUIHidden = false
        await sleepAsync(delay)

        if let osakaPlace = world.places.first(where: { $0.id == "osaka-castle" }) {
            world.selectedPlaceID = osakaPlace.id
            world.worldPanelSection = .moments
        }
        await sleepAsync(delay)

        if let hkPlace = world.places.first(where: { $0.id == "victoria-harbour" }) {
            world.selectedPlaceID = hkPlace.id
            world.worldPanelSection = .relations
        }
        await sleepAsync(delay)

        selectedTab = .upload
        await sleepAsync(delay * 2)

        selectedTab = .profile
        await sleepAsync(delay * 2)

        if let momID = world.familyMembers.first(where: { !$0.isSelf })?.id {
            world.selectFamilyMember(id: momID)
        }
        selectedTab = .family
        isAutoDemoRunning = false
    }

    private func sleepAsync(_ nanos: UInt64) async {
        try? await Task.sleep(nanoseconds: nanos)
    }

    private var debugTab: AppTab? {
        guard let raw = debugValue("CARTOON_INITIAL_TAB")?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        return AppTab.allCases.first(where: { $0.rawValue.lowercased() == raw.lowercased() })
    }

    private var debugFamilyLayout: FamilyContactLayout? {
        guard let raw = debugValue("CARTOON_INITIAL_FAMILY_LAYOUT")?.lowercased() else { return nil }
        return FamilyContactLayout.allCases.first { $0.rawValue.lowercased() == raw }
    }

    private var debugFamilyExpanded: Bool? {
        debugBool("CARTOON_INITIAL_FAMILY_EXPANDED")
    }

    private var debugFamilyCallTrayExpanded: Bool? {
        debugBool("CARTOON_INITIAL_FAMILY_CALL_TRAY_EXPANDED")
    }

    private var debugFamilyContactEndpoint: ContactConversationEndpoint? {
        guard let raw = debugValue("CARTOON_INITIAL_FAMILY_CONTACT_ENDPOINT")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() else { return nil }

        switch raw {
        case "local", "localagent", "local_agent", "本机", "本机agent", "本机模拟":
            return .localAgent
        case "remote", "remoteagent", "remote_agent", "online", "线上", "线上agent", "对方在线":
            return .remoteAgent
        case "human", "humanuser", "human_user", "真人", "真人用户", "真人在线":
            return .humanUser
        case "offline", "humanoffline", "human_offline", "真人离线", "真人未登录":
            return .humanOffline
        default:
            return ContactConversationEndpoint.allCases.first {
                $0.rawValue.lowercased() == raw
            }
        }
    }

    private var debugWorldCity: WorldCity? {
        guard let raw = debugValue("CARTOON_INITIAL_WORLD_CITY")?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        return WorldCity(rawValue: raw) ?? WorldCity.allCases.first(where: { $0.rawValue.lowercased() == raw.lowercased() })
    }

    private var debugWorldDisplayMode: WorldDisplayMode? {
        let normalized = debugValue("CARTOON_INITIAL_WORLD_MODE")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        if normalized == "real" || normalized == "real3d" || normalized == "real_3d" || normalized == "3d" {
            return .real3D
        }
        if normalized == "cartoon" || normalized == "cartoon3d" || normalized == "cartoonworld" {
            return .cartoon
        }

        return debugEnumMatch("CARTOON_INITIAL_WORLD_MODE", candidates: Array(WorldDisplayMode.allCases))
    }

    private var debugWorldPanelSection: WorldPanelSection? {
        return debugEnumMatch("CARTOON_INITIAL_WORLD_PANEL_SECTION", candidates: Array(WorldPanelSection.allCases))
    }

    private var debugWorldPanelExpanded: Bool? {
        debugBool("CARTOON_INITIAL_WORLD_PANEL_EXPANDED")
    }

    private var debugWorldUIHidden: Bool? {
        debugBool("CARTOON_INITIAL_WORLD_UI_HIDDEN")
    }

    private var debugWorldSelectedPlace: String? {
        debugValue("CARTOON_INITIAL_WORLD_SELECTED_PLACE")
    }

    private var autoDemoEnabled: Bool {
        debugBool("CARTOON_AUTO_DEMO") ?? false
    }

    private var debugAutoDemoStepDelayMs: Int? {
        guard let raw = debugValue("CARTOON_AUTO_DEMO_DELAY_MS")?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }
        return Int(raw)
    }
}

private enum AppTab: String, Hashable, CaseIterable {
    case family = "family"
    case world = "world"
    case upload = "upload"
    case profile = "profile"
}

#Preview {
    ContentView()
        .environment(WorldModel.preview)
}
