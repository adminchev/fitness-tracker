internal import SwiftUI
import SwiftData
import Charts

/// Per-exercise trend chart. Lets you pick a metric (1RM / top weight / volume / reps),
/// a time window, and — for unilateral exercises — a side (Both / Left / Right).
///
/// `points` (and per-side / PR values) are cached in `@State` and recomputed only when
/// the metric/range change, so scrubbing and side-toggling stay smooth on long windows.
/// In "Both" view, colour encodes side (two lines); otherwise dots are coloured by how
/// close the logged RPE was to the prescribed target.
struct ExerciseProgressView: View {
    let definition: ExerciseDefinition
    @State private var metric: ProgressMetric = .oneRepMax
    @State private var range: ProgressRange = .threeMonths
    @State private var selectedSide: SetSide?      // nil = Both (sided) or all (non-sided)
    @State private var rawSelection: Date?

    // Cached so scrubbing / side-toggling don't recompute the whole dataset.
    @State private var leftPoints: [MetricPoint] = []
    @State private var rightPoints: [MetricPoint] = []
    @State private var nonSidedPoints: [MetricPoint] = []
    @State private var prValues: [ProgressMetric: Double] = [:]

    private let accent = Color.accentColor

    private var loggedExercises: [Exercise] {
        (definition.exercises ?? []).filter { $0.sets?.isEmpty == false }
    }

    private var tracksSides: Bool { definition.tracksSides }
    private var isBoth: Bool { tracksSides && selectedSide == nil }

    private var unit: String {
        metric == .totalReps ? "reps" : (definition.equipment.loadUnit ?? "")
    }

    private var displayPoints: [MetricPoint] {
        guard tracksSides else { return nonSidedPoints }
        switch selectedSide {
        case .none: return leftPoints + rightPoints
        case .left: return leftPoints
        case .right: return rightPoints
        }
    }

    private var selectedPoint: MetricPoint? {
        guard let rawSelection else { return nil }
        return displayPoints.min {
            abs($0.date.timeIntervalSince(rawSelection)) < abs($1.date.timeIntervalSince(rawSelection))
        }
    }

    var body: some View {
        List {
            Section {
                header
                chart
                    .frame(height: 260)
                    .padding(.top, 4)
            }
            .listRowSeparator(.hidden)

            Section {
                if tracksSides {
                    controlRow("Side") {
                        Picker("Side", selection: $selectedSide) {
                            Text("Both").tag(SetSide?.none)
                            Text("Left").tag(SetSide?.some(.left))
                            Text("Right").tag(SetSide?.some(.right))
                        }
                        .pickerStyle(.segmented)
                    }
                }
                controlRow("Time range") {
                    Picker("Range", selection: $range) {
                        ForEach(ProgressRange.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                controlRow("Metric") {
                    Picker("Metric", selection: $metric) {
                        ForEach(ProgressMetric.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }

            Section("Personal Bests") {
                prRow("Est. 1RM", .oneRepMax)
                prRow("Top weight", .topWeight)
                prRow("Best volume", .volume)
                prRow("Most reps", .totalReps)
            }
        }
        .navigationTitle(definition.name)
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.2), value: selectedSide)
        .onAppear(perform: recompute)
        .onChange(of: metric) { recompute() }
        .onChange(of: range) { recompute() }
    }

    private func recompute() {
        if tracksSides {
            leftPoints = ProgressCalculator.points(for: loggedExercises, metric: metric, range: range, side: .left)
            rightPoints = ProgressCalculator.points(for: loggedExercises, metric: metric, range: range, side: .right)
            nonSidedPoints = []
        } else {
            nonSidedPoints = ProgressCalculator.points(for: loggedExercises, metric: metric, range: range, side: nil)
            leftPoints = []
            rightPoints = []
        }
        prValues = Dictionary(uniqueKeysWithValues: ProgressMetric.allCases.map {
            ($0, ProgressCalculator.best(for: loggedExercises, metric: $0, side: nil))
        })
    }

    // MARK: - Header

    @ViewBuilder private var header: some View {
        if let selectedPoint {
            scrubHeader(selectedPoint)
        } else if isBoth {
            imbalanceHeader
        } else {
            singleHeader
        }
    }

    private func scrubHeader(_ point: MetricPoint) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(metric.rawValue.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(format(point.value))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text(unit).font(.title3).foregroundStyle(.secondary)
                if !point.side.isEmpty {
                    Text(point.side == SetSide.left.rawValue ? "Left" : "Right")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.quaternary, in: Capsule())
                }
            }
            Text(scrubSubtitle(point))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func scrubSubtitle(_ point: MetricPoint) -> String {
        let date = point.date.formatted(.dateTime.month(.abbreviated).day())
        return point.breakdown.isEmpty ? date : "\(date)  ·  \(point.breakdown)"
    }

    private var singleHeader: some View {
        let latest = displayPoints.last
        let earliest = displayPoints.first
        let delta = (latest?.value ?? 0) - (earliest?.value ?? 0)
        return VStack(alignment: .leading, spacing: 6) {
            Text(metric.rawValue.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(format(latest?.value ?? 0))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text(unit).font(.title3).foregroundStyle(.secondary)
                if abs(delta) > 0.05 { deltaChip(delta) }
            }
            Text(displayPoints.isEmpty ? "No data in \(range.label)" : "over \(range.label)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var imbalanceHeader: some View {
        let left = leftPoints.last?.value
        let right = rightPoints.last?.value
        return VStack(alignment: .leading, spacing: 6) {
            Text("LEFT vs RIGHT — \(metric.rawValue.uppercased())")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                sideStat("L", left)
                sideStat("R", right)
                if let left, let right, left > 0 {
                    let diff = (right - left) / left * 100
                    Text("Δ \(diff, format: .number.precision(.fractionLength(0)))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.quaternary, in: Capsule())
                }
            }
            Text("latest, over \(range.label)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sideStat(_ label: String, _ value: Double?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(label).font(.caption.weight(.bold)).foregroundStyle(.secondary)
            Text(value.map(format) ?? "—")
                .font(.system(size: 26, weight: .bold, design: .rounded))
            Text(unit).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func deltaChip(_ delta: Double) -> some View {
        let improving = delta > 0
        let tint: Color = improving ? .green : .red
        return HStack(spacing: 2) {
            Image(systemName: improving ? "arrow.up.right" : "arrow.down.right")
            Text("\(format(abs(delta))) \(unit)")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(tint.opacity(0.12), in: Capsule())
    }

    // MARK: - Chart

    @ViewBuilder private var chart: some View {
        if displayPoints.isEmpty {
            ContentUnavailableView(
                "No Data Yet",
                systemImage: "chart.xyaxis.line",
                description: Text("Log this exercise to see your trend.")
            )
            .frame(height: 220)
        } else {
            Chart {
                ForEach(displayPoints) { point in
                    if isBoth {
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value(metric.rawValue, point.value),
                            series: .value("Side", point.side)
                        )
                        .foregroundStyle(by: .value("Side", point.side == SetSide.left.rawValue ? "Left" : "Right"))
                        .interpolationMethod(.catmullRom)
                    } else {
                        AreaMark(x: .value("Date", point.date), y: .value(metric.rawValue, point.value))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(areaGradient)
                        LineMark(x: .value("Date", point.date), y: .value(metric.rawValue, point.value))
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .foregroundStyle(accent)
                        if displayPoints.count <= 31 {
                            PointMark(x: .value("Date", point.date), y: .value(metric.rawValue, point.value))
                                .foregroundStyle(color(for: point.adherence))
                                .symbolSize(60)
                        }
                    }
                }

                if let selectedPoint {
                    RuleMark(x: .value("Date", selectedPoint.date))
                        .foregroundStyle(Color.secondary.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                    PointMark(x: .value("Date", selectedPoint.date), y: .value(metric.rawValue, selectedPoint.value))
                        .foregroundStyle(isBoth ? (selectedPoint.side == SetSide.left.rawValue ? Color.blue : Color.orange) : accent)
                        .symbolSize(110)
                }
            }
            .chartForegroundStyleScale(["Left": Color.blue, "Right": Color.orange])
            .chartLegend(isBoth ? .visible : .hidden)
            .chartXSelection(value: $rawSelection)
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) {
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) {
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                    AxisValueLabel()
                }
            }
        }
    }

    private var areaGradient: LinearGradient {
        LinearGradient(colors: [accent.opacity(0.35), accent.opacity(0.04)], startPoint: .top, endPoint: .bottom)
    }

    private func color(for adherence: Adherence) -> Color {
        switch adherence {
        case .onTarget: .green
        case .near: .orange
        case .off: .red
        case .unknown: accent
        }
    }

    private func controlRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    // MARK: - Helpers

    private func prRow(_ label: String, _ prMetric: ProgressMetric) -> some View {
        let value = prValues[prMetric] ?? 0
        let prUnit = prMetric == .totalReps ? "reps" : (definition.equipment.loadUnit ?? "")
        let text = value > 0 ? "\(format(value)) \(prUnit)" : "—"
        return LabeledContent(label, value: text)
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
