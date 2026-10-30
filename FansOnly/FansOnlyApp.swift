import SwiftUI

@main
struct FansOnlyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("FansOnly")
                .font(.largeTitle)
                .bold()
            Button("Connect account") {
                // Login will be added in a later step
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
