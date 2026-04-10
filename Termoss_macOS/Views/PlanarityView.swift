import SwiftUI
import AppKit

private let sfx = GameSoundManager.shared

// MARK: - Model

struct PlanarityVertex: Identifiable, Equatable {
    let id: Int
    var position: CGPoint  // normalized [0,1] in board space
}

struct PlanarityEdge: Identifiable, Hashable {
    let id: Int
    let a: Int  // vertex id
    let b: Int  // vertex id
}

final class PlanarityGame: ObservableObject {
    @Published var vertices: [PlanarityVertex] = []
    @Published var edges: [PlanarityEdge] = []
    @Published var level: Int = 5  // number of lines used to build the graph
    @Published var isCustom: Bool = false
    @Published var customVertexCount: Int = 20  // target dot count for custom mode
    @Published var moves: Int = 0
    @Published var startedAt: Date = Date()

    // Cached crossing edges, invalidated whenever vertices/edges change.
    // Critical for performance: crossingEdges() is called many times per
    // SwiftUI render (once per vertex view + stat pills + isSolved check),
    // and the underlying O(E²) segment-intersection loop is expensive
    // once dot counts climb into the dozens.
    private var _cachedCrossings: Set<Int>? = nil

    init() {
        newGame()
    }

    // MARK: Level generation (line-intersection method)
    //
    // We generate `level` random lines in the unit square. Each pairwise
    // intersection becomes a vertex, and each line's intersections (sorted
    // along the line) are connected consecutively. This guarantees the
    // graph has a planar layout (the solution).
    //
    // In custom mode we pick enough lines to overshoot the target vertex
    // count, then randomly trim down. Removing vertices also removes
    // their incident edges, so the resulting graph is still a subgraph
    // of a planar graph — which is itself planar (solution still exists).
    func newGame() {
        moves = 0
        startedAt = Date()

        var attempt = 0
        while attempt < 40 {
            attempt += 1
            if isCustom {
                let target = max(4, min(120, customVertexCount))
                // Rough estimate: v ≈ n*(n-1)/2 after filtering, so start
                // a little above √(2v) and jitter.
                let base = max(4, Int(ceil((1.0 + (1.0 + 8.0 * Double(target)).squareRoot()) / 2.0)))
                let n = base + Int.random(in: 0...3)
                if generateLevel(lineCount: n, trimTo: target) { return }
            } else {
                if generateLevel(lineCount: level, trimTo: nil) { return }
            }
        }
        // Fallback — simple cycle
        generateFallback()
    }

    @discardableResult
    private func generateLevel(lineCount n: Int, trimTo: Int? = nil) -> Bool {
        struct Line { let p: CGPoint; let d: CGPoint }

        var lines: [Line] = []
        for _ in 0..<n {
            let angle = CGFloat.random(in: 0..<(2 * .pi))
            // Random point near center
            let px = CGFloat.random(in: 0.2...0.8)
            let py = CGFloat.random(in: 0.2...0.8)
            let dx = cos(angle)
            let dy = sin(angle)
            lines.append(Line(p: CGPoint(x: px, y: py), d: CGPoint(x: dx, y: dy)))
        }

        // Solution positions for each pairwise intersection
        var solutionPositions: [CGPoint] = []
        // For each line: list of (t, vertexIndex) pairs
        var lineHits: [[(t: CGFloat, vi: Int)]] = Array(repeating: [], count: n)

        for i in 0..<n {
            for j in (i + 1)..<n {
                let l1 = lines[i], l2 = lines[j]
                let denom = l1.d.x * l2.d.y - l1.d.y * l2.d.x
                if abs(denom) < 1e-9 { continue }  // parallel
                let dx = l2.p.x - l1.p.x
                let dy = l2.p.y - l1.p.y
                let t1 = (dx * l2.d.y - dy * l2.d.x) / denom
                let t2 = (dx * l1.d.y - dy * l1.d.x) / denom
                let x = l1.p.x + t1 * l1.d.x
                let y = l1.p.y + t1 * l1.d.y
                // Keep intersections inside the unit square (with margin)
                if x < 0.08 || x > 0.92 || y < 0.08 || y > 0.92 { continue }
                let vi = solutionPositions.count
                solutionPositions.append(CGPoint(x: x, y: y))
                lineHits[i].append((t1, vi))
                lineHits[j].append((t2, vi))
            }
        }

        // Need at least enough vertices to make an interesting graph
        guard solutionPositions.count >= max(4, n) else { return false }

        var edgesArr: [PlanarityEdge] = []
        for hits in lineHits {
            let sorted = hits.sorted { $0.t < $1.t }
            if sorted.count < 2 { continue }
            for k in 0..<(sorted.count - 1) {
                let a = sorted[k].vi
                let b = sorted[k + 1].vi
                if a == b { continue }
                edgesArr.append(PlanarityEdge(id: edgesArr.count, a: a, b: b))
            }
        }

        guard !edgesArr.isEmpty else { return false }

        // Trim vertices down to target count if requested
        if let target = trimTo {
            if solutionPositions.count < target { return false }
            if solutionPositions.count > target {
                let excess = solutionPositions.count - target
                let indices = Array(0..<solutionPositions.count).shuffled()
                let removeSet = Set(indices.prefix(excess))

                var oldToNew: [Int: Int] = [:]
                var newPositions: [CGPoint] = []
                for (oldIdx, pos) in solutionPositions.enumerated() {
                    if removeSet.contains(oldIdx) { continue }
                    oldToNew[oldIdx] = newPositions.count
                    newPositions.append(pos)
                }
                solutionPositions = newPositions

                var newEdges: [PlanarityEdge] = []
                for e in edgesArr {
                    guard let a = oldToNew[e.a], let b = oldToNew[e.b] else { continue }
                    newEdges.append(PlanarityEdge(id: newEdges.count, a: a, b: b))
                }
                edgesArr = newEdges
                if edgesArr.count < max(3, target / 2) { return false }
            }
        }

        // Scramble: place vertices on a shuffled circle layout
        let m = solutionPositions.count
        var circlePositions: [CGPoint] = []
        let radius: CGFloat = 0.38
        for i in 0..<m {
            let angle = (CGFloat(i) / CGFloat(m)) * 2 * .pi - .pi / 2
            circlePositions.append(CGPoint(
                x: 0.5 + radius * cos(angle),
                y: 0.5 + radius * sin(angle)
            ))
        }
        circlePositions.shuffle()

        var result: [PlanarityVertex] = []
        for i in 0..<m {
            result.append(PlanarityVertex(id: i, position: circlePositions[i]))
        }

        // Only accept if the initial layout actually has crossings
        self.vertices = result
        self.edges = edgesArr
        self._cachedCrossings = nil
        if crossingEdges().isEmpty {
            return false  // too easy, try again
        }
        return true
    }

    private func generateFallback() {
        let n = 8
        var verts: [PlanarityVertex] = []
        for i in 0..<n {
            let angle = CGFloat(i) / CGFloat(n) * 2 * .pi
            verts.append(PlanarityVertex(
                id: i,
                position: CGPoint(x: 0.5 + 0.35 * cos(angle), y: 0.5 + 0.35 * sin(angle))
            ))
        }
        verts.shuffle()
        var ev: [PlanarityEdge] = []
        for i in 0..<n {
            ev.append(PlanarityEdge(id: i, a: i, b: (i + 1) % n))
        }
        // Add a few diagonals
        for k in stride(from: 0, to: n, by: 2) {
            ev.append(PlanarityEdge(id: ev.count, a: k, b: (k + n / 2) % n))
        }
        self.vertices = verts
        self.edges = ev
        self._cachedCrossings = nil
    }

    // MARK: Crossings

    /// Returns the set of edge ids that currently cross another edge.
    /// Result is cached until the next vertex move or new game.
    func crossingEdges() -> Set<Int> {
        if let cached = _cachedCrossings { return cached }
        let result = computeCrossings()
        _cachedCrossings = result
        return result
    }

    private func computeCrossings() -> Set<Int> {
        var crossing = Set<Int>()
        // Vertex ids are dense 0..<vertices.count in our generator, but
        // guard with a safe lookup fallback just in case.
        let count = vertices.count
        var posByID = [CGPoint](repeating: .zero, count: count)
        var valid = [Bool](repeating: false, count: count)
        for v in vertices where v.id >= 0 && v.id < count {
            posByID[v.id] = v.position
            valid[v.id] = true
        }

        let edgeCount = edges.count
        for i in 0..<edgeCount {
            let e1 = edges[i]
            guard e1.a < count, e1.b < count, valid[e1.a], valid[e1.b] else { continue }
            let p1 = posByID[e1.a]
            let p2 = posByID[e1.b]
            for j in (i + 1)..<edgeCount {
                let e2 = edges[j]
                // Edges sharing a vertex never "cross" in Planarity
                if e1.a == e2.a || e1.a == e2.b || e1.b == e2.a || e1.b == e2.b { continue }
                guard e2.a < count, e2.b < count, valid[e2.a], valid[e2.b] else { continue }
                let p3 = posByID[e2.a]
                let p4 = posByID[e2.b]
                if Self.segmentsIntersect(p1, p2, p3, p4) {
                    crossing.insert(e1.id)
                    crossing.insert(e2.id)
                }
            }
        }
        return crossing
    }

    var isSolved: Bool { crossingEdges().isEmpty }

    func invalidateCrossings() {
        _cachedCrossings = nil
    }

    func moveVertex(id: Int, to newPosition: CGPoint) {
        guard let idx = vertices.firstIndex(where: { $0.id == id }) else { return }
        // Clamp to [0.02, 0.98]
        let clamped = CGPoint(
            x: min(max(newPosition.x, 0.02), 0.98),
            y: min(max(newPosition.y, 0.02), 0.98)
        )
        if vertices[idx].position != clamped {
            vertices[idx].position = clamped
            _cachedCrossings = nil
        }
    }

    func endMove() {
        moves += 1
    }

    // Strict segment intersection test (proper crossing only).
    private static func segmentsIntersect(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ p4: CGPoint) -> Bool {
        func ccw(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
            return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
        }
        let d1 = ccw(p3, p4, p1)
        let d2 = ccw(p3, p4, p2)
        let d3 = ccw(p1, p2, p3)
        let d4 = ccw(p1, p2, p4)
        if ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
           ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0)) {
            return true
        }
        return false
    }
}

// MARK: - View

struct PlanarityView: View {
    @StateObject private var game = PlanarityGame()
    @State private var draggingVertexID: Int? = nil
    @State private var showConfetti: Bool = false
    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer? = nil
    @State private var wasSolved: Bool = false  // track solve moment for sound

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                GlassDivider()

                board
                    .padding(20)
            }

            if game.isSolved {
                winOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .frame(minWidth: 640, minHeight: 720)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: game.isSolved)
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Planarity")
                    .font(.system(size: 18, weight: .semibold))
                Text("Drag the vertices so no edges cross")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Stats pills
            HStack(spacing: 6) {
                statPill(icon: "arrow.up.left.and.down.right.magnifyingglass", value: "\(game.crossingEdges().count / 2)", label: "crossings")
                statPill(icon: "hand.draw", value: "\(game.moves)", label: "moves")
                statPill(icon: "clock", value: formatElapsed(elapsed), label: nil)
            }

            // Level selector
            HStack(spacing: 6) {
                Text("Level")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Menu {
                    ForEach(3...9, id: \.self) { n in
                        Button("\(n)") {
                            wasSolved = false
                            game.isCustom = false
                            game.level = n
                            game.newGame()
                            restartTimer()
                        }
                    }
                    Divider()
                    Button("Custom…") {
                        wasSolved = false
                        game.isCustom = true
                        game.newGame()
                        restartTimer()
                    }
                } label: {
                    Text(game.isCustom ? "Custom" : "\(game.level)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .monospacedDigit()
                }
                .menuStyle(.borderlessButton)
                .frame(width: 70)

                if game.isCustom {
                    HStack(spacing: 4) {
                        Stepper(
                            "",
                            value: Binding(
                                get: { game.customVertexCount },
                                set: { newVal in
                                    game.customVertexCount = newVal
                                    game.newGame()
                                    restartTimer()
                                }
                            ),
                            in: 4...120,
                            step: 1
                        )
                        .labelsHidden()
                        Text("\(game.customVertexCount) dots")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }

            GlassPillButton(title: "New Game", style: .secondary) {
                wasSolved = false
                game.newGame()
                restartTimer()
                sfx.newGame()
            }

            MuteButton()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func statPill(icon: String, value: String, label: String?) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
            if let label {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule(style: .continuous).fill(Color.white.opacity(0.05)))
        .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
        .clipShape(Capsule(style: .continuous))
    }

    // MARK: Board

    private var board: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let boardSize = CGSize(width: side, height: side)
            let origin = CGPoint(
                x: (proxy.size.width - side) / 2,
                y: (proxy.size.height - side) / 2
            )
            let crossings = game.crossingEdges()
            let solved = crossings.isEmpty

            ZStack {
                // Board background — glass pane
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.04),
                                Color.white.opacity(0.01)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.18),
                                        Color.white.opacity(0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    )
                    .shadow(color: .black.opacity(0.25), radius: 20, y: 8)

                // Edges layer
                Canvas { context, size in
                    let vs = game.vertices
                    let count = vs.count
                    // Dense lookup array — vertex ids are 0..<count
                    var posByID = [CGPoint](repeating: .zero, count: count)
                    for v in vs where v.id >= 0 && v.id < count {
                        posByID[v.id] = CGPoint(
                            x: v.position.x * size.width,
                            y: v.position.y * size.height
                        )
                    }

                    let calmColor = Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.55)
                    let crossColor = Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.85)

                    // Pass 1: draw non-crossing edges
                    var calm = Path()
                    for edge in game.edges {
                        if crossings.contains(edge.id) { continue }
                        if edge.a >= count || edge.b >= count { continue }
                        calm.move(to: posByID[edge.a])
                        calm.addLine(to: posByID[edge.b])
                    }
                    context.stroke(calm, with: .color(calmColor), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))

                    // Pass 2: draw crossing edges on top
                    var cross = Path()
                    for edge in game.edges {
                        if !crossings.contains(edge.id) { continue }
                        if edge.a >= count || edge.b >= count { continue }
                        cross.move(to: posByID[edge.a])
                        cross.addLine(to: posByID[edge.b])
                    }
                    context.stroke(cross, with: .color(crossColor), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                }
                .allowsHitTesting(false)

                // Vertices layer
                ForEach(game.vertices) { vertex in
                    PlanarityVertexView(
                        isDragging: draggingVertexID == vertex.id,
                        isSolved: solved
                    )
                    .position(
                        x: vertex.position.x * boardSize.width,
                        y: vertex.position.y * boardSize.height
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .local)
                            .onChanged { value in
                                if draggingVertexID != vertex.id {
                                    draggingVertexID = vertex.id
                                    sfx.pickup()
                                }
                                let newPos = CGPoint(
                                    x: value.location.x / boardSize.width,
                                    y: value.location.y / boardSize.height
                                )
                                game.moveVertex(id: vertex.id, to: newPos)
                            }
                            .onEnded { _ in
                                if draggingVertexID == vertex.id {
                                    game.endMove()
                                    sfx.drop()
                                }
                                draggingVertexID = nil
                                // Check if just solved
                                if game.isSolved && !wasSolved {
                                    wasSolved = true
                                    sfx.solve()
                                }
                            }
                    )
                }
            }
            .frame(width: side, height: side)
            .offset(x: origin.x, y: origin.y)
        }
    }

    // MARK: Win overlay

    private var winOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40, weight: .thin))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.yellow, Color.orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Text("Solved!")
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                VStack(spacing: 4) {
                    Text(game.isCustom
                         ? "\(game.vertices.count) dots — \(game.moves) moves"
                         : "Level \(game.level) — \(game.moves) moves")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text(formatElapsed(elapsed))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    GlassPillButton(title: "Play Again", style: .accent) {
                        wasSolved = false
                        game.newGame()
                        restartTimer()
                        sfx.newGame()
                    }
                    if game.isCustom {
                        if game.customVertexCount < 120 {
                            GlassPillButton(title: "Add 3 Dots", style: .secondary) {
                                wasSolved = false
                                game.customVertexCount = min(120, game.customVertexCount + 3)
                                game.newGame()
                                restartTimer()
                                sfx.newGame()
                            }
                        }
                    } else if game.level < 9 {
                        GlassPillButton(title: "Next Level", style: .secondary) {
                            wasSolved = false
                            game.level += 1
                            game.newGame()
                            restartTimer()
                            sfx.newGame()
                        }
                    }
                }
                .padding(.top, 6)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 30, y: 10)
            )
        }
    }

    // MARK: Timer helpers

    private func startTimer() {
        timer?.invalidate()
        elapsed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if !game.isSolved {
                elapsed = Date().timeIntervalSince(game.startedAt)
            }
        }
    }

    private func restartTimer() { startTimer() }

    private func formatElapsed(_ t: TimeInterval) -> String {
        let total = Int(t)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Vertex View (liquid glass bead)

struct PlanarityVertexView: View {
    var isDragging: Bool
    var isSolved: Bool
    @State private var isHovering: Bool = false

    var body: some View {
        ZStack {
            // Minimalist glass bead — brighter gray, centered soft highlight
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            beadColor.opacity(0.95),
                            beadColor.opacity(0.9)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 9
                    )
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isHovering || isDragging ? 0.65 : 0.45), lineWidth: 0.5)
                )
                .frame(width: isDragging ? 15 : 12.5, height: isDragging ? 15 : 12.5)
                .shadow(color: Color.black.opacity(0.3), radius: isDragging ? 3 : 2, y: 1)

            // Soft centered highlight
            Circle()
                .fill(Color.white.opacity(isHovering || isDragging ? 0.38 : 0.22))
                .frame(width: 6, height: 6)
                .blur(radius: 1.2)
        }
        .contentShape(Circle().inset(by: -12))  // larger hit target
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDragging)
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }

    private var baseColor: Color {
        if isSolved {
            // Soft minty glass tint when solved
            return Color(red: 0.55, green: 0.78, blue: 0.62)
        }
        // Brighter neutral gray glass
        return Color(white: 0.82)
    }

    private var beadColor: Color {
        if isSolved {
            return isHovering || isDragging
                ? Color(red: 0.72, green: 0.92, blue: 0.78)
                : baseColor
        }
        return isHovering || isDragging ? Color(white: 0.97) : baseColor
    }
}
