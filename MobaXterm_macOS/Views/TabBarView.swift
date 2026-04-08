import SwiftUI

struct TabBarView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Binding var showSidebar: Bool
    @Binding var showFileBrowser: Bool
    let isSSHTab: Bool
    @Binding var customizingTab: TabItem?

    @State private var fileBtnHover = false

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar toggle
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showSidebar.toggle() } }) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.white.opacity(0.05)))
                    .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)

            // Tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(sessionManager.tabs) { tab in
                        TabItemView(
                            tab: tab,
                            isActive: sessionManager.activeTabID == tab.id,
                            onSelect: { sessionManager.activeTabID = tab.id },
                            onClose: { sessionManager.closeTab(tab.id) }
                        )
                        .contextMenu {
                            Button("Customize…") {
                                customizingTab = tab
                            }
                            Divider()
                            Button("Close Tab") {
                                sessionManager.closeTab(tab.id)
                            }
                            .disabled(sessionManager.tabs.count <= 1)
                        }
                    }
                    Button(action: { sessionManager.newLocalTab() }) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Color.white.opacity(0.04)))
                            .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 2)
                }
                .padding(.horizontal, 6)
                .padding(.top, 6)
                .padding(.bottom, 5)
            }

            Spacer()

            // File browser toggle
            if isSSHTab {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) { showFileBrowser.toggle() }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 11, weight: .medium))
                        Text("Files")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(showFileBrowser ? .primary : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(
                                showFileBrowser
                                    ? Color.white.opacity(0.12)
                                    : fileBtnHover ? Color.white.opacity(0.07) : Color.white.opacity(0.04)
                            )
                            .shadow(color: .black.opacity(showFileBrowser ? 0.06 : 0), radius: 3, y: 1)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(showFileBrowser ? 0.2 : fileBtnHover ? 0.1 : 0.06),
                                        Color.white.opacity(showFileBrowser ? 0.06 : 0.02)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    )
                    .clipShape(Capsule(style: .continuous))
                    .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .onHover { fileBtnHover = $0 }
                .padding(.trailing, 10)
            }
        }
        .frame(height: 42)
        .background(VisualEffectBackground(material: .titlebar, blendingMode: .withinWindow))
    }
}

struct TabItemView: View {
    @EnvironmentObject var sessionManager: SessionManager
    let tab: TabItem
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false
    @State private var isEditing = false
    @State private var editText = ""

    private var indicatorColor: Color {
        if tab.type == .ssh, let config = tab.sessionConfig {
            return config.iconColor
        }
        return tab.type == .local ? .green : .blue
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(indicatorColor.opacity(0.9))
                .frame(width: 6, height: 6)
                .shadow(color: indicatorColor.opacity(0.4), radius: 3)

            if isEditing {
                TextField("", text: $editText, onCommit: {
                    let trimmed = editText.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        sessionManager.renameTab(tab.id, to: trimmed)
                    }
                    isEditing = false
                })
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .frame(minWidth: 60, maxWidth: 140)
                .onExitCommand { isEditing = false }
            } else {
                Text(tab.title)
                    .font(.system(size: 11, weight: isActive ? .medium : .regular))
                    .lineLimit(1)
                    .onTapGesture(count: 2) {
                        editText = tab.title
                        isEditing = true
                    }
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 14, height: 14)
                    .background(Circle().fill(Color.white.opacity(isHovering ? 0.08 : 0)))
                    .clipShape(Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.borderless)
            .opacity(isHovering || isActive ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(
                    isActive
                        ? Color.white.opacity(0.12)
                        : isHovering ? Color.white.opacity(0.06) : Color.clear
                )
                .shadow(color: .black.opacity(isActive ? 0.08 : 0), radius: 3, y: 1)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isActive ? 0.22 : isHovering ? 0.1 : 0),
                            Color.white.opacity(isActive ? 0.06 : 0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .clipShape(Capsule(style: .continuous))
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) { isHovering = hovering }
        }
        .simultaneousGesture(TapGesture().onEnded { onSelect() })
        .transition(.asymmetric(
            insertion: .scale(scale: 0.8, anchor: .leading).combined(with: .opacity),
            removal: .scale(scale: 0.8, anchor: .leading).combined(with: .opacity)
        ))
    }
}
