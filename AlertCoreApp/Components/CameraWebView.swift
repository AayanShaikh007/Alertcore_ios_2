import Foundation
import SwiftUI
import WebKit

struct CameraWebView: UIViewRepresentable {
    let pageUrl: String

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        let webpagePreferences = WKWebpagePreferences()
        webpagePreferences.allowsContentJavaScript = true
        cfg.defaultWebpagePreferences = webpagePreferences
        let web = WKWebView(frame: .zero, configuration: cfg)
        web.allowsBackForwardNavigationGestures = false
        // allow scrolling inside the web view; the outer SwiftUI view also supports scrolling
        web.scrollView.isScrollEnabled = true
        web.backgroundColor = UIColor.black
        // background is black - keep the view opaque for proper rendering
        web.isOpaque = true
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let url = URL(string: pageUrl) else { return }
                if uiView.url?.absoluteString == pageUrl {
                        return
                }

        let isStream = pageUrl.contains("/stream")
        if isStream {
            let html = """
            <html>
              <head>
                <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />
                                <style>html,body{margin:0;background:#000;width:100%;height:100%;overflow:hidden;}img{position:fixed;inset:0;width:100vw;height:100vh;object-fit:cover;display:block;}</style>
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
