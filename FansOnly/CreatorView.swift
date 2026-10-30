import SwiftUI

struct CreatorView: View {
    let sub: Subscription

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

                Text("Posts will show here soon")
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle(sub.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}