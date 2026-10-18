import AppKit
@preconcurrency import WebKit

@MainActor
final class AnnotationRunner: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    var web: WKWebView!
    var activated = ""
    func run() {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(self, name: "selection")
        configuration.userContentController.add(self, name: "annotation")
        configuration.userContentController.addUserScript(WKUserScript(source: "window.folioRequest='test';" + AnnotationScript.source, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        web = WKWebView(frame: NSRect(x: 0, y: 0, width: 700, height: 700), configuration: configuration)
        web.navigationDelegate = self
        web.loadHTMLString("<html><body><p>Alpha 世界🙂 repeated <em>across elements</em> end.</p><p>Second paragraph: 世界🙂 repeated.</p><script>window.authorScriptRan=true;</script></body></html>", baseURL: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) { fputs("FAIL WebKit annotation test timeout\n", stderr); exit(1) }
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "annotation", let data = message.body as? [String: String] { activated = data["id"] ?? "" }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let script = #"""
        (()=>{
            let checks=0;const assert=(ok,message)=>{if(!ok)throw Error(message);checks++;};
            assert(typeof window.authorScriptRan==='undefined','Author scripts must remain disabled');
            const original=document.body.textContent,p=document.querySelector('p');
            const range=document.createRange();range.setStart(p.firstChild,6);range.setEnd(p.querySelector('em').firstChild,6);
            getSelection().removeAllRanges();getSelection().addRange(range);
            const selection=window.folioSelection();
            assert(selection.quote==='世界🙂 repeated across','Selection spans Unicode and inline elements');
            assert(original.slice(selection.start,selection.end)===selection.quote,'Offsets use the same UTF-16 convention as the DOM');
            getSelection().removeAllRanges();
            const mark={...selection,id:'test-a',color:'#E9C96A',note:'メモ <img onerror="bad()">',label:'Add note'};
            window.folioRenderMarks([mark]);
            assert(Array.from(document.querySelectorAll('mark')).map(x=>x.textContent).join('')===selection.quote,'Highlight wraps the exact text across elements');
            assert(document.body.textContent===original,'Highlight preserves book text');
            assert(document.querySelectorAll('p')[1].querySelectorAll('mark').length===0,'Repeated text in another paragraph stays unmarked');
            assert(document.querySelectorAll('img').length===0,'Note text is never parsed as HTML');
            assert(document.querySelector('mark').style.backgroundColor==='rgb(233, 201, 106)','Chosen color is applied');
            window.folioRenderMarks([mark]);
            assert(document.querySelectorAll('mark').length===2,'Repeated rendering does not accumulate wrappers');
            const shortQuote='世界🙂';
            const overlap={id:'test-b',start:selection.start,end:selection.start+shortQuote.length,quote:shortQuote,prefix:'',suffix:'',color:'#9DC99A',note:'Another note',label:'Add note'};
            window.folioRenderMarks([mark,overlap]);
            assert(document.querySelector('[data-folio-id="test-b"]').textContent===shortQuote,'Overlapping highlights remain readable');
            assert(document.body.textContent===original,'Overlapping highlights preserve source text');
            window.folioRenderMarks([]);
            const multiRange=document.createRange(),paragraphs=document.querySelectorAll('p');
            multiRange.setStart(paragraphs[0],0);multiRange.setEnd(paragraphs[1].firstChild,17);
            getSelection().addRange(multiRange);const multi=window.folioSelection();getSelection().removeAllRanges();
            window.folioRenderMarks([{...mark,...multi}]);
            assert(Array.from(document.querySelectorAll('mark')).map(x=>x.textContent).join('')===multi.quote,'Cross-paragraph selections preserve an exact highlight range');
            assert(document.querySelectorAll('p')[0].querySelector('mark')&&document.querySelectorAll('p')[1].querySelector('mark'),'Cross-paragraph highlight appears in both paragraphs');
            window.folioRenderMarks([{...mark,start:0,end:1}]);
            assert(document.querySelector('mark').textContent.startsWith('世界'),'Context resolves stale offsets without marking a duplicate');
            document.querySelector('mark').click();
            window.folioRenderMarks([]);
            assert(document.querySelectorAll('mark').length===0&&document.body.textContent===original,'Removing a highlight restores clean book markup');
            return checks;
        })();
        """#
        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard error == nil, let count = result as? Int else { fputs("FAIL \(String(describing: error))\n", stderr); exit(1) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                guard self?.activated == "test-a" else { fputs("FAIL Highlight click did not reach native note editor bridge\n", stderr); exit(1) }
                print("PASS \(count + 1) WebKit highlight checks"); exit(0)
            }
        }
    }
}

@main
@MainActor
struct AnnotationTests {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let runner = AnnotationRunner()
        runner.run()
        withExtendedLifetime(runner) { app.run() }
    }
}
