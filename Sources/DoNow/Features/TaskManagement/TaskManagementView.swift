import SwiftUI

struct TaskManagementView: View {
    @ObservedObject var appModel: AppModel
    @State private var showingEditor = false
    @State private var editingTask: TaskTemplate?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("待办事项")
                        .font(.title2.bold())
                    Text("点击悬浮球时会显示这些事项。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("添加", systemImage: "plus") {
                    editingTask = nil
                    showingEditor = true
                }
                .buttonStyle(.borderedProminent)
            }

            if appModel.tasks.isEmpty {
                ContentUnavailableView("还没有事项", systemImage: "checklist")
            } else {
                List {
                    ForEach(appModel.tasks) { task in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(task.name).fontWeight(.medium)
                                Text("预计 \(task.estimatedDurationSeconds / 60) 分钟")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("编辑") {
                                editingTask = task
                                showingEditor = true
                            }
                            .buttonStyle(.borderless)
                            Button(role: .destructive) {
                                appModel.archiveTask(task)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            TaskEditorView(task: editingTask) { name, minutes in
                if let editingTask {
                    appModel.updateTask(editingTask, name: name, minutes: minutes)
                } else {
                    appModel.addTask(name: name, minutes: minutes)
                }
            }
        }
    }
}

private struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let task: TaskTemplate?
    let save: (String, Int) -> Void

    @State private var name: String
    @State private var minutes: Int

    init(task: TaskTemplate?, save: @escaping (String, Int) -> Void) {
        self.task = task
        self.save = save
        _name = State(initialValue: task?.name ?? "")
        _minutes = State(initialValue: (task?.estimatedDurationSeconds ?? 25 * 60) / 60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(task == nil ? "添加事项" : "编辑事项")
                .font(.title2.bold())
            TextField("事项名称", text: $name)
                .textFieldStyle(.roundedBorder)
            HStack(spacing: 8) {
                Text("预计单次需要")
                TextField("分钟数", value: $minutes, format: .number.grouping(.never))
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 76)
                    .accessibilityLabel("预计分钟数")
                Text("分钟")
                Stepper("调整预计分钟数", value: $minutes, in: 1...(24 * 60))
                    .labelsHidden()
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") {
                    save(name, minutes)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || !(1...(24 * 60)).contains(minutes)
                )
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
