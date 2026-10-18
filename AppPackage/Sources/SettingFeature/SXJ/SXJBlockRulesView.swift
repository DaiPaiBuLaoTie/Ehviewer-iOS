import AppModels
import Sharing
import SwiftUI

struct SXJBlockRulesView: View {
    @Shared(.sxjBlockRules) private var rules: [SXJBlockRule]
    @State private var kind: SXJBlockRule.Kind = .title
    @State private var value = ""
    @State private var failure: String?

    var body: some View {
        Form {
            Section("添加本地屏蔽规则") {
                Picker("匹配内容", selection: $kind) {
                    Text("标题包含").tag(SXJBlockRule.Kind.title)
                    Text("上传者（完整名称）").tag(SXJBlockRule.Kind.uploader)
                    Text("标签（可含命名空间）").tag(SXJBlockRule.Kind.tag)
                    Text("命名空间").tag(SXJBlockRule.Kind.namespace)
                }
                TextField("输入匹配文字", text: $value)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("添加规则") { addRule() }
                    .disabled(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || rules.count >= 2_000)
            }
            Section("已有规则") {
                ForEach(rules) { rule in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(rule.value)
                            Text(rule.kind.rawValue).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(rule.isEnabled ? "停用" : "启用") {
                            $rules.withLock { current in
                                guard let index = current.firstIndex(where: { $0.id == rule.id }) else { return }
                                current[index].isEnabled.toggle()
                            }
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .onDelete { offsets in $rules.withLock { $0.remove(atOffsets: offsets) } }
                .onMove { source, destination in
                    $rules.withLock { $0.move(fromOffsets: source, toOffset: destination) }
                }
            }
            Section {
                Text("规则应用于首页、搜索和收藏列表。标题使用包含匹配；上传者和标签使用完整匹配，忽略大小写。")
                    .font(.footnote).foregroundStyle(.secondary)
                if let failure { Text(failure).foregroundStyle(.red) }
            }
        }
        .navigationTitle("本地屏蔽").toolbar { EditButton() }
    }

    private func addRule() {
        let rule = SXJBlockRule(kind: kind, value: value)
        guard !rules.contains(where: { $0.kind == kind && $0.value.caseInsensitiveCompare(rule.value) == .orderedSame })
        else {
            failure = "该规则已经存在。"
            return
        }
        $rules.withLock { $0.append(rule) }
        value = ""
        failure = nil
    }
}
