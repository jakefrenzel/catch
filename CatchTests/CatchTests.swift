import XCTest
@testable import Catch

final class CatchTests: XCTestCase {
    func testContentViewBuilds() {
        _ = ContentView().body
    }
}
