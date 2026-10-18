import AppModels
import Sharing
import SwiftUI

struct SXJReaderSettingsView: View {
    @Shared(.sxjReaderOptions) private var options: SXJReaderOptions

    var body: some View {
        Section("屏幕与阅读状态") {
            Toggle("阅读时保持屏幕常亮", isOn: Binding($options.keepsScreenAwake))
            Toggle("自定义阅读亮度", isOn: Binding($options.usesCustomBrightness))
            if options.usesCustomBrightness {
                Slider(value: Binding($options.brightness), in: 0.05...1) {
                    Text("阅读亮度")
                }
            }
            Picker("阅读背景", selection: Binding($options.background)) {
                Text("跟随外观").tag(SXJReaderOptions.Background.system)
                Text("黑色").tag(SXJReaderOptions.Background.black)
                Text("白色").tag(SXJReaderOptions.Background.white)
            }
            Toggle("显示页码", isOn: Binding($options.showsPageNumber))
            Toggle("显示时间", isOn: Binding($options.showsTime))
            Toggle("显示电量", isOn: Binding($options.showsBattery))
            Text("亮度和屏幕常亮仅在阅读界面生效，退出阅读或进入后台后恢复。状态信息在收起阅读菜单后显示。")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}
