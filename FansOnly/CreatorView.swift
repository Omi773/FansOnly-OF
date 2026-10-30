import SwiftUI

struct CreatorView: View {
    let sub: Subscription
    @State private var posts: [Post] = []
    @State private var status = "Loading posts..."

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

                Text("@" + sub.username)
                    .foregroundColor(.secondary)

                Text(sub.isActive ? "Subscription active" : "Subscription expired")
                    .font(.footnote)
                    .foregroundColor(sub.isActive ? .green : .secondary)

                if let price = sub.subscriptionPrice {
                    Text(price == 0 ? "Free" : String(format: "$%.2f / month", price))
                        .font(.footnote)
                }

                NavigationLink {
                    ChatView(userId: sub.id, name: sub.name)
                } label: {
                    Label("Message", systemImage: "message")
                }
                .buttonStyle(.bordered)

                Divider()

                if !status.isEmpty {
                    Text(status)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(posts) { post in
                        PostCard(post: post)
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
        do {
            let user = sub.username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? sub.username
            let data = try await API.request("/access/users/\\(user)/posts?limit=20")
            let decoded = try JSONDecoder().decode(PostsResponse.self, from: data)
            posts = decoded.list
            status = decoded.list.isEmpty ? "No posts found" : ""
        } catch {
            status = error.localizedDescription
        }
    }
}
