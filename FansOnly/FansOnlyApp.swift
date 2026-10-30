import SwiftUI
import AuthenticationServices

@main
struct FansOnlyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class LoginModel: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    @Published var connectionId: String? = UserDefaults.standard.string(forKey: "connectionId")
    @Published var message = ""
    private var authSession: ASWebAuthenticationSession?

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap { $0.windows }.first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
    }

    func connect() {
        message = "Starting login..."
        Task {
            do {
                var req = URLRequest(url: URL(string: "https://fansonly-proxy.omishkdr.workers.dev/link")!)
                req.httpMethod = "POST"
                let (data, _) = try await URLSession.shared.data(for: req)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let urlString = json?["url"] as? String, let url = URL(string: urlString) else {
                    await MainActor.run { self.message = "Could not get login link" }
                    return
                }
                await MainActor.run { self.start(url) }
            } catch {
                await MainActor.run { self.message = "Error: \(error.localizedDescription)" }
            }
        }
    }

    private func start(_ url: URL) {
        let s = ASWebAuthenticationSession(url: url, callbackURLScheme: "fansonly") { callback, error in
            DispatchQueue.main.async {
                if error != nil {
                    self.message = "Login cancelled"
                    return
                }
                guard let callback = callback,
                      let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems else {
                    self.message = "No response"
                    return
                }
                let status = items.first(where: { $0.name == "status" })?.value
                if status == "success",
                   let id = items.first(where: { $0.name == "connection_id" })?.value {
                    UserDefaults.standard.set(id, forKey: "connectionId")
                    self.connectionId = id
                    self.message = "Connected!"
                } else {
                    self.message = "Login not completed (\(status ?? "unknown"))"
                }
            }
        }
        s.presentationContextProvider = self
        authSession = s
        s.start()
    }
}

struct ContentView: View {
    @StateObject private var model = LoginModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("FansOnly")
                .font(.largeTitle)
                .bold()
            if model.connectionId == nil {
                Button("Connect account") { model.connect() }
                    .buttonStyle(.borderedProminent)
            } else {
                Text("Account connected")
                    .foregroundColor(.green)
            }
            Text(model.message)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}