import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var showingNewSession = false
    @State private var editingSession: SSHSessionConfig?
    @State private var searchText = ""

    var filteredSessions: [SSHSessionConfig] {
        let sessions = sessionManager.savedSessions
        if searchText.isEmpty { return sessions }
        return sessions.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.host.localizedCaseInsensitiveContains(searchText) ||
            $0.username.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header area with frosted glass
            VStack(spacing: 8) {
                SidebarButton(label: "New Terminal", icon: "terminal", tint: .green) {
                    sessionManager.newLocalTab()
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 8)

            GlassDivider()

            // Search bar — glass pill
            GlassSearchBar(text: $searchText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            GlassDivider()

            // Sessions list
            if filteredSessions.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 24, weight: .thin))
                        .foregroundStyle(.tertiary)
                    Text(searchText.isEmpty ? "No saved sessions" : "No matching sessions")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredSessions) { session in
                            SessionRowView(session: session) {
                                sessionManager.newSSHTab(config: session)
                            }
                            .contextMenu {
                                Button("Connect") { sessionManager.newSSHTab(config: session) }
                                Button("Edit")    { editingSession = session }
                                Divider()
                                Button("Delete", role: .destructive) { sessionManager.deleteSession(session) }
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
            }

            GlassDivider()

            // Bottom action
            VStack(spacing: 8) {
                SidebarButton(label: "New SSH Session", icon: "plus.circle", tint: .blue) {
                    showingNewSession = true
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .sheet(isPresented: $showingNewSession) {
            SessionEditorView(mode: .create)
        }
        .sheet(item: $editingSession) { session in
            SessionEditorView(mode: .edit(session))
        }
    }
}

// MARK: - Glass Search Bar

struct GlassSearchBar: View {
    @Binding var text: String
    @State private var isFocused = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.tertiary)
                .font(.system(size: 11, weight: .medium))

            TextField("Search sessions…", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .clipShape(Capsule(style: .continuous))
    }
}

// MARK: - Sidebar Button (Liquid Glass pill)

struct SidebarButton: View {
    let label: String
    let icon: String
    var tint: Color = .primary
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint.opacity(0.9))
                .frame(width: 20)

            Text(label)
                .font(.system(size: 12, weight: .medium))

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .glassPill(isActive: false, isHovering: isHovering)
        .onHover { isHovering = $0 }
        .onTapGesture { action() }
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }
}

// MARK: - Session Row (Glass card)

struct SessionRowView: View {
    let session: SSHSessionConfig
    let onConnect: () -> Void
    @State private var isHovering = false
    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 10) {
            // Glass icon circle — uses session's custom icon color
            ZStack {
                Circle()
                    .fill(session.iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Circle()
                    .stroke(session.iconColor.opacity(0.2), lineWidth: 0.5)
                    .frame(width: 32, height: 32)
                Image(systemName: "desktopcomputer")
                    .foregroundColor(session.iconColor)
                    .font(.system(size: 13, weight: .medium))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(session.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text("\(session.username)@\(session.host)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()

            // Subtle connect indicator on hover
            if isHovering {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    isPressed
                        ? Color.accentColor.opacity(0.15)
                        : isHovering ? Color.white.opacity(0.06) : Color.white.opacity(0.02)
                )
                .shadow(color: .black.opacity(isHovering ? 0.06 : 0.02), radius: 4, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isHovering ? 0.16 : 0.08),
                            Color.white.opacity(isHovering ? 0.04 : 0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) { isHovering = hovering }
        }
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.1)) { isPressed = true }
            onConnect()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation { isPressed = false }
            }
        }
    }
}
