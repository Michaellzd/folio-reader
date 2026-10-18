import Foundation

enum AnnotationScript {
    static let source = #"""
    ;(()=>{
        const textNodes=()=>{
            const walker=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);
            const nodes=[];let node;while(node=walker.nextNode())nodes.push(node);return nodes;
        };
        window.folioSelection=()=>{
            const selection=window.getSelection();
            if(!selection||selection.isCollapsed||!selection.rangeCount)return null;
            const range=selection.getRangeAt(0);
            if(!document.body.contains(range.commonAncestorContainer))return null;
            const quote=range.toString();if(!quote.trim())return null;
            const before=range.cloneRange();before.selectNodeContents(document.body);before.setEnd(range.startContainer,range.startOffset);
            const start=before.toString().length,end=start+quote.length,text=document.body.textContent;
            return {start,end,quote,prefix:text.slice(Math.max(0,start-48),start),suffix:text.slice(end,end+48)};
        };
        let selectionTimer;
        document.addEventListener('selectionchange',()=>{
            clearTimeout(selectionTimer);selectionTimer=setTimeout(()=>{
                window.webkit.messageHandlers.selection.postMessage({selection:window.folioSelection(),request:window.folioRequest});
            },100);
        });
        window.folioRenderMarks=marks=>{
            document.querySelectorAll('mark.folio-mark').forEach(mark=>mark.replaceWith(...mark.childNodes));
            const text=document.body.textContent;
            for(const mark of marks){
                let start=mark.start,end=mark.end;
                if(text.slice(start,end)!==mark.quote){
                    const found=[];let index=text.indexOf(mark.quote);
                    while(index>=0){
                        if((!mark.prefix||text.slice(Math.max(0,index-mark.prefix.length),index)===mark.prefix)&&
                           (!mark.suffix||text.slice(index+mark.quote.length,index+mark.quote.length+mark.suffix.length)===mark.suffix))found.push(index);
                        index=text.indexOf(mark.quote,index+1);
                    }
                    if(found.length!==1)continue;
                    start=found[0];end=start+mark.quote.length;
                }
                let position=0;const pieces=[];
                for(const node of textNodes()){
                    const length=node.textContent.length;
                    if(length>0&&position<end&&position+length>start&&!['SCRIPT','STYLE'].includes(node.parentElement.tagName)){
                        pieces.push({node,start:Math.max(0,start-position),end:Math.min(length,end-position)});
                    }
                    position+=length;
                }
                for(const piece of pieces.reverse()){
                    const range=document.createRange();range.setStart(piece.node,piece.start);range.setEnd(piece.node,piece.end);
                    const element=document.createElement('mark');element.className='folio-mark';element.dataset.folioId=mark.id;
                    element.style.setProperty('background-color',mark.color,'important');
                    element.style.setProperty('color','#292820','important');
                    element.style.setProperty('border-radius','2px');
                    element.style.setProperty('cursor','pointer');
                    element.title=mark.note||mark.label;element.tabIndex=0;element.setAttribute('role','button');
                    element.setAttribute('aria-label',mark.note||mark.label);
                    range.surroundContents(element);
                }
            }
        };
        const activate=event=>{
            const mark=event.target.closest&&event.target.closest('mark.folio-mark');
            if(!mark)return;
            if(event.type==='keydown'&&!['Enter',' '].includes(event.key))return;
            if(window.getSelection()&&!window.getSelection().isCollapsed)return;
            event.preventDefault();event.stopPropagation();
            window.webkit.messageHandlers.annotation.postMessage({id:mark.dataset.folioId,request:window.folioRequest});
        };
        document.addEventListener('click',activate,true);document.addEventListener('keydown',activate,true);
    })();
    """#

    static func render(_ json: String) -> String {
        "if(window.folioRenderMarks){window.folioRenderMarks(\(json));}"
    }
}
