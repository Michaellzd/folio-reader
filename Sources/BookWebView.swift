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
        config.userContentController.add(context.coordinator, name: "selection")
        config.userContentController.add(context.coordinator, name: "annotation")
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.setValue(false, forKey: "drawsBackground")
        web.allowsBackForwardNavigationGestures = false
        context.coordinator.web = web
        state.webView = web
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
        let highlights = state.highlightsJSON
        if coordinator.highlights != highlights {
            coordinator.highlights = highlights
            web.evaluateJavaScript(AnnotationScript.render(highlights), completionHandler: nil)
        }
        if coordinator.style != style {
            coordinator.style = style
            web.configuration.userContentController.removeAllUserScripts()
            web.configuration.userContentController.addUserScript(WKUserScript(source: Self.script(style, request: state.request), injectionTime: .atDocumentEnd, forMainFrameOnly: true))
            web.evaluateJavaScript(Self.applyStyle(style))
        }
        guard coordinator.request != state.request, let url = state.location, let book = state.book else { return }
        coordinator.request = state.request
        web.configuration.userContentController.removeAllUserScripts()
        web.configuration.userContentController.addUserScript(WKUserScript(source: Self.script(style, request: state.request), injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        coordinator.restoring = true
        coordinator.restoreScroll = state.restoreScroll
        coordinator.restorePoint = state.restorePoint
        coordinator.hasFragment = url.fragment != nil && state.restorePoint == nil
        coordinator.pending = (url, book.root)
        coordinator.loadPending()
    }

    static func dismantleNSView(_ web: WKWebView, coordinator: Coordinator) {
        web.stopLoading()
        web.configuration.userContentController.removeScriptMessageHandler(forName: "position")
        web.configuration.userContentController.removeScriptMessageHandler(forName: "selection")
        web.configuration.userContentController.removeScriptMessageHandler(forName: "annotation")
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
    static func script(_ style: String, request: UUID) -> String {
        applyStyle(style) + """
        ;(()=>{
            window.folioRequest='\(request.uuidString)';
            const selector='p,h1,h2,h3,h4,li,blockquote,pre,figure';
            window.folioSnapshot=()=>{
                const max=Math.max(0,document.documentElement.scrollHeight-innerHeight);
                const nodes=Array.from(document.querySelectorAll(selector));
                let anchor=null,offset=null;
                if(scrollY>1){
                    const index=nodes.findIndex(el=>{const r=el.getBoundingClientRect();return r.height>0&&r.bottom>0;});
                    if(index>=0){const r=nodes[index].getBoundingClientRect();anchor=index;offset=-r.top/Math.max(1,r.height);}
                }
                return {scroll:max?scrollY/max:0,anchor,offset,quote:String(window.getSelection()||'').slice(0,4000),selection:window.folioSelection?window.folioSelection():null};
            };
            let queued=false;
            const report=()=>{if(queued)return;queued=true;requestAnimationFrame(()=>{queued=false;window.webkit.messageHandlers.position.postMessage({...window.folioSnapshot(),request:'\(request.uuidString)'});});};
            window.addEventListener('scroll',report,{passive:true});
            window.addEventListener('pagehide',report);
        })();
        """ + AnnotationScript.source
    }

    @MainActor final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let state: ReaderState
        weak var web: WKWebView?
        var request: UUID?
        var style = ""
        var highlights = ""
        var restoring = false
        var restoreScroll = 0.0
        var restorePoint: ReadingPoint?
        var hasFragment = false
        var rulesReady = false
        var pending: (URL, URL)?
        init(_ state: ReaderState) { self.state = state }

        func loadPending() {
            guard rulesReady, let (url, root) = pending else { return }
            pending = nil
            // WebKit treats a fragment-only change as same-document navigation and
            // skips didFinish. Always load the document, then restore its target below.
            var document = URLComponents(url: url, resolvingAgainstBaseURL: false)
            document?.fragment = nil
            guard let documentURL = document?.url else { return }
            web?.loadFileURL(documentURL, allowingReadAccessTo: root)
        }

        private func evaluate(_ script: String, in web: WKWebView?) {
            // The async WebKit overlay force-unwraps an undefined JS result on some macOS versions.
            web?.evaluateJavaScript(script, completionHandler: { _, _ in })
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard !restoring, let snapshot = message.body as? [String: Any], snapshot["request"] as? String == state.request.uuidString else { return }
            switch message.name {
            case "selection": state.selection = ReaderState.decodeSelection(snapshot["selection"])
            case "annotation":
                if let id = snapshot["id"] as? String, let mark = state.marks.first(where: { $0.id.uuidString == id }) { state.editNote(mark) }
            default:
                if let fraction = snapshot["scroll"] as? Double {
                    state.receivePosition(fraction, anchor: snapshot["anchor"] as? Int, offset: snapshot["offset"] as? Double)
                }
            }
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let fraction = restoreScroll
            evaluate(AnnotationScript.render(state.highlightsJSON), in: webView)
            let restoringRequest = request
            let anchorJSON = restorePoint?.anchor.map(String.init) ?? "null"
            let offset = restorePoint?.offset ?? 0
            let fragment = state.location.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.fragment } ?? ""
            let fragmentJSON = String(data: try! JSONSerialization.data(withJSONObject: [fragment]), encoding: .utf8)!
            var script = hasFragment ? """
            (()=>{const id=\(fragmentJSON)[0];const target=document.getElementById(id)||document.getElementsByName(id)[0];
            if(target){target.scrollIntoView({block:'start'});}else{scrollTo(0,0);}})();
            """ : """
            (()=>{const nodes=document.querySelectorAll('p,h1,h2,h3,h4,li,blockquote,pre,figure');
            const index=\(anchorJSON),max=Math.max(0,document.documentElement.scrollHeight-innerHeight);
            let y=max*\(fraction);
            if(index!==null&&nodes[index]){const r=nodes[index].getBoundingClientRect();y=scrollY+r.top+r.height*\(offset);}
            scrollTo(0,Math.min(max,Math.max(0,y)));})();
            """
            if let mark = state.restoreMark {
                script += ";document.querySelector('mark[data-folio-id=\"\(mark.uuidString)\"]')?.scrollIntoView({block:'center'});"
            }
            // A second restoration after images/fonts settle prevents tall covers from moving the saved position.
            evaluate(script, in: webView)
            Task { @MainActor [weak self, weak webView] in
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard let self, self.request == restoringRequest, self.state.request == restoringRequest else { return }
                self.evaluate(script, in: webView)
                self.restoring = false
                self.state.pageReady = true
                self.evaluate("window.dispatchEvent(new Event('scroll'))", in: webView)
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
