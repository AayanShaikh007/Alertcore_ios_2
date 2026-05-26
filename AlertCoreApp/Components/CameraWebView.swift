import Foundation
import SwiftUI
import WebKit

struct CameraWebView: UIViewRepresentable {
    let pageUrl: String

    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKPreferences()
        prefs.javaScriptEnabled = true
        let cfg = WKWebViewConfiguration()
        cfg.preferences = prefs
        let web = WKWebView(frame: .zero, configuration: cfg)
        web.allowsBackForwardNavigationGestures = false
        web.scrollView.isScrollEnabled = false
        web.backgroundColor = UIColor.black
        web.isOpaque = false
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let url = URL(string: pageUrl) else { return }
        let isStream = pageUrl.contains("/stream")
        if isStream {
            let html = """
            <html>
              <head>
                <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />
                <style>html,body{margin:0;background:#000;height:100%;}img{width:100%;height:100%;object-fit:contain;display:block;}</style>
              </head>
              <body>
                <img src=\"
            """ + pageUrl + "\" alt=\"stream\" />\n</body>\n</html>"
            uiView.loadHTMLString(html, baseURL: url)
        } else {
            let req = URLRequest(url: url)
            uiView.load(req)
        }
    }
}
