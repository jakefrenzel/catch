import SwiftUI

extension View {
    /// A step's long-press menu: Start Focus (not for a done step), Rename, and
    /// Delete (not for a project's only step).
    func stepMenu(_ step: Step, onFocus: (() -> Void)?) -> some View {
        modifier(StepMenu(step: step, onFocus: onFocus))
    }
}

private struct StepMenu: ViewModifier {
    let step: Step
    let onFocus: (() -> Void)?

    @Environment(AppModel.self) private var model
    @State private var isRenaming = false
    @State private var newText = ""

    func body(content: Content) -> some View {
        content
            .contextMenu {
                // The menu can be built while an undo or Siri removes the step.
                if !step.isGone {
                    if let onFocus {
                        Button(action: onFocus) {
                            Label("Start Focus", systemImage: "timer")
                        }
                    }
                    Button {
                        newText = step.text
                        isRenaming = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    if model.store.canDelete(step) {
                        Button(role: .destructive) {
                            model.delete(step)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .alert("Rename Step", isPresented: $isRenaming) {
                TextField("Step", text: $newText)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    guard !step.isGone else { return }
                    model.rename(step, to: newText)
                }
            }
    }
}
