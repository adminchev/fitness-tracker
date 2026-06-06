internal import SwiftUI
import SwiftData

/// The accessible ("fried-forearm") logger: one exercise, one field at a time, every
/// value a giant stepper. Designed so the right action is easy to hit and the wrong
/// one is hard to trigger — pinned context, controls anchored in the reachable lower
/// third, a deliberate hold to commit a set, a large Undo for stray taps, and
/// destructive actions tucked behind a guarded menu. VoiceOver- and Dynamic-Type-aware.
struct GuidedLoggerView: View {
    @Bindable var exercise: Exercise
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.effortScaleKey) private var effortRaw = EffortScale.rpe.rawValue

    @State private var stepIndex = 0
    @State private var undoStack: [() -> Void] = []
    @State private var prior: [WorkoutSet] = []
    @State private var loadedPrior = false
    @State private var confirmingDelete = false

    private var scale: EffortScale { EffortScale(rawValue: effortRaw) ?? .rpe }
    private var steps: [LogStep] { GuidedLogger.steps(for: exercise) }
    private var currentStep: LogStep? { steps.indices.contains(stepIndex) ? steps[stepIndex] : nil }

    var body: some View {
        VStack(spacing: 20) {
            if let step = currentStep {
                header(step)
                Spacer(minLength: 0)            // void sits up top; controls stay reachable
                fieldSection(step)
                controls(step)
            } else {
                ContentUnavailableView("No sets", systemImage: "checkmark.circle")
            }
        }
        .padding(20)
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { moreMenu }
        }
        .confirmationDialog("Delete this set?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete set", role: .destructive) { deleteCurrentSet() }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            if !loadedPrior { prior = PreviousSession.sets(for: exercise); loadedPrior = true }
        }
    }

    // MARK: - Header (pinned context)

    private func header(_ step: LogStep) -> some View {
        VStack(spacing: 8) {
            Text(armAndSet(step))
                .font(.headline)
                .foregroundStyle(.secondary)
            fieldDots(step)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(headerLabel(step))
    }

    private func armAndSet(_ step: LogStep) -> String {
        let arm: String
        switch step.set.side {
        case SetSide.left.rawValue: arm = "Left · "
        case SetSide.right.rawValue: arm = "Right · "
        default: arm = ""
        }
        return "\(arm)Set \(step.setNumber) of \(step.setCount)"
    }

    private func headerLabel(_ step: LogStep) -> String {
        let fields = setFields(for: step)
        let index = (fields.firstIndex(of: step.field) ?? 0) + 1
        return "\(armAndSet(step)), \(fieldTitle(step.field)), field \(index) of \(fields.count)"
    }

    /// Dots showing field progress within the current set (decorative — the header's
    /// accessibility label carries this for VoiceOver).
    private func fieldDots(_ step: LogStep) -> some View {
        let fields = setFields(for: step)
        let index = fields.firstIndex(of: step.field) ?? 0
        return HStack(spacing: 8) {
            ForEach(Array(fields.enumerated()), id: \.offset) { offset, _ in
                Circle()
                    .fill(offset == index ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 9, height: 9)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - The one field

    private func fieldSection(_ step: LogStep) -> some View {
        VStack(spacing: 12) {
            Text(fieldTitle(step.field))
                .font(.title2.weight(.bold))
            if let hint = lastTimeHint(step) {
                Text(hint)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
            GuidedField(set: step.set, field: step.field,
                        equipment: exercise.equipment, scale: scale,
                        onChange: { snapshotForUndo(step) })
                .padding(.top, 4)
            if isEmpty(step) {
                Text("Tap the number to type, or use − / +")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func fieldTitle(_ field: LogField) -> String {
        switch field {
        case .weight: "Weight"
        case .reps: "Reps"
        case .duration: "Hold"
        case .effort: scale.rawValue
        }
    }

    /// Whether the current field has no value yet (so we show the tap-to-enter hint).
    private func isEmpty(_ step: LogStep) -> Bool {
        switch step.field {
        case .weight:   step.set.weight == nil
        case .reps:     step.set.reps == nil
        case .duration: step.set.durationSeconds == nil
        case .effort:   step.set.rpe == nil
        }
    }

    /// The matching set from last session, shown as a faint target under the value.
    private func lastTimeHint(_ step: LogStep) -> String? {
        let sameSide = prior.filter { $0.side == step.set.side }
        guard sameSide.indices.contains(step.setNumber - 1) else { return nil }
        let was = sameSide[step.setNumber - 1]
        switch step.field {
        case .weight:
            return was.weight.map { "last: \(format($0)) \(exercise.equipment.loadUnit ?? "")" }
        case .reps:
            return was.reps.map { "last: \($0)" }
        case .duration:
            return was.durationSeconds.map { "last: \($0)s" }
        case .effort:
            return was.rpe.map { "last: \(format(scale.display($0)))" }
        }
    }

    // MARK: - Controls (advance · back · undo)

    private func controls(_ step: LogStep) -> some View {
        VStack(spacing: 12) {
            advanceButton(step)
            HStack(spacing: 12) {
                Button(action: back) {
                    Label("Back", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.bordered)
                Button(action: undo) {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.bordered)
                .disabled(undoStack.isEmpty)
            }
            .font(.headline)
        }
    }

    @ViewBuilder
    private func advanceButton(_ step: LogStep) -> some View {
        if !startsNewSet {
            // Low-stakes field nav — a single tap is fine.
            Button {
                stepIndex += 1
            } label: {
                advanceLabel("Next", "arrow.right")
            }
            .buttonStyle(.borderedProminent)
        } else if isFinalStep {
            // Committing the whole exercise — deliberate hold.
            HoldButton(title: "Finish", systemImage: "checkmark") { dismiss() }
        } else {
            // Committing a set and moving on — deliberate hold so a shake can't skip.
            HoldButton(title: "Save set", systemImage: "arrow.down") { stepIndex += 1 }
        }
    }

    private func advanceLabel(_ title: String, _ symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 64)
    }

    private var moreMenu: some View {
        Menu {
            Button { addSet() } label: { Label("Add set", systemImage: "plus") }
            if exercise.tracksSides, let step = currentStep {
                Button { copyToOtherSide(from: step.set) } label: {
                    Label("Copy this arm → other", systemImage: "arrow.left.arrow.right")
                }
            }
            Button(role: .destructive) { confirmingDelete = true } label: {
                Label("Delete this set", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("More actions")
    }

    // MARK: - Step shape helpers

    private func setFields(for step: LogStep) -> [LogField] {
        steps.filter { $0.set === step.set }.map(\.field)
    }

    /// Would advancing from here start a different set (or finish the exercise)?
    private var startsNewSet: Bool {
        guard let step = currentStep else { return true }
        let next = stepIndex + 1
        if next >= steps.count { return true }
        return steps[next].set !== step.set
    }

    private var isFinalStep: Bool { stepIndex >= steps.count - 1 }

    // MARK: - Navigation / undo

    private func back() {
        if stepIndex > 0 {
            stepIndex -= 1
        } else {
            dismiss()
        }
    }

    private func snapshotForUndo(_ step: LogStep) {
        let set = step.set
        let restore: () -> Void
        switch step.field {
        case .weight:   let v = set.weight;          restore = { set.weight = v }
        case .reps:     let v = set.reps;            restore = { set.reps = v }
        case .duration: let v = set.durationSeconds; restore = { set.durationSeconds = v }
        case .effort:   let v = set.rpe;             restore = { set.rpe = v }
        }
        undoStack.append(restore)
        if undoStack.count > 50 { undoStack.removeFirst() }
    }

    private func undo() {
        guard let restore = undoStack.popLast() else { return }
        restore()
    }

    // MARK: - Set mutation (guarded / secondary)

    private func addSet() {
        let side: SetSide? = exercise.tracksSides ? (currentStep?.set.sideTag ?? AppSettings.leadSide) : nil
        let sideSets = (exercise.sets ?? []).filter { $0.side == (side?.rawValue ?? "") }
        let template = sideSets.last
        let newOrder = ((exercise.sets ?? []).map(\.order).max() ?? -1) + 1
        let newSet = WorkoutSet(
            reps: template?.reps,
            weight: template?.weight,
            durationSeconds: template?.durationSeconds,
            rpe: template?.rpe ?? exercise.targetRPE,
            side: side?.rawValue ?? "",
            order: newOrder
        )
        modelContext.insert(newSet)
        newSet.exercise = exercise
    }

    private func copyToOtherSide(from set: WorkoutSet) {
        guard let from = set.sideTag else { return }
        let other = from.opposite
        let source = (exercise.sets ?? []).filter { $0.side == from.rawValue }.sortedByOrder()
        (exercise.sets ?? []).filter { $0.side == other.rawValue }.forEach { modelContext.delete($0) }
        var order = ((exercise.sets ?? []).map(\.order).max() ?? -1) + 1
        for set in source {
            let copy = WorkoutSet(reps: set.reps, weight: set.weight, durationSeconds: set.durationSeconds,
                                  rpe: set.rpe, side: other.rawValue, order: order)
            order += 1
            modelContext.insert(copy)
            copy.exercise = exercise
        }
    }

    private func deleteCurrentSet() {
        guard let set = currentStep?.set else { return }
        modelContext.delete(set)
        // Snap back to a valid step; leave if that was the last set.
        if steps.isEmpty { dismiss() }
        stepIndex = min(stepIndex, max(steps.count - 1, 0))
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}

/// Renders the giant control for whichever field the guided logger is on. Observes
/// the set directly (`@Bindable`) so stepper changes persist and redraw.
private struct GuidedField: View {
    @Bindable var set: WorkoutSet
    let field: LogField
    let equipment: Equipment
    let scale: EffortScale
    let onChange: () -> Void

    var body: some View {
        switch field {
        case .weight:
            BigStepper(value: $set.weight, step: equipment.loadStep, label: "Weight",
                       unit: equipment.loadUnit, onChange: onChange)
        case .reps:
            BigStepper(value: $set.reps.asDouble, step: 1, label: "Reps", unit: "reps",
                       isInteger: true, onChange: onChange)
        case .duration:
            VStack(spacing: 10) {
                TimedSetField(seconds: $set.durationSeconds, large: true)
                    .font(.system(size: 44, weight: .semibold).monospacedDigit())
                    .accessibilityLabel("Hold seconds")
                Text("sec").font(.headline).foregroundStyle(.secondary)
            }
        case .effort:
            BigStepper(value: effortBinding, step: 0.5, label: scale.rawValue,
                       unit: scale.rawValue, upperBound: 10, onChange: onChange)
        }
    }

    /// Steps the *displayed* scale; stores canonical RPE.
    private var effortBinding: Binding<Double?> {
        Binding(
            get: { set.rpe.map(scale.display) },
            set: { set.rpe = $0.map(scale.canonical) }
        )
    }
}

/// A full-width button that fires only after a brief hold, filling as you press — so a
/// shaky double-tap can't commit or skip a set. Releasing early cancels. For VoiceOver /
/// Switch Control it acts as an ordinary button (activation fires immediately; the hold
/// is a sighted-touch anti-mistap device).
private struct HoldButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0
    @State private var task: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .leading) {
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.accentColor.opacity(0.35))
                    .frame(width: geo.size.width * progress)
            }
            Label("\(title)  (hold)", systemImage: systemImage)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .background(Color.accentColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 16))
        .contentShape(.rect)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in startHold() }
                .onEnded { _ in cancelHold() }
        )
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { action() }
    }

    private func startHold() {
        guard task == nil else { return }
        task = Task { @MainActor in
            let ticks = 24
            for tick in 1...ticks {
                try? await Task.sleep(for: .seconds(0.5 / Double(ticks)))
                if Task.isCancelled { return }
                progress = CGFloat(tick) / CGFloat(ticks)
            }
            action()
            progress = 0
            task = nil
        }
    }

    private func cancelHold() {
        task?.cancel()
        task = nil
        if reduceMotion {
            progress = 0
        } else {
            withAnimation(.easeOut(duration: 0.15)) { progress = 0 }
        }
    }
}
