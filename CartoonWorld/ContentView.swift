import SwiftUI

struct ContentView: View {
    @Environment(WorldModel.self) private var world
    @State private var selectedTab: AppTab = .world

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                WorldMapView()
                    .navigationTitle("卡通世界")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar(.hidden, for: .navigationBar)
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
            world.bootstrapIfNeeded()
        }
    }
}

private enum AppTab: Hashable {
    case world
    case upload
    case profile
}

#Preview {
    ContentView()
        .environment(WorldModel.preview)
}
