import SwiftUI
@preconcurrency import WebKit

struct BookWebView: NSViewRepresentable {
    @ObservedObject var state: ReaderState

    func makeCoordinator() -> Coordinator { Coordinator(state) }
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        config.websiteDataStore = .nonPersistent()
        config.userContentController.add(context.coordinator, name: "position")
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.setValue(false, forKey: "drawsBackground")
        web.allowsBackForwardNavigationGestures = false
        context.coordinator.web = web
        // Prevent remote resources embedded in a local book from making network requests.
        let coordinator = context.coordinator
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "FolioLocalOnly", encodedContentRuleList:
            #"[{"trigger":{"url-filter":"^https?://"},"action":{"type":"block"}}]"#) { list, _ in
                if let list {
                    web.configuration.userContentController.add(list)
                    coordinator.rulesReady = true
                    coordinator.loadPending()
                } else { coordinator.state.webError = "无法初始化本地阅读环境，请重新打开应用。" }
            }
        return web
    }

    func updateNSView(_ web: WKWebView, context: Context) {
        let coordinator = context.coordinator
        let style = Self.style(size: state.fontSize, dark: state.dark)
        if coordinator.style != style {
            coordinator.style = style
            web.configuration.userContentController.removeAllUserScripts()
            web.configuration.userContentController.addUserScript(WKUserScript(source: Self.script(style), injectionTime: .atDocumentEnd, forMainFrameOnly: true))
            web.evaluateJavaScript(Self.applyStyle(style))
        }
        guard coordinator.request != state.request, let url = state.location, let book = state.book else { return }
        coordinator.request = state.request
        coordinator.restoring = true
        coordinator.restoreScroll = state.restoreScroll
        coordinator.hasFragment = url.fragment != nil
        coordinator.pending = (url, book.root)
        coordinator.loadPending()
    }

    static func dismantleNSView(_ web: WKWebView, coordinator: Coordinator) {
        web.stopLoading()
        web.configuration.userContentController.removeScriptMessageHandler(forName: "position")
        web.navigationDelegate = nil
    }

    static func style(size: Double, dark: Bool) -> String {
        """
        :root {color-scheme: \(dark ? "dark" : "light");}
        html {background: \(dark ? "#20221F" : "#F8F5EF") !important; color: \(dark ? "#E6E2D8" : "#302E29") !important; -webkit-text-size-adjust:100%; scroll-behavior:auto;}
        body {box-sizing:border-box !important; width:auto !important; max-width:68ch !important; margin:0 auto !important; padding:54px 48px 96px !important; font-family:Georgia,'Songti SC','Hiragino Mincho ProN','YuMincho',serif !important; font-size:\(Int(size))px !important; line-height:1.8 !important; color:inherit !important; background:transparent !important; overflow-wrap:break-word; text-align:start;}
        body * {font-family:inherit !important; color:inherit;}
        p,li,div,section,article {font-size:1em !important; line-height:inherit !important;}
        p {margin-block:0 1.05em !important;}
        h1,h2,h3,h4 {line-height:1.3 !important; text-wrap:balance; margin-block:1.8em .8em !important; letter-spacing:-.02em;}
        h1 {font-size:1.9em !important;} h2 {font-size:1.5em !important;} h3 {font-size:1.2em !important;}
        img,svg,video {max-width:100% !important; height:auto; object-fit:contain;}
        img {max-height:78vh;} svg {max-height:80vh;}
        a {color:\(dark ? "#BAC5A5" : "#5B6548") !important; text-underline-offset:.18em;}
        a:focus-visible {outline:2px solid currentColor; outline-offset:4px;}
        ::selection {background:\(dark ? "#4E5940" : "#DDE1D1");}
        pre {white-space:pre-wrap;} table {max-width:100%; display:block; overflow:auto;}
        @media(max-width:600px) {body {padding:30px 25px 70px !important;}}
        """
    }
    static func applyStyle(_ style: String) -> String {
        let json = String(data: try! JSONSerialization.data(withJSONObject: [style]), encoding: .utf8)!
        return """
        (()=>{let s=document.getElementById('folio-reading-style'); if(!s){s=document.createElement('style');s.id='folio-reading-style';document.head.appendChild(s);}s.textContent=\(json)[0];})();
        """
    }
    static func script(_ style: String) -> String {
        applyStyle(style) + """
        ;(()=>{let timer;window.addEventListener('scroll',()=>{clearTimeout(timer);timer=setTimeout(()=>{const h=Math.max(0,document.documentElement.scrollHeight-innerHeight);window.webkit.messageHandlers.position.postMessage(h?scrollY/h:0);},180);},{passive:true});})();
        """
    }

    @MainActor final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let state: ReaderState
        weak var web: WKWebView?
        var request: UUID?
        var style = ""
        var restoring = false
        var restoreScroll = 0.0
        var hasFragment = false
        var rulesReady = false
        var pending: (URL, URL)?
        init(_ state: ReaderState) { self.state = state }

        func loadPending() {
            guard rulesReady, let (url, root) = pending else { return }
            pending = nil
            web?.loadFileURL(url, allowingReadAccessTo: root)
        }

        private func evaluate(_ script: String, in web: WKWebView?) {
            // The async WebKit overlay force-unwraps an undefined JS result on some macOS versions.
            web?.evaluateJavaScript(script, completionHandler: { _, _ in })
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard !restoring, let fraction = message.body as? Double else { return }
            state.receivePosition(fraction)
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let fraction = restoreScroll
            let restoringRequest = request
            let script = hasFragment ? "void(0)" : "window.scrollTo(0,Math.max(0,document.documentElement.scrollHeight-innerHeight)*\(fraction))"
            // A second restoration after images/fonts settle prevents tall covers from moving the saved position.
            evaluate(script, in: webView)
            Task { @MainActor [weak self, weak webView] in
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard let self, self.request == restoringRequest, self.state.request == restoringRequest else { return }
                self.evaluate(script, in: webView)
                self.restoring = false
            }
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
            guard let book = state.book, book.contains(url) else { decisionHandler(.cancel); return }
            if navigationAction.navigationType == .linkActivated {
                decisionHandler(.cancel)
                state.navigate(url)
            } else { decisionHandler(.allow) }
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled { state.webError = "这一节未能载入，请从目录选择其他章节。" }
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            state.webError = "这一节未能载入，请从目录选择其他章节。"
        }
    }
}
