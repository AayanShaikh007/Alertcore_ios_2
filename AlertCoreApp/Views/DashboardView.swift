import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var state: AppState
    private let sensorZones = [41, 42, 43, 44, 45, 46, 49, 50, 51, 52, 53, 54]

    var body: some View {
        ZStack {
            Theme.darkBg.ignoresSafeArea()
            
            // Subtle neon glow background blobs for a premium visual effect
            VStack {
                HStack {
                    Circle()
                        .fill(Theme.accentGreen.opacity(0.12))
                        .frame(width: 200, height: 200)
                        .blur(radius: 80)
                        .offset(x: -50, y: -50)
                    Spacer()
                }
                Spacer()
                HStack {
                    Spacer()
                    Circle()
                        .fill(Theme.accentCoral.opacity(0.1))
                        .frame(width: 250, height: 250)
                        .blur(radius: 90)
                        .offset(x: 50, y: 50)
                }
            }
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header Bar
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AlertCore")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(state.connected ? Theme.accentGreen : Theme.accentCoral)
                                    .frame(width: 8, height: 8)
                                    .shadow(color: state.connected ? Theme.accentGreen : Theme.accentCoral, radius: 3)
                                
                                Text(state.connected ? "Connected" : "Disconnected")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(state.connected ? Theme.accentGreen : Theme.accentCoral)
                            }
                        }
                        
                        Spacer()
                        
                        // Mini telemetry badge
                        if state.objectPresent {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Theme.accentCoral)
                                .font(.system(size: 22))
                                .shadow(color: Theme.accentCoral.opacity(0.5), radius: 6)
                        } else {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(Theme.accentGreen)
                                .font(.system(size: 22))
                        }
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, 4)

                    // Primary Metric Card (Shortest Distance)
                    VStack(spacing: 12) {
                        HStack {
                            Text("SHORTEST DISTANCE")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                        }
                        
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            if let distance = state.distanceCm {
                                Text("\(distance)")
                                    .font(.system(size: 64, weight: .black, design: .rounded))
                                    .foregroundColor(state.objectPresent ? Theme.accentCoral : Theme.textPrimary)
                                Text("cm")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                            } else {
                                Text("--")
                                    .font(.system(size: 64, weight: .black, design: .rounded))
                                    .foregroundColor(Theme.inactiveGrey)
                            }
                            Spacer()
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                        
                        HStack {
                            Text("SYSTEM STATE")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text(state.objectPresent ? "ALERT ACTIVE" : "SECURED")
                                .font(.system(size: 12, weight: .black))
                                .foregroundColor(state.objectPresent ? Theme.accentCoral : Theme.accentGreen)
                        }
                    }
                    .glassCardStyle(borderColor: state.objectPresent ? Theme.accentCoral.opacity(0.3) : .white.opacity(0.15))

                    // Multizone 2x6 Grid Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DETECTION ZONE MAP (FLIPPED)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                        
                        VStack(spacing: 8) {
                            // Row 1: 11 down to 6
                            HStack(spacing: 8) {
                                ForEach([11, 10, 9, 8, 7, 6], id: \.self) { idx in
                                    ZoneCellView(
                                        zoneNumber: sensorZones[idx],
                                        distance: state.zonesCm.indices.contains(idx) && state.zonesCm[idx] >= 0 ? state.zonesCm[idx] : nil,
                                        threshold: state.thresholdCm
                                    )
                                }
                            }
                            
                            // Row 2: 5 down to 0
                            HStack(spacing: 8) {
                                ForEach([5, 4, 3, 2, 1, 0], id: \.self) { idx in
                                    ZoneCellView(
                                        zoneNumber: sensorZones[idx],
                                        distance: state.zonesCm.indices.contains(idx) && state.zonesCm[idx] >= 0 ? state.zonesCm[idx] : nil,
                                        threshold: state.thresholdCm
                                    )
                                }
                            }
                        }
                    }
                    .glassCardStyle()

                    // History Chart Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("DISTANCE HISTORY (\(state.graphMinutes) MIN)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text("Thresh: \(state.thresholdCm)cm")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Theme.accentCoral)
                        }
                        
                        HistoryChart(samples: state.history, threshold: state.thresholdCm)
                            .frame(height: 180)
                            .padding(.top, 8)
                    }
                    .glassCardStyle()

                    // Footer version code
                    Text("AlertCore V 2.7")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.textSecondary.opacity(0.5))
                        .padding(.vertical, 16)
                }
                .padding()
            }
        }
    }
}

struct ZoneCellView: View {
    let zoneNumber: Int
    let distance: Int?
    let threshold: Int

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Text("Z\(zoneNumber)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
            }
            
            Spacer()
            
            if let dist = distance, dist > 0 {
                Text("\(dist)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(dist <= threshold ? Theme.accentCoral : Theme.accentGreen)
            } else {
                Text("--")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.inactiveGrey)
            }
            
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    distance != nil && distance! > 0 && distance! <= threshold
                    ? Theme.accentCoral.opacity(0.12)
                    : Color.white.opacity(0.03)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    distance != nil && distance! > 0
                    ? (distance! <= threshold ? Theme.accentCoral : Theme.accentGreen.opacity(0.3))
                    : Theme.inactiveGrey.opacity(0.2),
                    lineWidth: distance != nil && distance! > 0 && distance! <= threshold ? 1.5 : 1
                )
        )
        .shadow(
            color: distance != nil && distance! > 0 && distance! <= threshold ? Theme.accentCoral.opacity(0.2) : .clear,
            radius: 4, x: 0, y: 0
        )
    }
}

struct HistoryChart: View {
    let samples: [DistanceSampleDto]
    let threshold: Int

    var body: some View {
        GeometryReader { geo in
            let sortedSamples = samples
                .filter { $0.distanceCm > 0 }
                .sorted(by: { $0.timestampMs < $1.timestampMs })

            if sortedSamples.isEmpty {
                VStack {
                    Spacer()
                    Text("Waiting for samples...")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                    Spacer()
                }
            } else {
                let latestTime = sortedSamples.last!.timestampMs
                let firstTime = sortedSamples.first!.timestampMs
                let dataSpanMs = latestTime - firstTime

                let minWindowMs: Int64 = 10_000 // 10 seconds
                let maxWindowMs: Int64 = 60 * 60_000 // 60 minutes
                let windowWidthMs = max(minWindowMs, min(maxWindowMs, dataSpanMs))

                let windowStartMs = latestTime - windowWidthMs
                let visibleSamples = sortedSamples.filter { $0.timestampMs >= windowStartMs }

                if visibleSamples.isEmpty {
                    VStack {
                        Spacer()
                        Text("Waiting for samples...")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                            .frame(maxWidth: .infinity)
                        Spacer()
                    }
                } else {
                    let minDistance = Double(visibleSamples.map { $0.distanceCm }.min() ?? 0)
                    let maxDistance = Double(visibleSamples.map { $0.distanceCm }.max() ?? 100)
                    
                    let minY = minDistance - 2.0
                    let maxY = maxDistance + 2.0
                    let yRange = max(1.0, maxY - minY)
                    let xRange = max(1.0, Double(windowWidthMs))

                    let w = geo.size.width
                    let h = geo.size.height

                    let points: [CGPoint] = visibleSamples.map { sample in
                        let xNorm = Double(sample.timestampMs - windowStartMs) / xRange
                        let yNorm = (Double(sample.distanceCm) - minY) / yRange
                        return CGPoint(
                            x: w * CGFloat(xNorm),
                            y: h - h * CGFloat(yNorm)
                        )
                    }

                    ZStack {
                        // Threshold reference line
                        Path { path in
                            let thresholdNorm = (Double(threshold) - minY) / yRange
                            let y = h - h * CGFloat(thresholdNorm)
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: w, y: y))
                        }
                        .stroke(Theme.accentCoral.opacity(0.4), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [4, 4]))

                        // Main distance graph line
                        if !points.isEmpty {
                            Path { path in
                                path.move(to: CGPoint(x: points[0].x, y: h))
                                for p in points {
                                    path.addLine(to: p)
                                }
                                path.addLine(to: CGPoint(x: points.last!.x, y: h))
                                path.close()
                            }
                            .fill(
                                LinearGradient(
                                    colors: [Theme.accentCoral.opacity(0.25), Theme.accentCoral.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                            Path { path in
                                path.move(to: points[0].x, points[0].y)
                                if points.count == 1 {
                                    path.addLine(to: CGPoint(x: points[0].x + 10, y: points[0].y))
                                } else {
                                    for i in 0..<(points.count - 1) {
                                        let p0 = points[i]
                                        let p1 = points[i+1]
                                        let cx1 = p0.x + (p1.x - p0.x) / 3.0
                                        let cx2 = p0.x + 2.0 * (p1.x - p0.x) / 3.0
                                        path.addCurve(to: p1, control1: CGPoint(x: cx1, y: p0.y), control2: CGPoint(x: cx2, y: p1.y))
                                    }
                                }
                            }
                            .stroke(
                                Theme.accentCoral,
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                            )
                        }
                    }
                }
            }
        }
    }
}
