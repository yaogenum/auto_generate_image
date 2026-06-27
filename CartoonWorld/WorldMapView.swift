import MapKit
import SwiftUI

struct WorldMapView: View {
    @Environment(WorldModel.self) private var world
    @AppStorage("CartoonWorld.world.selectedCity") private var selectedCityRaw = WorldCity.hongKong.rawValue
    @AppStorage("CartoonWorld.world.displayMode") private var displayModeRaw = WorldDisplayMode.real3D.rawValue
    private let initialCity: WorldCity?
    private let initialDisplayMode: WorldDisplayMode?
    private let initialPanelSection: WorldPanelSection?
    private let initialPanelExpanded: Bool?
    private let initialUIHidden: Bool?
    private let initialSelectedPlaceID: String?
    private let jumpToFamily: (String) -> Void

    @State private var shouldAutoExpandOnPlaceChange: Bool = true

    private var panelExpandedBinding: Binding<Bool> {
        Binding(
            get: { world.isWorldPanelExpanded },
            set: { world.isWorldPanelExpanded = $0 }
        )
    }

    private var panelSectionBinding: Binding<WorldPanelSection> {
        Binding(
            get: { world.worldPanelSection },
            set: { world.worldPanelSection = $0 }
        )
    }

    private var uiHiddenBinding: Binding<Bool> {
        Binding(
            get: { world.isWorldUIHidden },
            set: { world.isWorldUIHidden = $0 }
        )
    }

    init(
        initialCity: WorldCity? = nil,
        initialDisplayMode: WorldDisplayMode? = nil,
        initialPanelSection: WorldPanelSection? = nil,
        initialPanelExpanded: Bool? = nil,
        initialUIHidden: Bool? = nil,
        initialSelectedPlaceID: String? = nil,
        jumpToFamily: @escaping (String) -> Void = { _ in }
    ) {
        self.initialCity = initialCity
        self.initialDisplayMode = initialDisplayMode
        self.initialPanelSection = initialPanelSection
        self.initialPanelExpanded = initialPanelExpanded
        self.initialUIHidden = initialUIHidden
        self.initialSelectedPlaceID = initialSelectedPlaceID
        self.jumpToFamily = jumpToFamily
        self._shouldAutoExpandOnPlaceChange = State(initialValue: initialPanelExpanded == nil)
    }

    private var selectedCity: WorldCity {
        WorldCity(rawValue: selectedCityRaw) ?? .hongKong
    }

    private var displayMode: WorldDisplayMode {
        WorldDisplayMode(rawValue: displayModeRaw) ?? .real3D
    }

    var body: some View {
        @Bindable var world = world
        let visiblePlaces = world.places.filter { $0.city == selectedCity }
        let visiblePlaceIDs = Set(visiblePlaces.map(\.id))
        let contributionCountByPlace = Dictionary(grouping: world.contributions, by: \.placeID).mapValues { $0.count }
        let momentCountByPlace = world.momentsByPlaceCount(for: selectedCity)
        let visibleContributionCount = world.contributions.filter { visiblePlaceIDs.contains($0.placeID) }.count
        let visibleMoments = world.moments(for: selectedCity)
        let visibleMomentCount = visibleMoments.count

        ZStack {
            Group {
                switch displayMode {
                case .real3D:
                    RealCityMapView(
                        places: visiblePlaces,
                        momentCountByPlace: momentCountByPlace,
                        selectedPlaceID: $world.selectedPlaceID
                    )
                case .cartoon:
                    CartoonWorldSceneView(
                        places: visiblePlaces,
                        contributions: world.contributions,
                        momentCountByPlace: momentCountByPlace,
                        selectedPlaceID: $world.selectedPlaceID
                    )
                }
            }
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 0) {
                if !uiHiddenBinding.wrappedValue {
                    topHUD(visiblePlaces: visiblePlaces)
                        .padding(.horizontal, 14)
                        .padding(.top, 8)

                    Spacer(minLength: 0)

                    bottomPanel(
                        visiblePlaces: visiblePlaces,
                        contributionCountByPlace: contributionCountByPlace,
                        momentCountByPlace: momentCountByPlace,
                        visibleContributionCount: visibleContributionCount,
                        visibleMoments: visibleMoments,
                        visibleMomentCount: visibleMomentCount
                    )
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
                }
            }

            if uiHiddenBinding.wrappedValue {
                VStack {
                    HStack {
                        Spacer()

                        Button {
                            withAnimation(.snappy) {
                                uiHiddenBinding.wrappedValue = false
                            }
                        } label: {
                            Label("展开界面", systemImage: "eye.fill")
                                .font(.caption.weight(.semibold))
                                .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                        .tint(.white)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .ignoresSafeArea()
            }
        }
        .onAppear {
            applyLaunchOverrides()
            ensureSelection(in: world.places.filter { $0.city == selectedCity })
        }
        .onChange(of: initialCity) { _, _ in
            applyLaunchOverrides()
            ensureSelection(in: world.places.filter { $0.city == selectedCity })
        }
        .onChange(of: initialDisplayMode) { _, _ in
            applyLaunchOverrides()
        }
        .onChange(of: initialPanelSection) { _, _ in
            applyLaunchOverrides()
        }
        .onChange(of: initialPanelExpanded) { _, _ in
            applyLaunchOverrides()
        }
        .onChange(of: initialUIHidden) { _, _ in
            applyLaunchOverrides()
        }
        .onChange(of: initialSelectedPlaceID) { _, _ in
            applyLaunchOverrides()
            ensureSelection(in: world.places.filter { $0.city == selectedCity })
        }
        .onChange(of: selectedCityRaw) { _, _ in
            ensureSelection(in: world.places.filter { $0.city == selectedCity })
        }
        .onChange(of: world.selectedPlaceID) { _, _ in
            guard shouldAutoExpandOnPlaceChange else {
                shouldAutoExpandOnPlaceChange = true
                return
            }

            withAnimation(.snappy) {
                panelExpandedBinding.wrappedValue = true
                world.worldPanelSection = .explore
            }
        }
    }

    private func applyLaunchOverrides() {
        if let initialCity {
            selectedCityRaw = initialCity.rawValue
        }

        if let initialDisplayMode {
            displayModeRaw = initialDisplayMode.rawValue
        }

        if let initialPanelSection {
            world.worldPanelSection = initialPanelSection
        }

        if let initialPanelExpanded {
            world.isWorldPanelExpanded = initialPanelExpanded
        }

        if let initialUIHidden {
            world.isWorldUIHidden = initialUIHidden
        }

        if let initialSelectedPlaceID = initialSelectedPlaceID, let matchingPlace = world.places.first(where: { $0.id == initialSelectedPlaceID }) {
            world.selectedPlaceID = matchingPlace.id
        }
    }

    private func topHUD(visiblePlaces: [WorldPlace]) -> some View {
        HStack {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(selectedCity.rawValue)数字世界")
                        .font(.caption.weight(.bold))
                    Text(world.selectedPlace.district)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Divider()
                    .frame(height: 24)

                Menu {
                    Picker("城市", selection: selectedCityBinding) {
                        ForEach(WorldCity.allCases, id: \.self) { city in
                            Text(city.rawValue).tag(city)
                        }
                    }
                } label: {
                    Label(selectedCity.rawValue, systemImage: "mappin.and.ellipse")
                        .font(.caption.weight(.semibold))
                }

                Button {
                    withAnimation(.snappy) {
                        displayModeRaw = displayMode.toggled.rawValue
                    }
                } label: {
                    Label(displayMode.shortTitle, systemImage: displayMode.symbolName)
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
                .tint(.mint)

                Button {
                    withAnimation(.snappy) {
                        uiHiddenBinding.wrappedValue = true
                        panelExpandedBinding.wrappedValue = false
                    }
                } label: {
                    Label("收起界面", systemImage: "eye.slash.fill")
                        .font(.caption.weight(.semibold))
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
                .tint(.white.opacity(0.9))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)

            Spacer(minLength: 0)
        }
    }

    private func bottomPanel(
        visiblePlaces: [WorldPlace],
        contributionCountByPlace: [String: Int],
        momentCountByPlace: [String: Int],
        visibleContributionCount: Int,
        visibleMoments: [FamilyMoment],
        visibleMomentCount: Int
    ) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                if panelExpandedBinding.wrappedValue {
                    Text("世界面板")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    compactStatus(
                        visiblePlaces: visiblePlaces,
                        visibleContributionCount: visibleContributionCount,
                        visibleMomentCount: visibleMomentCount
                    )
                }

                Spacer(minLength: 8)

                Button {
                    withAnimation(.snappy) {
                        panelExpandedBinding.wrappedValue.toggle()
                    }
                } label: {
                    Label(panelExpandedBinding.wrappedValue ? "收起" : "展开", systemImage: panelExpandedBinding.wrappedValue ? "chevron.down" : "chevron.up")
                        .font(.caption.weight(.bold))
                        .labelStyle(.titleAndIcon)
                        .frame(minWidth: 64)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.mint)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))

            if panelExpandedBinding.wrappedValue {
                VStack(spacing: 12) {
                    panelSectionPicker

                    switch panelSectionBinding.wrappedValue {
                    case .explore:
                        controlDeck(
                            visiblePlaces: visiblePlaces,
                            contributionCountByPlace: contributionCountByPlace,
                            momentCountByPlace: momentCountByPlace,
                            visibleContributionCount: visibleContributionCount,
                            visibleMomentCount: visibleMomentCount
                        )
                        placeCarousel(
                            visiblePlaces: visiblePlaces,
                            contributionCountByPlace: contributionCountByPlace,
                            momentCountByPlace: momentCountByPlace
                        )
                        selectedPlaceDetailPanel
                    case .moments:
                        momentsPanel(
                            visiblePlaces: visiblePlaces,
                            visibleMoments: visibleMoments,
                            momentCountByPlace: momentCountByPlace
                        )
                    case .relations:
                        familyInteractionPanel
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func compactStatus(
        visiblePlaces: [WorldPlace],
        visibleContributionCount: Int,
        visibleMomentCount: Int
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: displayMode.symbolName)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.mint, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("\(selectedCity.rawValue) · \(world.selectedPlace.name)")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text("\(displayMode.title) · 地点 \(explorationPercent(for: visiblePlaces))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("素材\(visibleContributionCount) · 时刻\(visibleMomentCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var selectedCityBinding: Binding<WorldCity> {
        Binding {
            selectedCity
        } set: { newValue in
            selectedCityRaw = newValue.rawValue
        }
    }

    private var displayModeBinding: Binding<WorldDisplayMode> {
        Binding {
            displayMode
        } set: { newValue in
            displayModeRaw = newValue.rawValue
        }
    }

    private func controlDeck(
        visiblePlaces: [WorldPlace],
        contributionCountByPlace: [String: Int],
        momentCountByPlace: [String: Int],
        visibleContributionCount: Int,
        visibleMomentCount: Int
    ) -> some View {
        VStack(spacing: 10) {
            citySelectorStrip

            Picker("模式", selection: displayModeBinding) {
                ForEach(WorldDisplayMode.allCases, id: \.self) { mode in
                    Label(mode.title, systemImage: mode.symbolName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                StatPill(title: "区域", value: "\(visiblePlaces.count)")
                StatPill(title: "素材", value: "\(visibleContributionCount)")
                StatPill(title: "Moments", value: "\(visibleMomentCount)")
                StatPill(title: "覆盖", value: "\(explorationPercent(for: visiblePlaces))%")
            }

            if !visiblePlaces.isEmpty {
                let selectedMomentCount = momentCountByPlace[world.selectedPlaceID, default: 0]
                StatPill(title: "当前地点", value: "\(world.selectedPlace.name) · \(selectedMomentCount) 条")
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var panelSectionPicker: some View {
                    Picker("世界视图", selection: panelSectionBinding) {
            ForEach(WorldPanelSection.allCases, id: \.self) { section in
                Text(section.title)
                    .tag(section)
            }
        }
        .pickerStyle(.segmented)
    }

    private var citySelectorStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(WorldCity.allCases, id: \.self) { city in
                    Button {
                        selectedCityBinding.wrappedValue = city
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: city == selectedCity ? "location.fill" : "location")
                                .font(.caption2.weight(.bold))
                            Text(city.rawValue)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(city == selectedCity ? .white : .primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(city == selectedCity ? Color.mint : Color(uiColor: .secondarySystemBackground), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var selectedPlaceDetailPanel: some View {
        let place = world.selectedPlace
        let contributions = world.contributionsForSelectedPlace

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.headline)
                    Text("\(place.city.rawValue) · \(place.district) · \(place.role.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(place.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(contributions.count)")
                        .font(.headline.monospacedDigit())
                    Text("素材")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    placeSectionTitle("图片合集", count: contributions.count)

                    if contributions.isEmpty {
                        emptyStateCard(
                            icon: "photo.stack",
                            title: "当前地标还没有挂载图片",
                            subtitle: "本地素材导入后会按城市和关键字自动绑定到这个地标。"
                        )
                    } else {
                        ForEach(contributions) { contribution in
                            PlaceContributionRow(
                                item: contribution,
                                imageData: world.contributionImageData(for: contribution)
                            )
                        }
                    }
                }
            }
            .frame(maxHeight: 260)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func placeSectionTitle(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(count)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
        }
    }

    private func emptyStateCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.mint)
                .frame(width: 28, height: 28)
                .background(Color.mint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private var familyInteractionPanel: some View {
        let place = world.selectedPlace
        let moments = world.moments(for: place)
        let relatedMemberIDs = Array(Set(moments.map(\.memberID))).prefix(4)
        let fallbackMembers = world.familyMembers.filter { !$0.isSelf }.prefix(3)
        let memberIDs = relatedMemberIDs.isEmpty ? fallbackMembers.map(\.id) : Array(relatedMemberIDs)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("家人互动")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(place.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }

                Spacer()

                Text("\(memberIDs.count) 人")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
            }

            if memberIDs.isEmpty {
                emptyStateCard(
                    icon: "person.2.slash",
                    title: "当前还没有家人关系",
                    subtitle: "先在家人页录入成员，聊天和旅行时刻会自动关联到地点。"
                )
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(memberIDs, id: \.self) { memberID in
                            if let member = world.familyMembers.first(where: { $0.id == memberID }) {
                                PlaceFamilyInteractionRow(
                                    member: member,
                                    relationLabel: world.relationLabel(fromSelfTo: member),
                                    latestMoment: moments.first(where: { $0.memberID == memberID }),
                                    latestMessage: (world.conversations[memberID] ?? []).sorted { $0.createdAt > $1.createdAt }.first,
                                    onChatTapped: {
                                        jumpToFamily(member.id)
                                    }
                                )
                            }
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func momentsPanel(
        visiblePlaces: [WorldPlace],
        visibleMoments: [FamilyMoment],
        momentCountByPlace: [String: Int]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Moments")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("共 \(visibleMoments.count) 条")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if visibleMoments.isEmpty {
                Text("当前城市还没有 Moments，先从地图标记 POI 进行记录")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(visibleMoments) { moment in
                            Button {
                                if let placeID = moment.placeID {
                                    world.selectedPlaceID = placeID
                                } else if let fallback = world.places.first(where: { $0.name == moment.placeName && $0.city.rawValue == moment.city })?.id {
                                    world.selectedPlaceID = fallback
                                }
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "sparkle.magnifyingglass")
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                        .frame(width: 24, height: 24)
                                        .background(.purple, in: Circle())

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(moment.title)
                                            .font(.subheadline.weight(.semibold))
                                        Text(moment.note)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                        Text("\(moment.placeName) · \(moment.date.formatted(date: .numeric, time: .shortened))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer(minLength: 0)

                                    Text(world.familyMemberName(for: moment.memberID))
                                        .font(.caption2)
                                        .foregroundStyle(.mint)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(.mint.opacity(0.12), in: Capsule())
                                }
                                .padding(10)
                                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 230)
            }

            let hotPlaces = visiblePlaces.filter { momentCountByPlace[$0.id, default: 0] > 0 }
            if !hotPlaces.isEmpty {
                Text("当前城市时刻热区")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(hotPlaces) { place in
                            let momentCount = momentCountByPlace[place.id, default: 0]
                            Button {
                                world.selectedPlaceID = place.id
                                world.worldPanelSection = .explore
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "location.north.circle.fill")
                                        .font(.caption2)
                                    Text("\(place.name) · \(momentCount)")
                                        .font(.caption2.weight(.semibold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.purple.opacity(0.16), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 280)
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var worldHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(selectedCity.rawValue)数字世界")
                    .font(.headline)
                Text("\(displayMode.title) · 当前 \(world.selectedPlace.district)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(world.profile.displayName) · \(world.currentMood.label)")
                    .font(.subheadline.weight(.semibold))
                Label(world.currentMood.label, systemImage: world.currentMood.symbolName)
                    .font(.caption2)
                    .foregroundStyle(world.currentMood.color)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var questTracker: some View {
        HStack(spacing: 10) {
            Image(systemName: "scope")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.orange, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("追踪目标：\(world.selectedPlace.name)")
                    .font(.subheadline.weight(.semibold))
                Text(world.selectedPlace.dailyActivities.first ?? "探索城市")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                world.performDailyAction(world.selectedPlace.dailyActivities.first ?? "探索城市")
            } label: {
                Image(systemName: "sparkles")
                    .font(.headline.weight(.semibold))
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.borderedProminent)
            .tint(.mint)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func placeCarousel(
        visiblePlaces: [WorldPlace],
        contributionCountByPlace: [String: Int],
        momentCountByPlace: [String: Int]
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(visiblePlaces) { place in
                    Button {
                        withAnimation(.snappy) {
                            world.moveAvatar(to: place.id)
                        }
                    } label: {
                        PlaceChip(
                            place: place,
                            isSelected: place.id == world.selectedPlaceID,
                            contributionCount: contributionCountByPlace[place.id, default: 0],
                            momentCount: momentCountByPlace[place.id, default: 0]
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func ensureSelection(in places: [WorldPlace]) {
        guard !places.contains(where: { $0.id == world.selectedPlaceID }),
              let first = places.first else {
            return
        }
        world.moveAvatar(to: first.id)
    }

    private func explorationPercent(for places: [WorldPlace]) -> Int {
        guard !places.isEmpty else { return 0 }
        let contributed = Set(world.contributions.map(\.placeID))
        let visitedCount = places.filter { $0.id == world.selectedPlaceID || contributed.contains($0.id) }.count
        return min(100, max(8, Int((Double(visitedCount) / Double(places.count)) * 100)))
    }
}

private struct RealCityMapView: View {
    let places: [WorldPlace]
    let momentCountByPlace: [String: Int]
    @Binding var selectedPlaceID: String

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position) {
            ForEach(places) { place in
                Annotation(place.name, coordinate: place.coordinate) {
                    Button {
                        selectedPlaceID = place.id
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: place.role.symbolName)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: place.id == selectedPlaceID ? 42 : 34, height: place.id == selectedPlaceID ? 42 : 34)
                                .background(place.role.color, in: Circle())
                                .overlay {
                                    Circle()
                                        .stroke(.white, lineWidth: place.id == selectedPlaceID ? 3 : 1.5)
                                }
                                .shadow(color: .black.opacity(0.28), radius: 8, y: 4)

                            if let count = momentCountByPlace[place.id], count > 0 {
                                Text("\(count)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .padding(5)
                                    .background(.purple, in: Circle())
                                    .offset(x: 6, y: -6)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .mapStyle(.hybrid(elevation: .realistic))
        .mapControls {
            MapCompass()
            MapScaleView()
            MapPitchToggle()
        }
        .onAppear {
            focusSelectedPlace()
        }
        .onChange(of: selectedPlaceID) { _, _ in
            focusSelectedPlace()
        }
        .onChange(of: places) { _, _ in
            focusSelectedPlace()
        }
    }

    private func focusSelectedPlace() {
        guard let selected = places.first(where: { $0.id == selectedPlaceID }) ?? places.first else { return }
        position = .camera(
            MapCamera(
                centerCoordinate: selected.coordinate,
                distance: cameraDistance(for: selected.city),
                heading: cameraHeading(for: selected.city),
                pitch: 62
            )
        )
    }

    private func cameraDistance(for city: WorldCity) -> CLLocationDistance {
        switch city {
        case .shanghai: 5_800
        case .tokyo: 5_200
        case .osaka: 4_900
        case .nagoya: 4_700
        case .hongKong: 4_600
        }
    }

    private func cameraHeading(for city: WorldCity) -> CLLocationDirection {
        switch city {
        case .shanghai: 42
        case .tokyo: 26
        case .osaka: 34
        case .nagoya: 22
        case .hongKong: 18
        }
    }
}

private struct StatPill: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.bold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct PlaceChip: View {
    let place: WorldPlace
    let isSelected: Bool
    let contributionCount: Int
    let momentCount: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: place.role.symbolName)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(place.role.color, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.subheadline.weight(.semibold))
                Text("\(place.role.rawValue) · \(contributionCount) 素材 · \(momentCount) Moments")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isSelected ? Color.mint.opacity(0.22) : Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.mint : .clear, lineWidth: 1.5)
        }
    }
}

private struct PlaceContributionRow: View {
    let item: MediaContribution
    let imageData: Data?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ThumbnailView(data: imageData ?? item.thumbnailData, palette: item.palette)
                .frame(width: 92, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(item.summary ?? "已接入地标素材")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(item.mediaKind.rawValue)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.mint)
                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            WorldContributionStatusBadge(status: item.status)
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct PlaceMomentRow: View {
    let moment: FamilyMoment
    let memberName: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(.purple, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(moment.title)
                    .font(.subheadline.weight(.semibold))
                Text(moment.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                HStack(spacing: 8) {
                    Text(memberName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.mint)
                    Text(moment.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct WorldContributionStatusBadge: View {
    let status: CartoonizationStatus

    var body: some View {
        Text(status.rawValue)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .foregroundStyle(foreground)
            .background(foreground.opacity(0.15), in: Capsule())
    }

    private var foreground: Color {
        switch status {
        case .queued: .orange
        case .stylizing: .blue
        case .integrated: .green
        }
    }
}

private struct PlaceFamilyInteractionRow: View {
    let member: FamilyMember
    let relationLabel: String
    let latestMoment: FamilyMoment?
    let latestMessage: FamilyMessage?
    let onChatTapped: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AvatarSeedBadge(seed: member.avatarSeed, isSelf: member.isSelf)
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.name)
                        .font(.subheadline.weight(.semibold))
                    Text(relationLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if member.hasContact {
                    Label("可联系", systemImage: "phone.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.mint)
                }
            }

            if let latestMoment {
                Text("关联时刻：\(latestMoment.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let latestMessage {
                Text(latestMessage.text)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.mint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            } else {
                Text("还没有聊天记录，当前地标会在后续成为这个家人的旅行聊天落点。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let onChatTapped {
                Button {
                    onChatTapped()
                } label: {
                    Text("去家人页聊这条")
                        .font(.caption2.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .padding(.top, 2)
            }
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct AvatarSeedBadge: View {
    let seed: Int
    let isSelf: Bool

    private var palette: [Color] {
        [
            .mint, .orange, .blue, .pink, .green, .indigo, .teal
        ]
    }

    var body: some View {
        Text(isSelf ? "我" : String(seed % 9 + 1))
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(palette[abs(seed) % palette.count], in: Circle())
    }
}

#Preview {
    NavigationStack {
        WorldMapView()
            .environment(WorldModel.preview)
    }
}
