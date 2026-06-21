import SwiftUI

struct FamilyHubView: View {
    @Environment(WorldModel.self) private var world
    @Environment(\.openURL) private var openURL
    @State private var messageDraft = ""
    @State private var showFamilyManager = false
    @FocusState private var isComposerFocused: Bool
    @State private var contactLayout: FamilyContactLayout = .topology
    @State private var isComposerCallTrayExpanded = false
    private let initialChatExpanded: Bool
    private let initialCallTrayExpanded: Bool

    init(
        initialLayout: FamilyContactLayout = .topology,
        initialExpanded: Bool = false,
        initialCallTrayExpanded: Bool = false
    ) {
        _contactLayout = State(initialValue: initialLayout)
        initialChatExpanded = initialExpanded
        self.initialCallTrayExpanded = initialCallTrayExpanded
    }

    private typealias TopologyLayout = (point: CGPoint, row: Int, index: Int)

    var body: some View {
        @Bindable var world = world

        Group {
            if world.isFamilyChatExpanded {
                expandedChatPanel(world: world)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                VStack(spacing: 0) {
                    contactSection(world: world)
                    compactChatPanel(world: world)
                }
                Spacer(minLength: 0)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFamilyManager = true
                } label: {
                    Label("家人管理", systemImage: "person.2.fill")
                }
            }
        }
        .onAppear {
            world.addDefaultMomentsIfNeeded(for: world.selectedFamilyMember.id)
            world.ensureScenePromptsIfNeeded(for: world.selectedFamilyMember.id)
            world.isFamilyChatExpanded = initialChatExpanded
            isComposerCallTrayExpanded = initialCallTrayExpanded
        }
        .onChange(of: world.selectedFamilyMemberID) { _, newValue in
            world.addDefaultMomentsIfNeeded(for: newValue)
            world.ensureScenePromptsIfNeeded(for: newValue)
            world.isFamilyChatExpanded = false
            isComposerCallTrayExpanded = false
        }
        .sheet(isPresented: $showFamilyManager) {
            FamilyManagementSheet()
                .environment(world)
        }
    }

    private func contactSection(world: WorldModel) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text("联系人")
                    .font(.headline)

                Spacer()

                Picker("联系人结构", selection: $contactLayout) {
                    ForEach(FamilyContactLayout.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }

            Group {
                if contactLayout == .topology {
                    topologyContactGraph(world: world)
                        .frame(height: 220)
                } else {
                    contactRibbon(world: world)
                        .frame(height: 140)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 6)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private func contactRibbon(world: WorldModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(world.familyMembers) { member in
                    Button {
                        withAnimation(.snappy) {
                            world.selectFamilyMember(id: member.id)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(member.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text(member.relationForSelfNarrative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !member.isSelf {
                                ContactPresenceBadge(endpoint: world.contactEndpoint(for: member.id), compact: true)
                            }
                            if member.id == world.selectedFamilyMemberID {
                                Text("已选中")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.mint)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(width: 128, alignment: .leading)
                        .background(
                            member.id == world.selectedFamilyMemberID
                                ? Color.mint.opacity(0.22)
                                : Color(uiColor: .secondarySystemFill),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                }

                Button {
                    var newMember = FamilyMember.empty()
                    newMember.relationship = "家人"
                    world.upsertFamilyMember(newMember)
                    world.selectFamilyMember(id: newMember.id)
                } label: {
                    Label("新增家人", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color(uiColor: .systemFill), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
    }

    private func topologyContactGraph(world: WorldModel) -> some View {
        let selfMember = world.familyMembers.first(where: { $0.isSelf })
        let others = world.familyMembers.filter { !$0.isSelf }
        let edges = world.networkRelationEdges
        let membersByID = Dictionary(uniqueKeysWithValues: world.familyMembers.map { ($0.id, $0) })

        return GeometryReader { geometry in
            if others.isEmpty {
                HStack {
                    Text("先新增家人，显示关系拓扑")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    addFamilyMemberButton(world: world)
                }
                .padding(.horizontal, 8)
                .padding(.top, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else if let selfMember {
                let center = CGPoint(x: geometry.size.width * 0.5, y: geometry.size.height * 0.42)
                let addNodeOffset = CGPoint(x: 0.82, y: 0.16)
                let layout = topologyLayout(for: others, size: geometry.size, center: center)

                ZStack {
                    Canvas { context, size in
                        let selfPoint = CGPoint(x: center.x, y: center.y)

                        for edge in edges {
                            guard let targetLayout = layout[edge.targetMemberID] else { continue }
                            let source = topologySourcePoint(from: selfPoint, to: targetLayout.point)
                            let path = topologyFoldedPath(from: source, to: targetLayout.point, row: targetLayout.row)

                            context.stroke(
                                path,
                                with: .color(Color(uiColor: .systemGray4)),
                                style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
                            )
                        }

                        let addPoint = CGPoint(
                            x: geometry.size.width * addNodeOffset.x,
                            y: geometry.size.height * addNodeOffset.y
                        )
                        let addPath = topologyFoldedPath(
                            from: topologySourcePoint(from: selfPoint, to: addPoint),
                            to: addPoint,
                            row: layout.count + 1
                        )
                        context.stroke(
                            addPath,
                            with: .color(.orange.opacity(0.7)),
                            style: StrokeStyle(lineWidth: 1.0, dash: [4, 5])
                        )
                    }

                    if let selfNode = membersByID[selfMember.id] {
                        familyTopologyNode(
                            member: selfNode,
                            isSelected: selfNode.id == world.selectedFamilyMemberID,
                            in: center,
                            isSelf: true
                        )
                    }

                    ForEach(others) { member in
                            if let layoutNode = layout[member.id] {
                            familyTopologyNode(
                                member: member,
                                isSelected: member.id == world.selectedFamilyMemberID,
                                in: layoutNode.point,
                                isSelf: false,
                                relationLabel: world.networkRelationEdges.first(where: { $0.targetMemberID == member.id })?.relationLabel,
                                endpoint: world.contactEndpoint(for: member.id),
                                issueCount: world.openIssueCount(for: member.id)
                            ) {
                                withAnimation(.snappy) {
                                    world.selectFamilyMember(id: member.id)
                                }
                            }
                        }
                    }

                    let addPoint = CGPoint(x: geometry.size.width * addNodeOffset.x, y: geometry.size.height * addNodeOffset.y)
                    addFamilyMemberGraphButton(in: addPoint) {
                        var newMember = FamilyMember.empty()
                        newMember.relationship = "家人"
                        world.upsertFamilyMember(newMember)
                        world.selectFamilyMember(id: newMember.id)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(6)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func topologyLayout(
        for members: [FamilyMember],
        size: CGSize,
        center: CGPoint
    ) -> [String: TopologyLayout] {
        let sorted = members.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        var positions: [String: TopologyLayout] = [:]
        guard !sorted.isEmpty else { return positions }

        let maxColumns = max(1, Int((size.width - 48) / 130))
        let columns = min(max(1, maxColumns), sorted.count)
        let visibleRows = (sorted.count + columns - 1) / columns
        let rowGap = max(48, min(size.height * 0.2, size.height / CGFloat(max(visibleRows, 1) + 1)))
        let availableWidth = max(size.width - 24, 120)
        let rowInset: CGFloat = 16
        let rowWidth = availableWidth - rowInset * 2
        let baselineY = min(center.y + 74, max(88, size.height * 0.5))
        let maxY = size.height - 34

        for (index, member) in sorted.enumerated() {
            let row = index / columns
            let col = index % columns
            let rowStart = row * columns
            let rowCount = min(columns, sorted.count - rowStart)
            let layoutCol = (row % 2 == 0) ? col : (rowCount - 1 - col)

            let x: CGFloat
            if rowCount == 1 {
                if sorted.count == 1 {
                    x = center.x + min(size.width * 0.16, 60)
                } else {
                    x = center.x
                }
            } else {
                x = rowInset + rowWidth * (CGFloat(layoutCol + 1) / CGFloat(rowCount + 1))
            }

            let y = min(baselineY + CGFloat(row) * rowGap, maxY)
            positions[member.id] = TopologyLayout(point: CGPoint(x: x, y: y), row: row, index: index)
        }
        return positions
    }

    private func topologyFoldedPath(from source: CGPoint, to target: CGPoint, row: Int) -> Path {
        let railDirection: CGFloat = row.isMultiple(of: 2) ? 1 : -1
        let railOffset = 38 + CGFloat(row) * 11
        let foldY = max(source.y + 22, min(target.y - 12, source.y + 32 + CGFloat(row) * 10))
        let foldX = target.x + (railDirection * min(railOffset, 72))

        var path = Path()
        path.move(to: source)
        path.addLine(to: CGPoint(x: source.x, y: foldY))
        if abs(foldX - source.x) > 4 {
            path.addLine(to: CGPoint(x: foldX, y: foldY))
        }
        if abs(target.y - foldY) > 4 {
            path.addLine(to: CGPoint(x: foldX, y: target.y))
        }
        path.addLine(to: target)
        return path
    }

    private func topologySourcePoint(from source: CGPoint, to target: CGPoint) -> CGPoint {
        let lateralOffset: CGFloat = target.x >= source.x ? 14 : -14
        return CGPoint(
            x: source.x + lateralOffset,
            y: source.y + 26
        )
    }

    private func addFamilyMemberButton(world: WorldModel) -> some View {
        Button {
            var newMember = FamilyMember.empty()
            newMember.relationship = "家人"
            world.upsertFamilyMember(newMember)
            world.selectFamilyMember(id: newMember.id)
        } label: {
            Label("新增家人", systemImage: "plus.circle.fill")
                .font(.subheadline)
                .padding(10)
                .background(Color(uiColor: .systemFill), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func addFamilyMemberGraphButton(in point: CGPoint, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.25))
                    .frame(width: 34, height: 34)
                Image(systemName: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.orange)
            }
            .overlay {
                Text("新增\n家人")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .offset(y: 26)
            }
        }
        .buttonStyle(.plain)
        .position(point)
    }

    private func familyTopologyNode(
        member: FamilyMember,
        isSelected: Bool,
        in point: CGPoint,
        isSelf: Bool,
        relationLabel: String? = nil,
        endpoint: ContactConversationEndpoint? = nil,
        issueCount: Int = 0,
        onTap: (() -> Void)? = nil
    ) -> some View {
        let radius: CGFloat = isSelf ? 30 : 30

        return Button(action: onTap ?? {}) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(isSelf ? Color.mint.opacity(0.38) : (isSelected ? Color.blue.opacity(0.2) : Color(uiColor: .systemFill)))
                        .frame(width: radius * (isSelf ? 2.35 : 2), height: radius * (isSelf ? 2.35 : 2))

                    if isSelf {
                        Text("我")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                    } else if issueCount > 0 {
                        Text("\(issueCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.thinMaterial, in: Capsule())
                            .offset(x: radius * 0.45, y: -radius * 0.55)
                    }
                }

                Text(member.name)
                    .font(isSelf ? .caption.weight(.semibold) : .caption2.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, isSelf ? 8 : 0)
                    .padding(.vertical, isSelf ? 2 : 0)
                    .background(
                        isSelf
                            ? Color(uiColor: .systemBackground).opacity(0.94)
                            : .clear,
                        in: Capsule()
                    )

                if let relationLabel {
                    Text(relationLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let endpoint {
                    ContactPresenceBadge(endpoint: endpoint, compact: true)
                }
            }
            .padding(4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .position(point)
    }

    private func compactChatPanel(world: WorldModel) -> some View {
        VStack(spacing: 8) {
            chatHeader(world: world, expanded: false)
            chatStrategyBanner(world: world, expanded: false)
            issueQueue(world: world, expanded: false)
            chatScroller(world: world, expanded: false)
            messageComposer(world: world, compact: true)
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(14)
        .animation(.easeInOut(duration: 0.2), value: world.isFamilyChatExpanded)
    }

    private func expandedChatPanel(world: WorldModel) -> some View {
        VStack(spacing: 10) {
            chatHeader(world: world, expanded: true)
            chatStrategyBanner(world: world, expanded: true)
            issueQueue(world: world, expanded: true)
            chatScroller(world: world, expanded: true)
            messageComposer(world: world, compact: false)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(14)
        .layoutPriority(1)
        .animation(.easeInOut(duration: 0.2), value: world.isFamilyChatExpanded)
    }

    private func chatHeader(world: WorldModel, expanded: Bool) -> some View {
        let selectedMember = world.selectedFamilyMember
        let actionSize: CGFloat = 26
        let expandedActionHeight: CGFloat = 26

        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(selectedMember.name)
                        .font(expanded ? .title3.weight(.semibold) : .headline)

                    if selectedMember.isSelf {
                        Text("我")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(4)
                            .background(Color(uiColor: .systemFill), in: Capsule())
                    }

                    if expanded {
                        if selectedMember.isBirthdayToday() {
                            Text("今天是生日")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.pink)
                        } else if selectedMember.isWeeklyChatDue() {
                            Text("固定沟通日")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.blue)
                        }
                    }
                }

                Text(selectedMember.relationForSelfNarrative)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !selectedMember.isSelf {
                    ContactPresenceBadge(endpoint: world.contactEndpoint(for: selectedMember.id), compact: false)
                } else {
                    Text("当前：\(world.effectiveSelfProxyMode.rawValue)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if expanded {
                    if let birthday = selectedMember.birthday {
                        Text("生日：\(birthday.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Text("固定聊天：\(selectedMember.weeklyChatLabel)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .center, spacing: expanded ? 2 : 4) {
                Spacer(minLength: 0)
                if expanded {
                    HStack(spacing: 6) {
                        Button {
                            world.isFamilyChatExpanded = false
                        } label: {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                        }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.roundedRectangle)
                            .controlSize(.mini)
                            .labelStyle(.iconOnly)
                            .font(.caption)
                            .frame(height: expandedActionHeight)
                            .frame(width: actionSize, height: actionSize)

                        if selectedMember.isSelf {
                            Menu {
                                ForEach(SelfProxyMode.allCases, id: \.self) { mode in
                                    Button(mode.rawValue) {
                                        world.setSelfProxyMode(mode)
                                    }
                                }
                            } label: {
                                Image(systemName: "person.crop.circle.badge.checkmark")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.mint)
                            .controlSize(.mini)
                            .labelStyle(.iconOnly)
                            .frame(height: expandedActionHeight)
                            .frame(width: actionSize, height: actionSize)
                        } else {
                            Menu {
                                Section("对方状态") {
                                    ForEach(ContactConversationEndpoint.allCases, id: \.self) { endpoint in
                                        Button(endpoint.presenceTitle) {
                                            world.setContactEndpoint(for: selectedMember.id, to: endpoint)
                                        }
                                    }
                                }
                                Section("沟通") {
                                    Button("模拟来信", systemImage: "arrow.down.message") {
                                        world.simulateIncomingMessage(from: selectedMember.id)
                                    }
                                    Button("语音", systemImage: "phone.fill") {
                                        startCommunication(isVideo: false, member: selectedMember)
                                    }
                                    Button("视频", systemImage: "video.fill") {
                                        startCommunication(isVideo: true, member: selectedMember)
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .labelStyle(.iconOnly)
                            .frame(height: expandedActionHeight)
                            .frame(width: actionSize, height: actionSize)
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        Button {
                            world.isFamilyChatExpanded = true
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle)
                        .controlSize(.mini)
                        .frame(height: expandedActionHeight)
                        .frame(width: actionSize, height: actionSize)

                        if selectedMember.isSelf {
                            Menu {
                                ForEach(SelfProxyMode.allCases, id: \.self) { mode in
                                    Button(mode.rawValue) {
                                        world.setSelfProxyMode(mode)
                                    }
                                }
                            } label: {
                                Image(systemName: "person.crop.circle.badge.checkmark")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .labelStyle(.iconOnly)
                            .frame(height: expandedActionHeight)
                            .frame(width: actionSize, height: actionSize)
                        } else {
                            Menu {
                                Button("模拟来信", systemImage: "arrow.down.message") {
                                    world.simulateIncomingMessage(from: selectedMember.id)
                                }
                                Button("语音", systemImage: "phone.fill") {
                                    startCommunication(isVideo: false, member: selectedMember)
                                }
                                Button("视频", systemImage: "video.fill") {
                                    startCommunication(isVideo: true, member: selectedMember)
                                }
                                Divider()
                                ForEach(ContactConversationEndpoint.allCases, id: \.self) { endpoint in
                                    Button(endpoint.presenceTitle) {
                                        world.setContactEndpoint(for: selectedMember.id, to: endpoint)
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .labelStyle(.iconOnly)
                            .frame(height: expandedActionHeight)
                            .frame(width: actionSize, height: actionSize)
                        }
                    }
                }
            }
        }
    }

    private func chatStrategyBanner(world: WorldModel, expanded: Bool) -> some View {
        let selectedMember = world.selectedFamilyMember
        let issueCount = selectedMember.isSelf ? world.openAgentIssueCount : world.openIssueCount(for: selectedMember.id)

        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: selectedMember.isSelf ? "brain.head.profile" : "point.3.connected.trianglepath.dotted")
                .font(.headline)
                .foregroundStyle(.mint)

            VStack(alignment: .leading, spacing: 4) {
                if selectedMember.isSelf {
                    Text("你的数字分身在前台社交")
                        .font(.subheadline.weight(.semibold))
                    Text(world.isSelfProxyFullyDelegated
                         ? "你已经较长时间未登录，数字分身已进入全托管模式，自动处理外部对话。"
                         : world.effectiveSelfProxyMode.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("分身社交链路")
                        .font(.subheadline.weight(.semibold))
                    Text("对方当前为 \(world.contactEndpoint(for: selectedMember.id).presenceTitle)；你的一侧当前是 \(world.effectiveSelfProxyMode.rawValue)。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if issueCount > 0 {
                    Text("待确认 issue：\(issueCount)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            if expanded {
                if selectedMember.isSelf && !world.isSelfProxyFullyDelegated {
                    Button("本人接管") {
                        world.setSelfProxyMode(.human)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                } else if !selectedMember.isSelf {
                    Button("模拟来信") {
                        world.simulateIncomingMessage(from: selectedMember.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func issueQueue(world: WorldModel, expanded: Bool) -> some View {
        let selectedMember = world.selectedFamilyMember
        let issues = selectedMember.isSelf ? world.openAgentIssues : world.issues(for: selectedMember.id).filter { $0.status == .open }

        if !issues.isEmpty {
            let displayedIssues = expanded ? Array(issues.prefix(3)) : Array(issues.prefix(1))
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("待本人确认")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(issues.count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.orange)
                }

                ForEach(displayedIssues) { issue in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(issue.prompt)
                            .font(.caption)
                            .lineLimit(expanded ? 3 : 2)
                        Text("建议回复：\(issue.suggestedReply)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(expanded ? 3 : 2)

                        if expanded {
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

                                Button("忽略") {
                                    world.dismissIssue(issue.id)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(10)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func chatScroller(world: WorldModel, expanded: Bool) -> some View {
        let displayedMessages = expanded
            ? world.messagesForSelectedMember
            : Array(world.messagesForSelectedMember.suffix(4))

        return VStack(alignment: .leading, spacing: 8) {
            if expanded {
                HStack {
                    Text("聊天记录（\(world.messagesForSelectedMember.count)）")
                        .font(.caption.weight(.bold))
                    Spacer()
                    if world.messagesForSelectedMember.isEmpty {
                        Text("先发消息创建对话")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("最近对话")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                if displayedMessages.isEmpty {
                    Text("还没有聊天记录，先发条消息打个招呼吧")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(20)
                } else {
                    ForEach(displayedMessages) { message in
                        MessageBubble(message: message)
                    }
                }
            }
            .frame(minHeight: expanded ? 220 : 120, maxHeight: expanded ? .infinity : 150)
            .padding(8)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func messageComposer(world: WorldModel, compact: Bool) -> some View {
        let composerHeight: CGFloat = 28

        return VStack(alignment: .trailing, spacing: 6) {
            if isComposerCallTrayExpanded, !world.selectedFamilyMember.isSelf {
                HStack(spacing: 6) {
                    Button {
                        startCommunication(isVideo: false, member: world.selectedFamilyMember)
                        isComposerCallTrayExpanded = false
                    } label: {
                        Label("语音", systemImage: "phone.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.mini)

                    Button {
                        startCommunication(isVideo: true, member: world.selectedFamilyMember)
                        isComposerCallTrayExpanded = false
                    } label: {
                        Label("视频", systemImage: "video.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.mini)
                }
                .font(.caption2.weight(.semibold))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: 6) {
                TextField(world.selectedFamilyMember.isSelf ? "给数字分身下达指令" : "给 \(world.selectedFamilyMember.name) 发送消息", text: $messageDraft)
                    .textFieldStyle(.roundedBorder)
                    .focused($isComposerFocused)
                    .frame(height: composerHeight)

                if !world.selectedFamilyMember.isSelf {
                    Button {
                        withAnimation(.snappy) {
                            isComposerCallTrayExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isComposerCallTrayExpanded ? "xmark" : "phone.badge.waveform")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .labelStyle(.iconOnly)
                    .frame(width: composerHeight, height: composerHeight)
                }

                Button {
                    sendCurrentMessage(world: world)
                } label: {
                    Text(world.selectedFamilyMember.isSelf ? "下发" : "发送")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
                .font(.caption2)
                .frame(height: composerHeight)
                .disabled(messageDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func sendCurrentMessage(world: WorldModel) {
        let text = messageDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        world.touchHumanPresence()
        world.sendMessage(to: world.selectedFamilyMember.id, text: text)
        messageDraft = ""
        isComposerCallTrayExpanded = false
        isComposerFocused = false
    }

    private func startCommunication(isVideo: Bool, member: FamilyMember) {
        guard !member.isSelf else {
            world.appendSystemMessage(member.id, text: "不能对自己发起通话，先选择其他家庭成员")
            return
        }

        let type = isVideo ? "视频" : "语音"
        if !member.hasContact {
            world.appendSystemMessage(member.id, text: "\(member.name) 未设置联系方式，先在家人管理补充电话或 FaceTime 账号")
            return
        }

        let digits = member.phoneNumber.filter { $0.isNumber }
        if let url = URL(string: "\(isVideo ? "facetime" : "facetime-audio")://\(digits)") {
            openURL(url)
            world.appendSystemMessage(member.id, text: "已发起\(type)沟通")
        } else {
            world.appendSystemMessage(member.id, text: "联系方式格式不正确")
        }
    }
}

private struct ContactPresenceBadge: View {
    let endpoint: ContactConversationEndpoint
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 3 : 5) {
            Image(systemName: endpoint.presenceSymbol)
                .font(compact ? .caption2.weight(.bold) : .caption2.weight(.semibold))
            Text(endpoint.presenceTitle)
                .font(compact ? .caption2.weight(.semibold) : .caption2.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(endpoint.presenceColor)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 2 : 4)
        .background(endpoint.presenceColor.opacity(0.14), in: Capsule())
        .accessibilityLabel("对方状态：\(endpoint.presenceTitle)")
    }
}

private extension ContactConversationEndpoint {
    var presenceTitle: String {
        switch self {
        case .localAgent:
            "本机模拟"
        case .remoteAgent:
            "对方在线"
        case .humanUser:
            "真人在线"
        case .humanOffline:
            "真人离线"
        }
    }

    var presenceSymbol: String {
        switch self {
        case .localAgent:
            "desktopcomputer"
        case .remoteAgent:
            "checkmark.icloud.fill"
        case .humanUser:
            "person.fill.checkmark"
        case .humanOffline:
            "person.fill.xmark"
        }
    }

    var presenceColor: Color {
        switch self {
        case .localAgent:
            .teal
        case .remoteAgent, .humanUser:
            .green
        case .humanOffline:
            .red
        }
    }
}

private struct MessageBubble: View {
    let message: FamilyMessage

    var body: some View {
        HStack {
            if message.isFromSelf {
                Spacer()
            }

            Text(message.text)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(message.isFromSelf ? Color.mint.opacity(0.3) : Color(uiColor: .systemFill), in: RoundedRectangle(cornerRadius: 10))
                .frame(maxWidth: 250, alignment: message.isFromSelf ? .trailing : .leading)
                .overlay(alignment: .bottomTrailing) {
                    Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .offset(y: 8)
                }

            if !message.isFromSelf {
                Spacer()
            }
        }
    }
}

private struct FamilyManagementSheet: View {
    @Environment(WorldModel.self) private var world
    @Environment(\.dismiss) private var dismiss
    @State private var editingMember: FamilyMember?
    @State private var name = ""
    @State private var relationship = ""
    @State private var phone = ""
    @State private var weekday = 2
    @State private var time = "20:00"
    @State private var birthday: Date = Date()
    @State private var hasBirthday = false
    @State private var activeRole: FamilyRolePreset = .mother
    @State private var endpoint: ContactConversationEndpoint = .localAgent

    var body: some View {
        NavigationStack {
            Form {
                Section("家庭成员") {
                    ForEach(world.familyMembers) { member in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(member.name)
                                .font(.headline)
                            Text(member.relationship)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !member.isSelf {
                                Text("固定聊天：\(member.weeklyChatLabel)")
                                    .font(.caption2)
                            }
                            HStack {
                                Button("编辑") {
                                    editingMember = member
                                    editTemplate(from: member)
                                }
                                .buttonStyle(.bordered)

                                if !member.isSelf {
                                    Button("移除", role: .destructive) {
                                        world.deleteFamilyMember(member.id)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }

                    Button("新增家人") {
                        editingMember = FamilyMember.empty()
                        editTemplate(from: editingMember!)
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let editing = editingMember {
                    Section("成员信息") {
                        TextField("姓名", text: $name)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("关系快捷标签（第一人称）")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(FamilyRolePreset.familyDefaults + FamilyRolePreset.socialDefaults, id: \.self) { preset in
                                        Button(preset.rawValue) {
                                            relationship = preset.rawValue
                                            activeRole = preset
                                        }
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(preset == activeRole ? Color.mint.opacity(0.4) : Color.mint.opacity(0.14), in: Capsule())
                                        .foregroundStyle(preset == activeRole ? .white : .primary)
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 2)
                            }

                            TextField("关系", text: $relationship)
                                .textFieldStyle(.roundedBorder)
                        }
                        TextField("联系方式", text: $phone)
                            .keyboardType(.phonePad)

                        if !editing.isSelf {
                            Picker("对方状态", selection: $endpoint) {
                                ForEach(ContactConversationEndpoint.allCases, id: \.self) { item in
                                    Text(item.presenceTitle).tag(item)
                                }
                            }

                            Text(endpoint.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Toggle("设置生日", isOn: $hasBirthday)
                        if hasBirthday {
                            DatePicker("生日", selection: $birthday, displayedComponents: .date)
                        }

                        Stepper("每周固定在第 \(weekday) 天", value: $weekday, in: 1...7)
                        TextField("时间", text: $time)
                            .textFieldStyle(.roundedBorder)

                        Button(editing.isSelf ? "保存(自己)" : "保存成员") {
                            var updated = editing
                            updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                            updated.relationship = relationship.trimmingCharacters(in: .whitespacesAndNewlines)
                            updated.phoneNumber = phone.trimmingCharacters(in: .whitespacesAndNewlines)
                            updated.cadenceDay = weekday
                            updated.cadenceTime = time
                            updated.birthday = hasBirthday ? birthday : nil
                            world.upsertFamilyMember(updated)
                            if !updated.isSelf {
                                world.setContactEndpoint(for: updated.id, to: endpoint)
                            }
                            editingMember = nil
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("家人关系维护")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .onChange(of: editingMember) { _, newValue in
            if let value = newValue {
                editTemplate(from: value)
                activeRole = rolePreset(from: value.relationship)
            }
        }
    }

    private func editTemplate(from member: FamilyMember) {
        name = member.name
        relationship = member.relationship
        phone = member.phoneNumber
        weekday = member.cadenceDay
        time = member.cadenceTime
        birthday = member.birthday ?? Date()
        hasBirthday = member.birthday != nil
        activeRole = rolePreset(from: member.relationship)
        endpoint = world.contactEndpoint(for: member.id)
    }

    private func rolePreset(from value: String) -> FamilyRolePreset {
        FamilyRolePreset(rawValue: value.trimmingCharacters(in: .whitespacesAndNewlines)) ?? .friend
    }
}

#Preview {
    NavigationStack {
        FamilyHubView()
            .environment(WorldModel.preview)
    }
}
