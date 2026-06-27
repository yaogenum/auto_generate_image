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
                proxyControlPanel
                recentProxyActivityPanel

                VStack(alignment: .leading, spacing: 12) {
                    Text("身份档案")
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

            HStack(spacing: 10) {
                ProxyStatusCard(
                    title: "当前回复方",
                    value: world.effectiveSelfProxyMode.rawValue,
                    symbol: world.isSelfProxyFullyDelegated ? "bolt.badge.automatic" : "person.wave.2.fill",
                    tint: world.effectiveSelfProxyMode == .human ? .blue : .mint
                )
                ProxyStatusCard(
                    title: "待确认",
                    value: "\(world.openAgentIssueCount)",
                    symbol: "checklist",
                    tint: world.openAgentIssueCount > 0 ? .orange : .green
                )
            }

            Text(world.isSelfProxyFullyDelegated
                 ? "你已超过 72 小时未接管，数字分身进入全托管。"
                 : world.effectiveSelfProxyMode.detail)
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
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private var recentProxyActivityPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("待确认与最近代办")
                    .font(.headline)
                Spacer()
                Text("\(world.openAgentIssueCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.orange)
            }

            if world.openAgentIssues.isEmpty {
                Text("当前没有需要你确认的问题。数字分身可以继续处理家人之间的日常互动。")
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

            let recentMessages = world.familyMembers
                .filter { !$0.isSelf }
                .compactMap { member -> (FamilyMember, FamilyMessage)? in
                    guard let latest = (world.conversations[member.id] ?? []).sorted(by: { $0.createdAt > $1.createdAt }).first else {
                        return nil
                    }
                    return (member, latest)
                }
                .sorted { $0.1.createdAt > $1.1.createdAt }
                .prefix(3)

            if !recentMessages.isEmpty {
                Divider()

                ForEach(Array(recentMessages), id: \.0.id) { member, message in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: message.isFromSelf ? "paperplane.fill" : "tray.and.arrow.down.fill")
                            .font(.caption)
                            .foregroundStyle(message.isFromSelf ? .mint : .secondary)
                            .frame(width: 24, height: 24)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground), in: Circle())

                        VStack(alignment: .leading, spacing: 3) {
                            Text(member.name)
                                .font(.caption.weight(.semibold))
                            Text(message.text)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer()
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

private struct ProxyStatusCard: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.13), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
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
