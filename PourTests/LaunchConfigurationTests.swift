import XCTest
@testable import Pour

final class LaunchConfigurationTests: XCTestCase {
    func testCameraUsageDescriptionMatchesThePromptCopy() {
        let expected = "Pour uses the camera to scan bottle barcodes into My Bar. Codes are matched on this device and are not sent anywhere."
        let actual = Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") as? String
        XCTAssertEqual(actual, expected)
    }

    func testUITestingHooksStayOffWithoutTheLaunchArgument() {
        XCTAssertFalse(LaunchConfiguration.isUITesting)
        XCTAssertFalse(LaunchConfiguration.usesEphemeralStore)
        XCTAssertNil(LaunchConfiguration.simulatedReadiness())
    }

    func testCameraStatusArgumentFeedsTheAuthorizationPolicy() {
        XCTAssertEqual(
            LaunchConfiguration.simulatedReadiness(
                arguments: ["-uiTesting", "-cameraStatus=denied"],
                uiTesting: true
            ),
            .denied
        )
        XCTAssertEqual(
            LaunchConfiguration.simulatedReadiness(
                arguments: ["-uiTesting", "-cameraStatus=restricted"],
                uiTesting: true
            ),
            .restricted
        )
        XCTAssertEqual(
            LaunchConfiguration.simulatedReadiness(
                arguments: ["-uiTesting", "-cameraStatus=authorized"],
                uiTesting: true
            ),
            .ready
        )
        XCTAssertNil(
            LaunchConfiguration.simulatedReadiness(
                arguments: ["-cameraStatus=denied"],
                uiTesting: false
            )
        )
        XCTAssertNil(LaunchConfiguration.simulatedReadiness(arguments: ["-uiTesting"], uiTesting: true))
        XCTAssertNil(LaunchConfiguration.cameraStatus(in: ["-cameraStatus=nope"]))
    }
}
