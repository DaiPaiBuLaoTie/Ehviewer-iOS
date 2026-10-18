import Foundation
import NetworkingFeature
import Testing

struct SXJNetworkSettingsTests {
    @Test func parsesMultipleDomainsAndComments() throws {
        let text = "# comment only\n127.0.0.1 example.org second.org # note\n::1 ipv6.example.org"
        let hosts = try SXJNetworkSettings.parseHosts(text)
        #expect(hosts["example.org"] == "127.0.0.1")
        #expect(hosts["second.org"] == "127.0.0.1")
        #expect(hosts["ipv6.example.org"] == "::1")
    }

    @Test func rejectsHostURLsAndInvalidAddresses() {
        #expect(throws: SXJNetworkSettings.ConfigurationError.self) {
            try SXJNetworkSettings.parseHosts("not-an-ip example.org")
        }
        #expect(throws: SXJNetworkSettings.ConfigurationError.self) {
            try SXJNetworkSettings.parseHosts("127.0.0.1 https://example.org")
        }
    }

    @Test func rejectsPlaintextDOH() {
        #expect(throws: SXJNetworkSettings.ConfigurationError.self) {
            try SXJNetworkSettings.validateDOH("http://example.org/dns-query")
        }
    }

    @Test func requiresExplicitValidProxyPort() {
        #expect(throws: SXJNetworkSettings.ConfigurationError.self) {
            try SXJNetworkSettings.proxyConfiguration("http://example.org")
        }
        #expect(throws: SXJNetworkSettings.ConfigurationError.self) {
            try SXJNetworkSettings.proxyConfiguration("socks5://example.org:99999")
        }
    }
}
