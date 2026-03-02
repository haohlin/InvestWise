import Foundation

struct RedditPost {
    let title: String
    let selftext: String
    let score: Int
    let numComments: Int
    let permalink: String
    let subreddit: String
}

struct SubredditPage {
    let posts: [RedditPost]
    let after: String?
}

final class RedditService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchTrending(subreddits: [String] = ["wallstreetbets", "investing", "stocks"]) async throws -> (posts: [RedditPost], afterCursors: [String: String]) {
        var allPosts: [RedditPost] = []
        var afterCursors: [String: String] = [:]
        for sub in subreddits {
            let page = try await fetchSubreddit(sub)
            allPosts.append(contentsOf: page.posts)
            if let after = page.after {
                afterCursors[sub] = after
            }
        }
        return (posts: allPosts.sorted { $0.score > $1.score }, afterCursors: afterCursors)
    }

    func fetchMore(subreddits: [String], afterCursors: [String: String]) async throws -> (posts: [RedditPost], afterCursors: [String: String]) {
        var allPosts: [RedditPost] = []
        var newCursors: [String: String] = [:]
        for sub in subreddits {
            guard let cursor = afterCursors[sub] else { continue }
            let page = try await fetchSubreddit(sub, after: cursor)
            allPosts.append(contentsOf: page.posts)
            if let after = page.after {
                newCursors[sub] = after
            }
        }
        return (posts: allPosts.sorted { $0.score > $1.score }, afterCursors: newCursors)
    }

    private func fetchSubreddit(_ name: String, after: String? = nil) async throws -> SubredditPage {
        var urlString = "https://www.reddit.com/r/\(name)/hot.json?limit=15"
        if let after {
            urlString += "&after=\(after)"
        }
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.setValue("InvestWise/1.0", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: request)
        return try Self.parseRedditResponse(data: data, subredditName: name)
    }

    static func parseRedditResponse(data: Data, subredditName: String = "") throws -> SubredditPage {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let dataObj = json?["data"] as? [String: Any],
              let children = dataObj["children"] as? [[String: Any]]
        else { return SubredditPage(posts: [], after: nil) }
        let after = dataObj["after"] as? String
        let posts = children.compactMap { child -> RedditPost? in
            guard let post = child["data"] as? [String: Any],
                  let title = post["title"] as? String
            else { return nil }
            let sub = post["subreddit"] as? String ?? subredditName
            return RedditPost(
                title: title,
                selftext: post["selftext"] as? String ?? "",
                score: post["score"] as? Int ?? 0,
                numComments: post["num_comments"] as? Int ?? 0,
                permalink: post["permalink"] as? String ?? "",
                subreddit: sub
            )
        }
        return SubredditPage(posts: posts, after: after)
    }
}
