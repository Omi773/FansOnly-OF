import SwiftUI

struct ChatsView: View {
    let subs: [Subscription]
    @State private var chats: [ChatSummary] = []
    @State private var status = "Loading chats..."

    func name(for id: Int) -> String {
        subs.first(where: { $0.id == id })?.name ?? ("User " + String(id))
    }

    func avatar(for id: Int) -> some View {
        AsyncImage(url: URL(string: subs.first(where: { $0.id == id })?.avatar ?? "")) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Circle().fill(Color.gray.opacity(0.3))
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }

    var body: some View {
        NavigationStack {
            List(chats) { chat in
                NavigationLink {
                    ChatView(userId: chat.id, name: name(for: chat.id))
                } label: {
                    HStack(spacing: 12) {
                        avatar(for: chat.id)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name(for: chat.id)).bold()
                            Text((chat.lastMessage?.text ?? "").strippedHTML)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if (chat.unreadMessagesCount ?? 0) > 0 {
                            Text(String(chat.unreadMessagesCount ?? 0))
                                .font(.caption)
                                .padding(6)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                        }
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if !status.isEmpty {
                    Text(status).foregroundColor(.secondary)
                }
            }
            .navigationTitle("Chats")
            .refreshable { await load() }
            .task { await load() }
        }
    }

    func load() async {
        do {
            let data = try await API.request("/access/chats?limit=20")
            let decoded = try JSONDecoder().decode(ChatsResponse.self, from: data)
            chats = decoded.list
            status = decoded.list.isEmpty ? "No chats yet" : ""
        } catch {
            status = error.localizedDescription
        }
    }
}

struct ChatView: View {
    let userId: Int
    let name: String
    @State private var messages: [ChatMessage] = []
    @State private var hasMore = false
    @State private var cursor: String?
    @State private var status = ""
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 8) {
                    if hasMore {
                        Button("Load older messages") {
                            Task { await load(older: true) }
                        }
                        .font(.footnote)
                    }
                    ForEach(messages) { message in
                        bubble(message)
                    }
                }
                .padding()
            }

            if !status.isEmpty {
                Text(status)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }

            HStack {
                TextField("Message", text: $draft)
                    .textFieldStyle(.roundedBorder)
                Button("Send") {
                    Task { await send() }
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load(older: false) }
    }

    func bubble(_ message: ChatMessage) -> some View {
        let mine = message.fromUser.map { $0.id != userId } ?? false
        return HStack {
            if mine { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 6) {
                if let text = message.text, !text.isEmpty {
                    Text(text.strippedHTML)
                }
                ForEach(message.media ?? []) { item in
                    MediaView(item: item)
                }
            }
            .padding(10)
            .background(mine ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            if !mine { Spacer(minLength: 40) }
        }
    }

    func load(older: Bool) async {
        do {
            var path = "/access/chats/" + String(userId) + "/messages?limit=10"
            if older, let c = cursor,
               let enc = c.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                path += "&cursor=" + enc
            }
            let data = try await API.request(path)
            let decoded = try JSONDecoder().decode(ChatMessagesResponse.self, from: data)
            var merged = older ? messages + decoded.list : decoded.list
            var seen = Set<Int>()
            merged = merged.filter { seen.insert($0.id).inserted }
            messages = merged.sorted { $0.id < $1.id }
            hasMore = decoded.hasMore ?? false
            cursor = decoded.nextLastId
            status = messages.isEmpty ? "No messages yet" : ""
        } catch {
            status = error.localizedDescription
        }
    }

    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return }
        do {
            _ = try await API.request("/access/chats/" + String(userId) + "/messages", method: "POST", body: ["text": text])
            draft = ""
            await load(older: false)
        } catch {
            status = error.localizedDescription
        }
    }
}