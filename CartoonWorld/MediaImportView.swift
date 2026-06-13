import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct MediaImportView: View {
    @Environment(WorldModel.self) private var world
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedPlaceID = "the-bund"
    @State private var title = ""
    @State private var pendingData: Data?
    @State private var pendingKind: MediaKind = .image
    @State private var isLoadingMedia = false
    @State private var errorMessage: String?

    var body: some View {
        @Bindable var world = world

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("把真实素材变成地图积木")
                        .font(.title2.bold())
                    Text("选择上海、东京或香港地点后上传照片或视频。当前版本会在本地生成卡通调色板和贡献状态，后续可接入生成式卡通化服务。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Picker("地点", selection: $selectedPlaceID) {
                    ForEach(world.places) { place in
                        Text("\(place.city.rawValue) · \(place.name) · \(place.district)").tag(place.id)
                    }
                }
                .pickerStyle(.menu)

                TextField("素材标题，例如：雨后的外滩", text: $title)
                    .textFieldStyle(.roundedBorder)

                PhotosPicker(selection: $selectedItem, matching: .any(of: [.images, .videos])) {
                    HStack {
                        Image(systemName: "square.and.arrow.up.on.square.fill")
                        Text(pendingData == nil ? "选择照片或视频" : "重新选择素材")
                        Spacer()
                        if isLoadingMedia {
                            ProgressView()
                        }
                    }
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.mint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .onChange(of: selectedItem) { _, newItem in
                    load(newItem)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                previewCard

                Button {
                    world.addContribution(
                        placeID: selectedPlaceID,
                        title: title,
                        mediaKind: pendingKind,
                        rawData: pendingData
                    )
                    world.moveAvatar(to: selectedPlaceID)
                    title = ""
                    pendingData = nil
                    selectedItem = nil
                } label: {
                    Label("卡通化并融入地图", systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(pendingData == nil || isLoadingMedia)

                contributionQueue
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .onAppear {
            selectedPlaceID = world.selectedPlaceID
        }
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("卡通化预览", systemImage: "paintpalette.fill")
                    .font(.headline)
                Spacer()
                Text(pendingKind.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if let pendingData {
                ThumbnailView(data: pendingData, palette: ["#5FE0C0", "#FFD166", "#7A6FF0"])
                    .frame(height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .bottomLeading) {
                        HStack(spacing: 8) {
                            ForEach(["描边", "低多边形", "糖果色"], id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(.black.opacity(0.52), in: Capsule())
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(10)
                    }
            } else {
                ContentUnavailableView(
                    "还没有素材",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("上传后会生成一张卡通缩略图，并作为该地点的世界资产。")
                )
                .frame(height: 190)
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private var contributionQueue: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("世界资产队列")
                .font(.headline)

            if world.contributions.isEmpty {
                Text("还没有上传素材。第一条贡献会出现在地图地点和数字人生活流里。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(world.contributions) { item in
                    ContributionRow(item: item, placeName: world.places.first(where: { $0.id == item.placeID })?.name ?? "未知地点")
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private func load(_ item: PhotosPickerItem?) {
        guard let item else { return }
        isLoadingMedia = true
        errorMessage = nil

        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    pendingData = data
                    let contentType = item.supportedContentTypes.first
                    pendingKind = contentType?.conforms(to: .movie) == true ? .video : .image
                } else {
                    errorMessage = "无法读取这个素材"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoadingMedia = false
        }
    }
}

private struct ContributionRow: View {
    let item: MediaContribution
    let placeName: String

    var body: some View {
        HStack(spacing: 12) {
            ThumbnailView(data: item.thumbnailData, palette: item.palette)
                .frame(width: 74, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                Text("\(placeName) · \(item.mediaKind.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StatusBadge(status: item.status)
        }
        .padding(.vertical, 4)
    }
}

private struct StatusBadge: View {
    let status: CartoonizationStatus

    var body: some View {
        Text(status.rawValue)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .foregroundStyle(foreground)
            .background(background, in: Capsule())
    }

    private var foreground: Color {
        switch status {
        case .queued: .orange
        case .stylizing: .blue
        case .integrated: .green
        }
    }

    private var background: Color {
        foreground.opacity(0.16)
    }
}

#Preview {
    NavigationStack {
        MediaImportView()
            .environment(WorldModel.preview)
    }
}
