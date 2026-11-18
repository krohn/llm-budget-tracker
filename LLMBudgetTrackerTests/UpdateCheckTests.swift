import XCTest

final class UpdateCheckTests: XCTestCase {
    func testParsesVersionWithAndWithoutTagPrefix() throws {
        let tagged = try XCTUnwrap(AppVersion("v0.1.0"))
        XCTAssertEqual(tagged.description, "0.1.0")
        XCTAssertEqual(AppVersion("0.1.0"), tagged)
        XCTAssertEqual(AppVersion(" 1.2.3 ")?.description, "1.2.3")
    }

    func testRejectsMalformedVersions() {
        for value in ["", "v", "0.1", "0.1.0.1", "0.x.0", "0..1", "-1.0.0", "v0.1.0-beta", "unknown"] {
            XCTAssertNil(AppVersion(value), value)
        }
    }

    func testComparesVersionsNumerically() throws {
        XCTAssertGreaterThan(try XCTUnwrap(AppVersion("0.1.10")), try XCTUnwrap(AppVersion("0.1.9")))
        XCTAssertGreaterThan(try XCTUnwrap(AppVersion("1.0.0")), try XCTUnwrap(AppVersion("0.99.99")))
        XCTAssertGreaterThan(try XCTUnwrap(AppVersion("0.2.0")), try XCTUnwrap(AppVersion("0.1.5")))
        XCTAssertEqual(AppVersion("v0.1.0"), AppVersion("0.1.0"))
    }

    func testNewerReleaseLinksToItsReleasePage() throws {
        let url = try XCTUnwrap(URL(string: "https://git.krohn.io/karsten/llm-budget-tracker/-/releases/v0.2.0"))
        XCTAssertEqual(
            ReleaseFeed.status(latestTag: "v0.2.0", currentVersion: "0.1.0"),
            .updateAvailable(version: "0.2.0", url: url)
        )
    }

    func testSameOrOlderReleaseIsUpToDate() {
        XCTAssertEqual(ReleaseFeed.status(latestTag: "v0.1.0", currentVersion: "0.1.0"), .upToDate)
        XCTAssertEqual(ReleaseFeed.status(latestTag: "v0.0.8", currentVersion: "0.1.0"), .upToDate)
    }

    func testUnexpectedTagFails() {
        guard case .failed = ReleaseFeed.status(latestTag: "nightly", currentVersion: "0.1.0") else {
            return XCTFail("Expected .failed")
        }
    }

    func testReleasePageUsesHTTPS() {
        XCTAssertEqual(ReleaseFeed.releasePageURL(tag: "v0.1.0")?.scheme, "https")
        XCTAssertEqual(ReleaseFeed.latestReleaseURL?.scheme, "https")
    }

    func testCheckIsDueAfterOneDay() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertTrue(ReleaseFeed.isCheckDue(lastCheck: nil, now: now))
        XCTAssertFalse(ReleaseFeed.isCheckDue(lastCheck: now.addingTimeInterval(-23 * 3600), now: now))
        XCTAssertTrue(ReleaseFeed.isCheckDue(lastCheck: now.addingTimeInterval(-24 * 3600), now: now))
    }

    func testDecodesLatestReleaseResponse() throws {
        let json = Data(#"{"name":"v0.1.0","tag_name":"v0.1.0","description":"notes","_links":{}}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(LatestRelease.self, from: json).tagName, "v0.1.0")
    }
}
