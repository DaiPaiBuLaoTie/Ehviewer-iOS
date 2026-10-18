import AppModels
import ComposableArchitecture
import DFClient
import NetworkingFeature
import Sharing
import SwiftUI

struct SXJNetworkView: View {
    @Shared(.setting) private var setting: Setting
    @Dependency(\.dfClient) private var dfClient
    @State private var hosts = UserDefaults.standard.string(forKey: SXJNetworkSettings.hostsKey) ?? ""
    @State private var doh = UserDefaults.standard.string(forKey: SXJNetworkSettings.dohKey) ?? ""
    @State private var proxy = UserDefaults.standard.string(forKey: SXJNetworkSettings.proxyKey) ?? ""
    @State private var status: String?

    var body: some View {
        Form {
            Section("自定义 Hosts") {
                TextEditor(text: $hosts).font(.system(.footnote, design: .monospaced)).frame(minHeight: 130)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Text("格式：IP地址 域名。自定义 Hosts 用于实验室的 SNI 直连模式；留空使用内置地址。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("DNS over HTTPS") {
                TextField("留空使用系统 DNS", text: $doh)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                Text("例如 https://cloudflare-dns.com/dns-query。系统已配置加密 DNS 或 Private Relay 时，由系统选择解析服务。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("应用代理") {
                TextField("http(s)://主机:端口 或 socks5://主机:端口", text: $proxy)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                Text("设置代理后关闭 SNI 直连，新的请求使用代理。留空恢复系统网络设置。代理地址暂不支持用户名密码。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                Button("保存并应用") { save() }
                if let status { Text(status).textSelection(.enabled) }
            }
        }
        .navigationTitle("网络设置")
    }

    private func save() {
        do {
            let hostText = hosts.trimmingCharacters(in: .whitespacesAndNewlines)
            let dohText = doh.trimmingCharacters(in: .whitespacesAndNewlines)
            let proxyText = proxy.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = try SXJNetworkSettings.parseHosts(hostText)
            _ = try SXJNetworkSettings.validateDOH(dohText)
            _ = try SXJNetworkSettings.proxyConfiguration(proxyText)
            UserDefaults.standard.set(hostText, forKey: SXJNetworkSettings.hostsKey)
            UserDefaults.standard.set(dohText, forKey: SXJNetworkSettings.dohKey)
            UserDefaults.standard.set(proxyText, forKey: SXJNetworkSettings.proxyKey)
            if !proxyText.isEmpty { $setting.withLock { $0.bypassesSNIFiltering = false } }
            dfClient.setActive(setting.bypassesSNIFiltering)
            status = "网络设置已保存，新请求生效。已建立的连接可能需要退出并重新打开应用。"
        } catch { status = error.localizedDescription }
    }
}
