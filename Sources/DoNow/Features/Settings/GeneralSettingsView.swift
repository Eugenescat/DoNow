import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject private var loginItem: LoginItemService

    init(appModel: AppModel) {
        self.appModel = appModel
        self.loginItem = appModel.loginItem
    }

    var body: some View {
        Form {
            Section("启动") {
                Toggle("登录 Mac 时自动打开 DoNow", isOn: loginItemBinding)
                if let error = loginItem.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("日历") {
                Text("任务完成后写入系统默认日历。首次完成时，系统会请求仅写入权限。")
                    .foregroundStyle(.secondary)
            }

            Section("关于") {
                LabeledContent("版本", value: "0.1.0 MVP")
                Text("所有任务和完成记录都保存在本机。")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { loginItem.refresh() }
    }

    private var loginItemBinding: Binding<Bool> {
        Binding(
            get: { loginItem.isEnabled },
            set: { loginItem.setEnabled($0) }
        )
    }
}
