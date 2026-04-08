import SwiftUI

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar
    var blendingMode: NSVisualEffectView.BlendingMode = .withinWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Liquid Glass Modifiers

struct GlassSurface: ViewModifier {
    var cornerRadius: CGFloat = 12
    var opacity: Double = 0.06
    var borderOpacity: Double = 0.18

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(borderOpacity),
                                Color.white.opacity(borderOpacity * 0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct GlassPill: ViewModifier {
    var isActive: Bool = false
    var isHovering: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                Capsule(style: .continuous)
                    .fill(
                        isActive
                            ? Color.white.opacity(0.14)
                            : isHovering ? Color.white.opacity(0.08) : Color.white.opacity(0.04)
                    )
                    .shadow(color: .black.opacity(isActive ? 0.1 : 0.04), radius: 4, y: 1)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isActive ? 0.28 : 0.12),
                                Color.white.opacity(isActive ? 0.08 : 0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .clipShape(Capsule(style: .continuous))
    }
}

extension View {
    func glassSurface(cornerRadius: CGFloat = 12, opacity: Double = 0.06, borderOpacity: Double = 0.18) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius, opacity: opacity, borderOpacity: borderOpacity))
    }

    func glassPill(isActive: Bool = false, isHovering: Bool = false) -> some View {
        modifier(GlassPill(isActive: isActive, isHovering: isHovering))
    }
}

// MARK: - Liquid Glass Divider

struct GlassDivider: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.0),
                        Color.white.opacity(0.1),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 0.5)
    }
}

// MARK: - Glass Pill Button (full-area clickable)

struct GlassPillButton: View {
    enum Style { case secondary, accent }

    let title: String
    var style: Style = .secondary
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(fillColor)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(strokeColor, lineWidth: 0.5)
            )
            .clipShape(Capsule(style: .continuous))
            .contentShape(Capsule(style: .continuous))
            .onHover { isHovering = $0 }
            .onTapGesture { action() }
            .animation(.easeOut(duration: 0.15), value: isHovering)
    }

    private var fillColor: Color {
        switch style {
        case .secondary:
            return Color.white.opacity(isHovering ? 0.1 : 0.06)
        case .accent:
            return Color.accentColor.opacity(isHovering ? 0.35 : 0.25)
        }
    }

    private var strokeColor: Color {
        switch style {
        case .secondary:
            return Color.white.opacity(isHovering ? 0.16 : 0.1)
        case .accent:
            return Color.accentColor.opacity(isHovering ? 0.45 : 0.35)
        }
    }
}

// MARK: - Resize Handle (reusable)

struct PanelResizeHandle: View {
    @Binding var width: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat
    let direction: CGFloat

    @State private var isHovering = false

    var body: some View {
        Rectangle()
            .fill(isHovering ? Color.white.opacity(0.14) : Color.white.opacity(0.06))
            .frame(width: 1)
            .contentShape(Rectangle().inset(by: -4))
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        let newWidth = width + value.translation.width * direction
                        width = min(max(newWidth, minWidth), maxWidth)
                    }
            )
    }
}

extension PanelResizeHandle {
    init(width: Binding<CGFloat>, min minWidth: CGFloat, max maxWidth: CGFloat) {
        self.init(width: width, minWidth: minWidth, maxWidth: maxWidth, direction: 1)
    }
}

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showSidebar = true
    @State private var sidebarWidth: CGFloat = 240
    @State private var showFileBrowser = true
    @State private var fileBrowserWidth: CGFloat = 260
    @State private var showSettings = false
    @State private var customizingTab: TabItem?

    private var activeTab: TabItem? {
        sessionManager.tabs.first { $0.id == sessionManager.activeTabID }
    }

    private var isSSHTab: Bool {
        activeTab?.type == .ssh
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            if showSidebar {
                SidebarView()
                    .frame(width: sidebarWidth)
                    .background(VisualEffectBackground(material: .sidebar, blendingMode: .withinWindow))

                PanelResizeHandle(width: $sidebarWidth, min: 180, max: 400)
            }

            // Main area
            VStack(spacing: 0) {
                TabBarView(
                    showSidebar: $showSidebar,
                    showFileBrowser: $showFileBrowser,
                    isSSHTab: isSSHTab,
                    customizingTab: $customizingTab
                )
                GlassDivider()

                if let tab = activeTab, tab.type == .ssh, let config = tab.sessionConfig {
                    HStack(spacing: 0) {
                        terminalStack

                        if showFileBrowser {
                            PanelResizeHandle(width: $fileBrowserWidth, minWidth: 180, maxWidth: 500, direction: -1)
                            FileBrowserView(config: config, isVisible: $showFileBrowser)
                                .id(config.id)
                                .frame(width: fileBrowserWidth)
                                .background(VisualEffectBackground(material: .sidebar, blendingMode: .withinWindow))
                        }
                    }
                } else {
                    terminalStack
                }
            }
        }
        .background(VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow))
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(item: $customizingTab) { tab in
            TabThemeEditorView(tabID: tab.id, tabTitle: tab.title)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            showSettings = true
        }
    }

    private var terminalStack: some View {
        ZStack {
            // Background uses the active tab's resolved theme
            Color(nsColor: {
                if let tab = activeTab {
                    let theme = themeManager.resolvedTheme(for: tab)
                    return NSColor(hex: theme.backgroundColorHex)
                }
                return NSColor(hex: TerminalTheme.defaultDark.backgroundColorHex)
            }())
            ForEach(sessionManager.tabs) { tab in
                TerminalContainer(tab: tab)
                    .opacity(sessionManager.activeTabID == tab.id ? 1 : 0)
                    .allowsHitTesting(sessionManager.activeTabID == tab.id)
            }
        }
    }
}
