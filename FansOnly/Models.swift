import Foundation

extension String {
    var strippedHTML: String {
        self.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#039;", with: "'")
    }
}

struct MediaFile: Decodable {
    let url: String?
}

struct MediaFiles: Decodable {
    let full: MediaFile?
    let thumb: MediaFile?
    let preview: MediaFile?
}

struct VideoSources: Decodable {
    let p240: String?
    let p720: String?

    enum CodingKeys: String, CodingKey {
        case p240 = "240"
        case p720 = "720"
    }
}

struct PostMedia: Identifiable, Decodable {
    let id: Int
    let type: String?
    let canView: Bool?
    let files: MediaFiles?
    let videoSources: VideoSources?

    var isVideo: Bool { type == "video" }

    var imageURL: URL? {
        let full = files?.full?.url
        let thumb = files?.thumb?.url
        let preview = files?.preview?.url
        var chosen: String?
        if isVideo {
            chosen = thumb ?? preview ?? full
        } else if canView == true {
            chosen = full ?? thumb ?? preview
        } else {
            chosen = preview ?? thumb ?? full
        }
        guard let s = chosen, !s.isEmpty else { return nil }
        return URL(string: s)
    }

    var videoURL: URL? {
        guard canView == true else { return nil }
        let s = videoSources?.p720 ?? videoSources?.p240 ?? files?.full?.url
        guard let s = s, !s.isEmpty else { return nil }
        return URL(string: s)
    }
}

struct Post: Identifiable, Decodable {
    let id: Int
    let rawText: String?
    let postedAt: String?
    let postedAtPrecise: String?
    let favoritesCount: Int?
    let mediaCount: Int?
    let media: [PostMedia]?

    var sortKey: Double { Double(postedAtPrecise ?? "") ?? 0 }
}

struct PostsResponse: Decodable {
    let list: [Post]
}

struct ChatUserRef: Decodable {
    let id: Int
}

struct ChatLastMessage: Decodable {
    let text: String?
    let createdAt: String?
}

struct ChatSummary: Identifiable, Decodable {
    let withUser: ChatUserRef
    let unreadMessagesCount: Int?
    let lastMessage: ChatLastMessage?

    var id: Int { withUser.id }
}

struct ChatsResponse: Decodable {
    let list: [ChatSummary]
}

struct ChatMessage: Identifiable, Decodable {
    let id: Int
    let text: String?
    let fromUser: ChatUserRef?
    let media: [PostMedia]?
    let createdAt: String?
}

struct ChatMessagesResponse: Decodable {
    let list: [ChatMessage]
    let hasMore: Bool?
    let nextLastId: String?
}
