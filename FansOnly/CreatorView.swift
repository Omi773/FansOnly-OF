import SwiftUI

struct Post: Identifiable, Decodable {
    let id: Int
    let rawText: String?
    let postedAt: String?
    let favoritesCount: Int?
    let mediaCount: Int?
}

struct PostsResponse: Decodable {
    let list: [Post]
}

struct CreatorView: View {
    let sub: Subscription
    @State private var posts: [Post] = []
    @State private var status = "Loading posts..."
    private let base = "https://fansonly-proxy.omishkdr.workers.dev"

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                AsyncImage(url: URL(string: sub.avatar ?? "")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())

                Text(sub.name)
                    .font(.title)
                    .bold()

                Text("@\(sub.username)")
                    .foregroundColor(.secondary)

                Text(sub.isActive ? "Subscription active" : "Subscription expired")
                    .font(.footnote)
                    .foregroundColor(sub.isActive ? .green : .secondary)

                if let price = sub.subscriptionPrice {
                    Text(price == 0 ? "Free" : String(format: "$%.2f / month", price))
                        .font(.footnote)
                }

                Divider()

                if !status.isEmpty {
                    Text(status)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(posts) { post in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(post.postedAt ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let text = post.rawText, !text.isEmpty {
                                Text(text)
                            }
                            Text("♥ \(post.favoritesCount ?? 0)   •   \(post.mediaCount ?? 0) media")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Divider()
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(sub.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadPosts() }
    }

    func loadPosts() async {
        guard let id = UserDefaults.standard.string(forKey: "connectionId") else {
            status = "Not connected"
            return
        }
        do {
            let user = sub.username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? sub.username
            var req = URLRequest(url: URL(string: base + "/access/users/\(user)/posts?limit=20")!)
            req.setValue(id, forHTTPHeaderField: "x-connection-id")
            let (data, response) = try await URLSession.shared.data(for: req)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code != 200 {
                let text = String(data: data, encoding: .utf8) ?? ""
                status = "Error \(code): \(text.prefix(150))"
                return
            }
            let decoded = try JSONDecoder().decode(PostsResponse.self, from: data)
            posts = decoded.list
            status = decoded.list.isEmpty ? "No posts found" : ""
        } catch {
            status = "Error: \(error.localizedDescription)"
        }
    }
}