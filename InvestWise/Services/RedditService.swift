import Foundation

struct RedditPost {
    let title: String
    let selftext: String
    let score: Int
    let numComments: Int
    let permalink: String
}

final class RedditService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchTrending(subreddits: [String] = ["investing", "stocks"]) async throws -> [RedditPost] {
        var allPosts: [RedditPost] = []
        for sub in subreddits {
            let posts = try await fetchSubreddit(sub)
            allPosts.append(contentsOf: posts)
        }
        return allPosts.sorted { $0.score > $1.score }
    }

    private func fetchSubreddit(_ name: String) async throws -> [RedditPost] {
        let url = URL(string: "https://www.reddit.com/r/\(name)/hot.json?limit=10")!
        var request = URLRequest(url: url)
        request.setValue("InvestWise/1.0", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: request)
        return try Self.parseRedditResponse(data: data)
    }

    static func parseRedditResponse(data: Data) throws -> [RedditPost] {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let dataObj = json?["data"] as? [String: Any],
              let children = dataObj["children"] as? [[String: Any]]
        else { return [] }
        return children.compactMap { child in
            guard let post = child["data"] as? [String: Any],
                  let title = post["title"] as? String
            else { return nil }
            return RedditPost(title: title, selftext: post["selftext"] as? String ?? "", score: post["score"] as? Int ?? 0, numComments: post["num_comments"] as? Int ?? 0, permalink: post["permalink"] as? String ?? "")
        }
    }
}
