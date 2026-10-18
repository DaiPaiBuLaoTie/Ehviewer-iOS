import Foundation
import Network

public enum SXJNetworkSettings {
    public static let hostsKey = "sxjCustomHosts"
    public static let dohKey = "sxjDOHURL"
    public static let proxyKey = "sxjProxyURL"

    public static func parseHosts(_ text: String) throws -> [String: String] {
        var result: [String: String] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let content = line.split(separator: "#", maxSplits: 1).first.map(String.init) ?? ""
            let parts = content.split(whereSeparator: \.isWhitespace).map(String.init)
            guard !parts.isEmpty else { continue }
            guard parts.count >= 2, IPv4Address(parts[0]) != nil || IPv6Address(parts[0]) != nil
            else { throw ConfigurationError.invalidHosts }
            for rawDomain in parts.dropFirst() {
                let domain = rawDomain.lowercased()
                let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-.")
                guard domain.count <= 253, !domain.contains("/"), !domain.contains(":"), !domain.isEmpty,
                      domain.unicodeScalars.allSatisfy({ allowed.contains($0) })
                else { throw ConfigurationError.invalidHosts }
                result[domain.lowercased()] = parts[0]
            }
        }
        return result
    }

    public static func proxyConfiguration(_ text: String) throws -> ProxyConfiguration? {
        guard !text.isEmpty else { return nil }
        guard let url = URL(string: text), let host = url.host,
              let rawPort = url.port, let port = NWEndpoint.Port(rawValue: UInt16(exactly: rawPort) ?? 0),
              rawPort > 0, rawPort <= 65_535,
              url.user == nil, url.password == nil,
              url.path.isEmpty || url.path == "/", url.query == nil, url.fragment == nil
        else { throw ConfigurationError.invalidProxy }
        let endpoint = NWEndpoint.hostPort(host: .name(host, nil), port: port)
        switch url.scheme?.lowercased() {
        case "http": return ProxyConfiguration(httpCONNECTProxy: endpoint)
        case "https": return ProxyConfiguration(httpCONNECTProxy: endpoint, tlsOptions: .init())
        case "socks5": return ProxyConfiguration(socksv5Proxy: endpoint)
        default: throw ConfigurationError.invalidProxy
        }
    }

    public static func validateDOH(_ text: String) throws -> URL? {
        guard !text.isEmpty else { return nil }
        guard let url = URL(string: text), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil, url.fragment == nil
        else { throw ConfigurationError.invalidDOH }
        return url
    }

    public static func apply() {
        let defaults = UserDefaults.standard
        let resolver = try? validateDOH(defaults.string(forKey: dohKey) ?? "")
        NWParameters.PrivacyContext.default.requireEncryptedNameResolution(
            resolver != nil, fallbackResolver: resolver.map { .https($0, serverAddresses: []) }
        )
        let proxy = try? proxyConfiguration(defaults.string(forKey: proxyKey) ?? "")
        NWParameters.PrivacyContext.default.proxyConfigurations = proxy.map { [$0] } ?? []
        NWParameters.PrivacyContext.default.flushCache()
    }

    public enum ConfigurationError: LocalizedError {
        case invalidHosts
        case invalidProxy
        case invalidDOH

        public var errorDescription: String? {
            switch self {
            case .invalidHosts: return "Hosts 格式应为：IP地址 域名。每行可包含多个域名，支持 # 注释。"
            case .invalidProxy: return "代理格式应为 http://主机:端口、https://主机:端口 或 socks5://主机:端口。"
            case .invalidDOH: return "加密 DNS 必须是有效的 HTTPS 地址。"
            }
        }
    }
}
