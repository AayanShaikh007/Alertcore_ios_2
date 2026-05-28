import SwiftUI
import UIKit

struct CameraView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                CameraWebView(pageUrl: state.cameraPageUrl)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Live camera")
                                .font(.title2.weight(.bold))
                                .foregroundColor(.white)
                            Text(state.objectPresent ? "Alert state: TRIGGERED" : "Alert state: NORMAL")
                                .foregroundColor(state.objectPresent ? .red : .green)
                                .font(.headline)
                        }

                        Spacer()

                        Button(action: openCameraWebsite) {
                            Text("Open website")
                                .font(.callout.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(.black.opacity(0.65))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Distance")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.9))
                        Text(state.distanceCm != nil ? "\(state.distanceCm!) cm" : "--")
                            .font(.system(size: 54, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 20)
                }
                .padding(.top, 16)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
        }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    func openCameraWebsite() {
        guard let url = URL(string: state.cameraPageUrl) else { return }
        UIApplication.shared.open(url)
    }
}
