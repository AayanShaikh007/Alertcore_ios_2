import SwiftUI
import UIKit

struct CameraView: View {
    @EnvironmentObject var state: AppState

    // baseline stream height; the live box is rendered at a fixed 600pt height
    let baselineStreamHeight: CGFloat = 300

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
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
                    .frame(height: 600)
                    .cornerRadius(8)
                    .clipped()
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
        }
    }

    func openCameraWebsite() {
        guard let url = URL(string: state.cameraPageUrl) else { return }
        UIApplication.shared.open(url)
    }
}
