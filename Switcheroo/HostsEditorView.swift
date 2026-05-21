import SwiftUI

struct HostsEditorView: View {
    @State private var text: String = ""
    @State private var savedText: String = ""
    @State private var status: Status = .idle
    @State private var errorMessage: String?
    @State private var showingSettings = false

    enum Status: Equatable { case idle, loading, saving, saved }

    private var isDirty: Bool { text != savedText }

    var body: some View {
        VStack(spacing: 0) {
            header
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            Divider()
            footer
        }
        .frame(width: 520, height: 560)
        .onAppear { load() }
    }

    private var header: some View {
        HStack {
            Text("/etc/hosts")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
            statusView
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .popover(isPresented: $showingSettings, arrowEdge: .top) {
                SettingsView()
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q", modifiers: .command)
            Button("Revert") { load() }
                .disabled(!isDirty || status == .saving)
            Spacer()
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            Button("Save") { save() }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!isDirty || status == .saving)
                .buttonStyle(.borderedProminent)
        }
        .padding(12)
    }

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .idle:
            if isDirty {
                Text("Modified").font(.caption).foregroundStyle(.orange)
            } else {
                Text("Clean").font(.caption).foregroundStyle(.secondary)
            }
        case .loading:
            Text("Loading…").font(.caption).foregroundStyle(.secondary)
        case .saving:
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text("Saving…").font(.caption).foregroundStyle(.secondary)
            }
        case .saved:
            Text("Saved").font(.caption).foregroundStyle(.green)
        }
    }

    private func load() {
        status = .loading
        errorMessage = nil
        do {
            let s = try HostsFile.read()
            text = s
            savedText = s
            status = .idle
        } catch {
            errorMessage = error.localizedDescription
            status = .idle
        }
    }

    private func save() {
        let toSave = text
        status = .saving
        errorMessage = nil
        Task {
            do {
                try await HostsFile.write(toSave)
                await MainActor.run {
                    savedText = toSave
                    status = .saved
                }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run {
                    if status == .saved { status = .idle }
                }
            } catch HostsFileError.cancelled {
                await MainActor.run { status = .idle }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    status = .idle
                }
            }
        }
    }
}

private struct SettingsView: View {
    @State private var postSaveCommand: String = Settings.postSaveCommand ?? ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Post-save command")
                .font(.headline)
            Text("Shell command to run after every successful save. Useful for nudging a proxy or other long-lived app to re-resolve DNS.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TextField("e.g. osascript -e 'tell application \"AutoProxxy\" to quit' && sleep 0.3 && open -a AutoProxxy", text: $postSaveCommand, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .lineLimit(2...4)
                .onChange(of: postSaveCommand) { _, newValue in
                    Settings.postSaveCommand = newValue
                }
            Text("Runs via /bin/sh -c. Leave blank to disable.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 380)
    }
}

#Preview {
    HostsEditorView()
}
