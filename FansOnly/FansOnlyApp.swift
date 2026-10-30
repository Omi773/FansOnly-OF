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

struct Subscription: Identifiable, Decodable {
    let id: Int
    let username: String
    let name: String
    let avatar: String?
    let isActive: Bool
    let subscriptionPrice: Double?
}

struct SubscriptionsResponse: Decodable {
    let list: [Subscription]
}

class LoginModel: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    @Published var connectionId: String? = UserDefaults.standard.string(forKey: "connectionId")
    @Published var message = ""
    @Published var subs: [Subscription] = []
    private var authSession: ASWebAuthenticationSession?
    private let base = "https://fansonly-proxy.omishkdr.workers.dev"

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap { $0.windows }.first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
    }

    func loadAccount() {
        guard let id = connectionId else { return }
        message = "Loading..."
        Task {
            do {
                var req = URLRequest(url: URL(string: base + "/access/self")!)
                req.setValue(id, forHTTPHeaderField: "x-connection-id")
                let (data, _) = try await URLSession.shared.data(for: req)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let name = json?["name"] as? String ?? "?"
                await MainActor.run { self.message = "Hello \(name)" }
            } catch {
                await MainActor.run { self.message = "Error: \(error.localizedDescription)" }
            }
        }
    }

    func loadSubscriptions() {
        guard let id = connectionId else { return }
        message = "Loading subscriptions..."
        Task {
            do {
                var req = URLRequest(url: URL(string: base + "/access/subscriptions?type=all&limit=50")!)
                req.setValue(id, forHTTPHeaderField: "x-connection-id")
                let (data, response) = try await URLSession.shared.data(for: req)
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                if code != 200 {
                    let text = String(data: data, encoding: .utf8) ?? ""
                    await MainActor.run { self.message = "Error \(code): \(text.prefix(150))" }
                    return
                }
                let decoded = try JSONDecoder().decode(SubscriptionsResponse.self, from: data)
                await MainActor.run {
                    self.subs = decoded.list
                    self.message = decoded.list.isEmpty ? "No subscriptions found" : ""
                }
            } catch {
                await MainActor.run { self.message = "Error: \(error.localizedDescription)" }
            }
        }
    }

    func disconnect() {
        UserDefaults.standard.removeObject(forKey: "connectionId")
        connectionId = nil
        subs = []
        message = ""
    }

    func connect() {
        message = "Starting login..."
        Task {
            do {
                var req = URLRequest(url: URL(string: base + "/link")!)
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
                    self.message = ""
                    self.loadSubscriptions()
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
        NavigationStack {
            VStack(spacing: 12) {
                Text("FansOnly")
                    .font(.largeTitle)
                    .bold()

                if model.connectionId == nil {
                    Button("Connect account") { model.connect() }
                        .buttonStyle(.borderedProminent)
                } else {
                    HStack {
                        Button("Load my account") { model.loadAccount() }
                        Button("Subscriptions") { model.loadSubscriptions() }
                        Button("Log out") { model.disconnect() }
                    }
                    .buttonStyle(.bordered)
                    .font(.footnote)

                    List(model.subs) { sub in
                        NavigationLink {
                            CreatorView(sub: sub)
                        } label: {
                            HStack(spacing: 12) {
                                AsyncImage(url: URL(string: sub.avatar ?? "")) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Circle().fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())

                                VStack(alignment: .leading) {
                                    Text(sub.name).bold()
                                    Text("@\(sub.username)")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(sub.isActive ? "Active" : "Expired")
                                    .font(.caption)
                                    .foregroundColor(sub.isActive ? .green : .secondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                }

                Text(model.message)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}