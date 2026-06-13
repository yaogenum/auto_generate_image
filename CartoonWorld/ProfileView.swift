import SwiftUI

struct ProfileView: View {
    @Environment(WorldModel.self) private var world
    @State private var displayName = ""
    @State private var identity = ""
    @State private var homeDistrict = ""
    @State private var motto = ""

    var body: some View {
        @Bindable var world = world

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                profileCard

                VStack(alignment: .leading, spacing: 12) {
                    Text("注册数字人身份")
                        .font(.headline)

                    TextField("名字", text: $displayName)
                        .textFieldStyle(.roundedBorder)
                    TextField("身份，例如：城市建筑师", text: $identity)
                        .textFieldStyle(.roundedBorder)
                    TextField("常驻区域", text: $homeDistrict)
                        .textFieldStyle(.roundedBorder)
                    TextField("生活宣言", text: $motto, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        world.register(
                            displayName: displayName.isEmpty ? world.profile.displayName : displayName,
                            identity: identity.isEmpty ? world.profile.identity : identity,
                            homeDistrict: homeDistrict.isEmpty ? world.profile.homeDistrict : homeDistrict,
                            motto: motto.isEmpty ? world.profile.motto : motto
                        )
                        syncDraft()
                    } label: {
                        Label("保存身份", systemImage: "checkmark.seal.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        world.randomizeGuestIdentity()
                        syncDraft()
                    } label: {
                        Label("重新分配游客身份", systemImage: "dice.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(14)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))

                worldStats
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .onAppear(perform: syncDraft)
    }

    private var profileCard: some View {
        HStack(spacing: 16) {
            AvatarFace(seed: world.profile.avatarSeed, mood: world.currentMood)
                .frame(width: 76, height: 76)

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(world.profile.displayName)
                        .font(.title3.bold())
                    Text(world.profile.isRegistered ? "已注册" : "游客")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(world.profile.isRegistered ? Color.green.opacity(0.16) : Color.orange.opacity(0.16), in: Capsule())
                        .foregroundStyle(world.profile.isRegistered ? .green : .orange)
                }
                Text(world.profile.identity)
                    .font(.subheadline.weight(.semibold))
                Text("\(world.profile.homeDistrict) · \(world.profile.motto)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.mint.opacity(0.20), Color.cyan.opacity(0.12), Color(uiColor: .secondarySystemGroupedBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8)
        )
    }

    private var worldStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("世界进度")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    StatCell(title: "三城地点", value: "\(world.places.count)")
                    StatCell(title: "素材资产", value: "\(world.contributions.count)")
                }
                GridRow {
                    StatCell(title: "已融入", value: "\(world.contributions.filter { $0.status == .integrated }.count)")
                    StatCell(title: "能量", value: "\(Int(world.avatarEnergy * 100))%")
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private func syncDraft() {
        displayName = world.profile.displayName
        identity = world.profile.identity
        homeDistrict = world.profile.homeDistrict
        motto = world.profile.motto
    }
}

private struct StatCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environment(WorldModel.preview)
    }
}
