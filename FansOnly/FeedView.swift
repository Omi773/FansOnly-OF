import SwiftUI

struct FeedItem: Identifiable {
    let id: Int
    let sub: Subscription
    let post: Post
}

struct FeedView: View {
    let subs: [Subscription]
    @State private var items: [FeedItem] = []
    @State private var status = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                if !status.isEmpty {
                    Text(status)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding()
                }
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(items) { item in
                        PostCard(post: item.post, author: item.sub)
                    }
                }
                .padding()
            }
            .navigationTitle("Feed")
            .refreshable { await load() }
            .task(id: subs.count) { await load() }
        }
    }

    func load() async {
        let active = Array(subs.filter { $0.isActive }.prefix(6))
        if active.isEmpty {
            status = subs.isEmpty ? "Loading..." : "No active subscriptions"
            return
        }
        status = "Loading feed..."
        var all: [FeedItem] = []
        await withTaskGroup(of: [FeedItem].self) { group in
            for sub in active {
                group.addTask {
                    do {
                        let user = sub.username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? sub.username
                        let data = try await API.request("/access/users/\\(user)/posts?limit=5")
                        let decoded = try JSONDecoder().decode(PostsResponse.self, from: data)
                        return decoded.list.map { FeedItem(id: $0.id, sub: sub, post: $0) }
                    } catch {
                        return []
                    }
                }
            }
            for await result in group {
                all.append(contentsOf: result)
            }
        }
        all.sort { $0.post.sortKey > $1.post.sortKey }
        items = all
        status = all.isEmpty ? "No posts found" : ""
    }
}