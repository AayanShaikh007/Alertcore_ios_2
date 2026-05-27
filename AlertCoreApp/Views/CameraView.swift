import SwiftUI
import UIKit

struct CameraView: View {
    @EnvironmentObject var state: AppState

    // baseline stream height to apply 1.5x scale when no explicit height exists
    // increased to give a visibly taller stream container
    let baselineStreamHeight: CGFloat = 300

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
                    .cornerRadius(8)
                    .frame(height: baselineStreamHeight * 1.5)
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
