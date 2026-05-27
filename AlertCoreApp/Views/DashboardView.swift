import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AlertCore")
                        .font(.largeTitle)
                    Text("v1.0")
                        .font(.caption)
                }
                .padding()

                CardView {
                    VStack(alignment: .leading) {
                        Text("Distance")
                            .font(.title2)
                        Text(state.distanceCm != nil ? "\(state.distanceCm!) cm" : "--")
                            .font(.system(size: 48, weight: .bold))
                        Text(state.objectPresent ? "Alert state: TRIGGERED" : "Alert state: NORMAL")
                            .foregroundColor(state.objectPresent ? .red : .green)
                        Text(state.statusMessage)
                            .font(.caption)
                    }
                }

                CardView {
                    VStack(alignment: .leading) {
                        Text("Distance history (\(state.graphMinutes) min)")
                            .font(.headline)
                        // simple placeholder chart
                        HistoryChart(samples: state.history)
                            .frame(height: 220)
                    }
                }
            }
            .padding()
        }
    }
}

struct CardView<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
    }
}

struct HistoryChart: View {
    let samples: [DistanceSampleDto]

    var body: some View {
        GeometryReader { geo in
            if samples.isEmpty {
                Text("Waiting for samples...")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let maxV = (samples.map { $0.distanceCm }.max() ?? 1)
                let minV = (samples.map { $0.distanceCm }.min() ?? 0)
                Path { path in
                    for (i, s) in samples.enumerated() {
                        let x = geo.size.width * CGFloat(i) / CGFloat(max(1, samples.count - 1))
                        let y = geo.size.height * (1 - CGFloat((s.distanceCm - minV)) / CGFloat(max(1, maxV - minV)))
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(Color.green, lineWidth: 2)
            }
        }
    }
}
