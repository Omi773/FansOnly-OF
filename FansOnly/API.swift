import Foundation

enum APIError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self {
        case .message(let m): return m
        }
    }
}

enum API {
    static let base = "https://fansonly-proxy.omishkdr.workers.dev"

    static var connectionId: String? {
        UserDefaults.standard.string(forKey: "connectionId")
    }

    static func request(_ path: String, method: String = "GET", body: [String: Any]? = nil) async throws -> Data {
        guard let id = connectionId else { throw APIError.message("Not connected") }
        guard let url = URL(string: base + path) else { throw APIError.message("Bad address") }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(id, forHTTPHeaderField: "x-connection-id")
        if let body = body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code < 200 || code >= 300 {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw APIError.message("Error \(code): \(text.prefix(150))")
        }
        return data
    }
}
