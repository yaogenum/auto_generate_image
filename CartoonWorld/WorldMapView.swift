import MapKit
import SwiftUI

struct WorldMapView: View {
    @Environment(WorldModel.self) private var world
    @State private var selectedCity: WorldCity = .hongKong
    @State private var displayMode: WorldDisplayMode = .real3D
    @State private var isPanelExpanded = false

    var body: some View {
        @Bindable var world = world
        let visiblePlaces = world.places.filter { $0.city == selectedCity }

        ZStack(alignment: .bottom) {
            Group {
                switch displayMode {
                case .real3D:
                    RealCityMapView(
                        places: visiblePlaces,
                        selectedPlaceID: $world.selectedPlaceID
                    )
                case .cartoon:
                    CartoonWorldSceneView(
                        places: visiblePlaces,
                        contributions: world.contributions,
                        selectedPlaceID: $world.selectedPlaceID
                    )
                }
            }
            .ignoresSafeArea(edges: .top)

            bottomPanel(visiblePlaces: visiblePlaces)
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .onAppear {
            ensureSelection(in: visiblePlaces)
        }
        .onChange(of: selectedCity) { _, _ in
            ensureSelection(in: world.places.filter { $0.city == selectedCity })
        }
    }

    private func bottomPanel(visiblePlaces: [WorldPlace]) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                if isPanelExpanded {
                    Text("探索面板")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    compactStatus(visiblePlaces: visiblePlaces)
                }

                Spacer(minLength: 8)

                Button {
                    withAnimation(.snappy) {
                        isPanelExpanded.toggle()
                    }
                } label: {
                    Label(isPanelExpanded ? "收起" : "展开", systemImage: isPanelExpanded ? "chevron.down" : "chevron.up")
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

            if isPanelExpanded {
                VStack(spacing: 12) {
                    controlDeck(visiblePlaces: visiblePlaces)
                    worldHeader
                    questTracker
                    placeCarousel(visiblePlaces: visiblePlaces)
                    AvatarPanel()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func compactStatus(visiblePlaces: [WorldPlace]) -> some View {
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
                Text("\(displayMode.title) · 探索 \(explorationPercent(for: visiblePlaces))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func controlDeck(visiblePlaces: [WorldPlace]) -> some View {
        VStack(spacing: 10) {
            Picker("城市", selection: $selectedCity) {
                ForEach(WorldCity.allCases, id: \.self) { city in
                    Text(city.rawValue).tag(city)
                }
            }
            .pickerStyle(.segmented)

            Picker("模式", selection: $displayMode) {
                ForEach(WorldDisplayMode.allCases, id: \.self) { mode in
                    Label(mode.title, systemImage: mode.symbolName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                StatPill(title: "区域", value: "\(visiblePlaces.count)")
                StatPill(title: "素材", value: "\(world.contributions.filter { contribution in visiblePlaces.contains { $0.id == contribution.placeID } }.count)")
                StatPill(title: "探索", value: "\(explorationPercent(for: visiblePlaces))%")
            }
        }
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
                Text(world.profile.displayName)
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

    private func placeCarousel(visiblePlaces: [WorldPlace]) -> some View {
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
                            contributionCount: world.contributions.filter { $0.placeID == place.id }.count
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

private enum WorldDisplayMode: String, CaseIterable, Hashable {
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
}

private struct RealCityMapView: View {
    let places: [WorldPlace]
    @Binding var selectedPlaceID: String

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position) {
            ForEach(places) { place in
                Annotation(place.name, coordinate: place.coordinate) {
                    Button {
                        selectedPlaceID = place.id
                    } label: {
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
        case .hongKong: 4_600
        }
    }

    private func cameraHeading(for city: WorldCity) -> CLLocationDirection {
        switch city {
        case .shanghai: 42
        case .tokyo: 26
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
                Text("\(place.role.rawValue) · \(contributionCount) 个素材")
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

#Preview {
    NavigationStack {
        WorldMapView()
            .environment(WorldModel.preview)
    }
}
