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

                proxyControlPanel

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
                    StatCell(title: "五城地点", value: "\(world.places.count)")
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

    private var proxyControlPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("我与数字分身")
                .font(.headline)

            Text("默认由你的数字分身先与其他家人的数字分身进行 social；只有遇到问题时，才把 issue 提给本人确认。")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(SelfProxyMode.allCases, id: \.self) { mode in
                    Button {
                        world.setSelfProxyMode(mode)
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: world.selfProxyMode == mode ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(world.selfProxyMode == mode ? .mint : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                Text(mode.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                }
            }

            HStack(spacing: 10) {
                Button("切回本人在线") {
                    world.touchHumanPresence()
                    world.setSelfProxyMode(.human)
                }
                .buttonStyle(.borderedProminent)
                .tint(.mint)

                Button("模拟长时间未登录") {
                    world.simulateLongAbsenceForDemo()
                }
                .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("当前托管状态")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(world.isSelfProxyFullyDelegated
                     ? "你已超过 72 小时未接管，数字分身已进入全托管模式。"
                     : "本人最近在线，当前策略为：\(world.effectiveSelfProxyMode.rawValue)。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("最近本人接管：\(world.lastHumanTakeoverAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("待确认 issue")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(world.openAgentIssueCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.orange)
                }

                if world.openAgentIssues.isEmpty {
                    Text("当前没有需要你确认的问题，数字分身可以继续保持对外社交。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(world.openAgentIssues.prefix(3)) { issue in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(world.familyMemberName(for: issue.memberID))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.mint)
                            Text(issue.prompt)
                                .font(.caption)
                            Text("建议回复：\(issue.suggestedReply)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 6) {
                                Button("确认发送") {
                                    world.approveIssue(issue.id)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.mint)
                                .controlSize(.mini)

                                Button("本人接管") {
                                    world.deferIssueToHuman(issue.id)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                        }
                        .padding(10)
                        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }
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
