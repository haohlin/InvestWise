import XCTest
@testable import InvestWise

final class NewsServiceTests: XCTestCase {
    func testParseNewsAPIResponse() throws {
        let json = """
        {"status":"ok","totalResults":1,"articles":[{"title":"Fed holds rates","source":{"name":"Reuters"},"url":"https://example.com/1","publishedAt":"2026-03-01T10:00:00Z","description":"The Fed held rates steady."}]}
        """.data(using: .utf8)!
        let items = try NewsService.parseNewsAPIResponse(data: json)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "Fed holds rates")
        XCTAssertEqual(items[0].source, "Reuters")
    }

    func testParseRedditResponse() throws {
        let json = """
        {"data":{"children":[{"data":{"title":"SPY hitting new highs","selftext":"Market looking strong","score":500,"num_comments":120,"permalink":"/r/investing/test"}}]}}
        """.data(using: .utf8)!
        let posts = try RedditService.parseRedditResponse(data: json)
        XCTAssertEqual(posts.count, 1)
        XCTAssertEqual(posts[0].title, "SPY hitting new highs")
    }
}
