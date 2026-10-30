import SwiftUI
import AVKit

struct InlinePlayer: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .frame(height: 260)
            .onAppear {
                try? AVAudioSession.sharedInstance().setCategory(.playback)
                let p = AVPlayer(url: url)
                player = p
                p.play()
            }
            .onDisappear { player?.pause() }
    }
}

struct MediaView: View {
    let item: PostMedia
    @State private var playing = false

    var body: some View {
        if playing, let url = item.videoURL {
            InlinePlayer(url: url)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            thumbnail
        }
    }

    private func box(_ text: String) -> some View {
        ZStack {
            Rectangle().fill(Color.gray.opacity(0.2))
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 160)
    }

    private var image: some View {
        AsyncImage(url: item.imageURL) { phase in
            switch phase {
            case .success(let img):
                img.resizable().scaledToFit()
            case .failure:
                box("Can't load image")
            default:
                ZStack {
                    Rectangle().fill(Color.gray.opacity(0.2))
                    ProgressView()
                }
                .frame(height: 160)
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var thumbnail: some View {
        Group {
            if item.imageURL == nil {
                box("Locked")
            } else {
                image
            }
        }
        .overlay {
            if item.isVideo {
                Image(systemName: item.videoURL == nil ? "lock.fill" : "play.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                    .shadow(radius: 4)
            }
        }
        .onTapGesture {
            if item.isVideo && item.videoURL != nil {
                playing = true
            }
        }
    }
}

struct PostCard: View {
    let post: Post
    var author: Subscription? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let a = author {
                HStack(spacing: 8) {
                    AsyncImage(url: URL(string: a.avatar ?? "")) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())

                    VStack(alignment: .leading) {
                        Text(a.name).bold().font(.subheadline)
                        Text("@" + a.username)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Text(post.postedAt ?? "")
                .font(.caption)
                .foregroundColor(.secondary)

            if let text = post.rawText, !text.isEmpty {
                Text(text.strippedHTML)
            }

            ForEach(post.media ?? []) { item in
                MediaView(item: item)
            }

            let likes = String(post.favoritesCount ?? 0)
            let mediaTotal = String(post.mediaCount ?? 0)
            Text("♥ " + likes + "   •   " + mediaTotal + " media")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()
        }
    }
}