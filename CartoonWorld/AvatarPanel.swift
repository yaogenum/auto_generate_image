import SwiftUI
import UIKit

struct AvatarPanel: View {
    @Environment(WorldModel.self) private var world

    var body: some View {
        @Bindable var world = world

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                AvatarFace(seed: world.profile.avatarSeed, mood: world.currentMood)

                VStack(alignment: .leading, spacing: 5) {
                    Text("\(world.profile.displayName) 在 \(world.selectedPlace.name)")
                        .font(.headline)
                    Text(world.selectedPlace.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }

            ProgressView(value: world.avatarEnergy)
                .tint(world.currentMood.color)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(world.selectedPlace.dailyActivities, id: \.self) { action in
                        Button {
                            world.performDailyAction(action)
                        } label: {
                            Label(action, systemImage: "sparkle")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            if !world.contributionsForSelectedPlace.isEmpty {
                ContributionStrip(contributions: world.contributionsForSelectedPlace)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct AvatarFace: View {
    let seed: Int
    let mood: AvatarMood

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [mood.color.opacity(0.82), .cyan.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Circle()
                .fill(.white.opacity(0.88))
                .frame(width: 46, height: 36)
                .offset(y: 4)
            HStack(spacing: 10) {
                Circle().fill(.black).frame(width: 6, height: 6)
                Circle().fill(.black).frame(width: 6, height: 6)
            }
            .offset(y: -1)
            Capsule()
                .fill(.black.opacity(0.75))
                .frame(width: 18 + CGFloat(seed % 3) * 4, height: 4)
                .offset(y: 13)
        }
        .frame(width: 58, height: 58)
        .overlay(alignment: .topTrailing) {
            Image(systemName: mood.symbolName)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(5)
                .background(.black.opacity(0.45), in: Circle())
        }
        .accessibilityLabel("数字人头像")
    }
}

private struct ContributionStrip: View {
    let contributions: [MediaContribution]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(contributions) { item in
                    HStack(spacing: 8) {
                        ThumbnailView(data: item.thumbnailData, palette: item.palette)
                            .frame(width: 54, height: 38)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Text(item.status.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 168, alignment: .leading)
                    .padding(7)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

struct ThumbnailView: View {
    let data: Data?
    let palette: [String]

    var body: some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .overlay {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.28)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        } else {
            HStack(spacing: 0) {
                ForEach(Array(palette.enumerated()), id: \.offset) { _, hex in
                    Color(hex: hex)
                }
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
