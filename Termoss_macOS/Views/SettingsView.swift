import SwiftUI

struct SettingsView: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var editingTheme: TerminalTheme
    @State private var selectedThemeName: String
    @State private var showDeleteConfirm = false
    @State private var showSaveAs = false
    @State private var saveAsName = ""

    init() {
        let current = ThemeManager.shared.globalTheme
        _editingTheme = State(initialValue: current)
        _selectedThemeName = State(initialValue: current.name)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Settings")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Global Terminal Theme")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)

            GlassDivider()

            // Theme picker row
            HStack(spacing: 8) {
                Image(systemName: "paintpalette")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))

                Picker("", selection: $selectedThemeName) {
                    ForEach(themeManager.savedThemes, id: \.name) { theme in
                        Text(theme.name).tag(theme.name)
                    }
                }
                .labelsHidden()
                .onChange(of: selectedThemeName) { _, newName in
                    if let theme = themeManager.savedThemes.first(where: { $0.name == newName }) {
                        editingTheme = theme
                    }
                }

                // Save current edits as new theme
                Button(action: {
                    saveAsName = ""
                    showSaveAs = true
                }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.white.opacity(0.05)))
                        .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Save as new theme")

                // Delete current theme (not built-in)
                if selectedThemeName != TerminalTheme.defaultDark.name {
                    Button(action: { showDeleteConfirm = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.red.opacity(0.8))
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Color.white.opacity(0.05)))
                            .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Delete this theme")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            GlassDivider()

            // Theme editor
            ThemeEditorView(theme: $editingTheme)
                .padding(.horizontal, 4)

            GlassDivider()

            // Actions
            HStack(spacing: 10) {
                GlassPillButton(title: "Reset to Default", style: .secondary) {
                    editingTheme = .defaultDark
                    selectedThemeName = TerminalTheme.defaultDark.name
                }

                Spacer()

                GlassPillButton(title: "Cancel", style: .secondary) { dismiss() }
                    .keyboardShortcut(.cancelAction)

                GlassPillButton(title: "Apply", style: .accent) {
                    var themeToSave = editingTheme
                    themeToSave.name = selectedThemeName
                    themeManager.saveTheme(themeToSave)
                    themeManager.globalTheme = themeToSave
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 520, height: 720)
        .background(VisualEffectBackground(material: .sidebar, blendingMode: .withinWindow))
        .alert("Delete Theme", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                themeManager.deleteTheme(named: selectedThemeName)
                selectedThemeName = TerminalTheme.defaultDark.name
                editingTheme = .defaultDark
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete \"\(selectedThemeName)\"? This cannot be undone.")
        }
        .sheet(isPresented: $showSaveAs) {
            VStack(spacing: 16) {
                Text("Save Theme As")
                    .font(.system(size: 14, weight: .semibold))

                TextField("Theme name", text: $saveAsName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)

                HStack(spacing: 10) {
                    Button("Cancel") { showSaveAs = false }
                        .keyboardShortcut(.cancelAction)

                    Button("Save") {
                        guard !saveAsName.isEmpty else { return }
                        var newTheme = editingTheme
                        newTheme.name = saveAsName
                        themeManager.saveTheme(newTheme)
                        selectedThemeName = saveAsName
                        editingTheme = newTheme
                        showSaveAs = false
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(saveAsName.isEmpty)
                }
            }
            .padding(24)
            .frame(width: 320)
            .background(VisualEffectBackground(material: .sidebar, blendingMode: .withinWindow))
        }
    }
}

// MARK: - Tab Theme Customization Sheet

struct TabThemeEditorView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.dismiss) var dismiss

    let tabID: UUID
    let tabTitle: String

    @State private var editingTheme: TerminalTheme
    @State private var useCustom: Bool
    @State private var selectedThemeName: String
    @State private var tabName: String

    init(tabID: UUID, tabTitle: String) {
        self.tabID = tabID
        self.tabTitle = tabTitle
        let existing = ThemeManager.shared.tabOverrides[tabID]
        _useCustom = State(initialValue: existing != nil)
        _editingTheme = State(initialValue: existing ?? ThemeManager.shared.globalTheme)
        _selectedThemeName = State(initialValue: existing?.name ?? ThemeManager.shared.globalTheme.name)
        _tabName = State(initialValue: tabTitle)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Customize Tab")
                        .font(.system(size: 15, weight: .semibold))
                    TextField("Tab name", text: $tabName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                        .frame(width: 200)
                }
                Spacer()

                Toggle("Custom theme", isOn: $useCustom)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)

            GlassDivider()

            if useCustom {
                // Theme picker
                HStack(spacing: 8) {
                    Text("Base theme:")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Picker("", selection: $selectedThemeName) {
                        ForEach(themeManager.savedThemes, id: \.name) { theme in
                            Text(theme.name).tag(theme.name)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: selectedThemeName) { _, newName in
                        if let theme = themeManager.savedThemes.first(where: { $0.name == newName }) {
                            editingTheme = theme
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

                GlassDivider()

                ThemeEditorView(theme: $editingTheme)
                    .padding(.horizontal, 4)
            } else {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 28, weight: .thin))
                        .foregroundStyle(.tertiary)
                    Text("Using global theme")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text(themeManager.globalTheme.name)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }

            GlassDivider()

            HStack {
                Spacer()

                GlassPillButton(title: "Cancel", style: .secondary) { dismiss() }
                    .keyboardShortcut(.cancelAction)

                GlassPillButton(title: "Apply", style: .accent) {
                    let trimmed = tabName.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty && trimmed != tabTitle {
                        sessionManager.renameTab(tabID, to: trimmed)
                    }
                    if useCustom {
                        themeManager.setTabOverride(editingTheme, for: tabID)
                    } else {
                        themeManager.clearTabOverride(for: tabID)
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 520, height: useCustom ? 720 : 300)
        .background(VisualEffectBackground(material: .sidebar, blendingMode: .withinWindow))
        .animation(.easeInOut(duration: 0.2), value: useCustom)
    }
}
