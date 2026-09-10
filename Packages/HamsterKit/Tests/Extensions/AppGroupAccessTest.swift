@testable import HamsterKit
import XCTest

final class AppGroupAccessTest: XCTestCase {
  func testUnavailableAppGroupErrorIsActionable() {
    let error = HamsterAppGroupError.unavailable(identifier: "group.example")
    let message = error.localizedDescription

    XCTAssertTrue(message.contains("App Group"))
    XCTAssertTrue(message.contains("Signing & Capabilities"))
    XCTAssertTrue(message.contains("重新安装"))
  }

  func testAppGroupContainerAccessThrowsWithoutEntitlement() throws {
    let existingContainer = try? FileManager.appGroupContainerURL()
    try XCTSkipUnless(existingContainer == nil, "测试宿主已配置 App Group，跳过无权限场景")

    XCTAssertThrowsError(try FileManager.appGroupContainerURL()) { error in
      XCTAssertEqual(
        error as? HamsterAppGroupError,
        .unavailable(identifier: HamsterConstants.appGroupName)
      )
    }
  }
}
