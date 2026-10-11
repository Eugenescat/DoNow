import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        TabView {
            TaskManagementView(appModel: appModel)
                .tabItem { Label("事项", systemImage: "checklist") }

            HistoryView(appModel: appModel)
                .tabItem { Label("历史", systemImage: "clock.arrow.circlepath") }

            GeneralSettingsView(appModel: appModel)
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .padding(20)
        .alert("DoNow", isPresented: errorPresented) {
            Button("好") { appModel.errorMessage = nil }
        } message: {
            Text(appModel.errorMessage ?? "未知错误")
        }
        .onAppear { appModel.reload() }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { appModel.errorMessage != nil },
            set: { if !$0 { appModel.errorMessage = nil } }
        )
    }
}
