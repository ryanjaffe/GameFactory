import SwiftUI

@main
struct GodotGameFactoryApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: viewModel)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowResizability(.contentSize)
    }
}
