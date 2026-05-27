import SwiftUI
import UIKit

struct CameraView: View {
    @EnvironmentObject var state: AppState

    // baseline stream height to apply 1.5x scale when no explicit height exists
    let baselineStreamHeight: CGFloat = 200

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("Live camera")
                        .font(.title)
                    CardView {
                        VStack(alignment: .leading) {
                            Text("Distance")
                            Text(state.distanceCm != nil ? "\(state.distanceCm!) cm" : "--")
                                .font(.title)
                            Text(state.objectPresent ? "Alert state: TRIGGERED" : "Alert state: NORMAL")
                                .foregroundColor(state.objectPresent ? .red : .green)
                            HStack(spacing: 12) {
                                Button(action: openCameraWebsite) {
                                    Text("Open camera website")
                                        .padding(8)
                                        .background(Color.green)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }

                CameraWebView(pageUrl: state.cameraPageUrl)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
                    .frame(minHeight: baselineStreamHeight * 1.5)
                    .cornerRadius(8)
                    .clipped()
                    .padding()
            }
            .padding()
        }
    }

    func openCameraWebsite() {
        guard let url = URL(string: state.cameraPageUrl) else { return }
        UIApplication.shared.open(url)
    }
}
