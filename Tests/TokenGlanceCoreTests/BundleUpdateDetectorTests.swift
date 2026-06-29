import Testing

@testable import TokenGlanceCore

@Suite("Bundle update detector")
struct BundleUpdateDetectorTests {
  @Test("Relaunches when disk version differs from launched version")
  func relaunchesWhenDiskVersionDiffers() {
    let detector = BundleUpdateDetector()

    #expect(detector.shouldRelaunch(launchedVersion: "0.1.8", diskVersion: "0.1.9"))
  }

  @Test("Does not relaunch when versions match or disk version is unavailable")
  func ignoresMatchingOrUnavailableVersions() {
    let detector = BundleUpdateDetector()

    #expect(!detector.shouldRelaunch(launchedVersion: "0.1.9", diskVersion: "0.1.9"))
    #expect(!detector.shouldRelaunch(launchedVersion: "0.1.9", diskVersion: nil))
    #expect(!detector.shouldRelaunch(launchedVersion: "0.1.9", diskVersion: " "))
  }
}
