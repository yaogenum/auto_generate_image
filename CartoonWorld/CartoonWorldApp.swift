import SwiftUI

@main
struct CartoonWorldApp: App {
    @State private var world = WorldModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(world)
        }
    }
}
