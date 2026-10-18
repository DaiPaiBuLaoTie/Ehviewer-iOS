import Foundation
import Testing
@testable import SettingFeature

struct SXJAndroidDownloadHeaderTests {
    @Test func acceptsVersionTwoHeaderWithoutLoadingPageTokens() throws {
        let text = "VERSION2\n00000004\n12345\nabcdef1234\n1\n2\n40\n80\n0 ignored"
        let header = try SXJAndroidDownloadHeader.parse(Data(text.utf8))
        #expect(header.gid == "12345")
        #expect(header.token == "abcdef1234")
        #expect(header.pageCount == 80)
    }

    @Test func acceptsLegacyVersionOne() throws {
        let text = "00000000\n12345\nabcdef1234\n1\n2\n40\n80\n"
        #expect(try SXJAndroidDownloadHeader.parse(Data(text.utf8)).pageCount == 80)
    }

    @Test(arguments: [
        "VERSION3\n00000000\n1\ntoken\n1\n1\n40\n1\n",
        "VERSION2\n00000000\n1\n../bad\n1\n1\n40\n1\n",
        "VERSION2\n00000000\n1\ntoken\n1\n1\n40\n999999\n",
        "VERSION2\n00000000\n-1\ntoken\n1\n1\n40\n1\n"
    ])
    func rejectsUnsupportedOrInvalidIdentity(_ text: String) {
        #expect(throws: SXJAndroidDownloadHeader.HeaderError.self) {
            try SXJAndroidDownloadHeader.parse(Data(text.utf8))
        }
    }
}
