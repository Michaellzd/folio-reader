import AppKit
let out = CommandLine.arguments[1]
let directory = URL(fileURLWithPath: out)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16,32,64,128,256,512,1024] {
    let image = NSImage(size: NSSize(width:size,height:size))
    image.lockFocus()
    let scale = CGFloat(size)/1024
    let transform = NSAffineTransform(); transform.scale(by: scale); transform.concat()
    NSColor(calibratedRed:0.27,green:0.32,blue:0.23,alpha:1).setFill()
    NSBezierPath(roundedRect:NSRect(x:40,y:40,width:944,height:944),xRadius:215,yRadius:215).fill()
    let book = NSBezierPath()
    book.move(to:NSPoint(x:512,y:690))
    book.curve(to:NSPoint(x:225,y:740),controlPoint1:NSPoint(x:405,y:765),controlPoint2:NSPoint(x:310,y:777))
    book.line(to:NSPoint(x:225,y:310))
    book.curve(to:NSPoint(x:512,y:260),controlPoint1:NSPoint(x:334,y:354),controlPoint2:NSPoint(x:421,y:323))
    book.curve(to:NSPoint(x:799,y:310),controlPoint1:NSPoint(x:603,y:323),controlPoint2:NSPoint(x:690,y:354))
    book.line(to:NSPoint(x:799,y:740))
    book.curve(to:NSPoint(x:512,y:690),controlPoint1:NSPoint(x:714,y:777),controlPoint2:NSPoint(x:619,y:765))
    NSColor(calibratedRed:0.96,green:0.94,blue:0.87,alpha:1).setFill(); book.fill()
    let spine = NSBezierPath(); spine.move(to:NSPoint(x:512,y:280)); spine.line(to:NSPoint(x:512,y:682)); spine.lineWidth=12
    NSColor(calibratedRed:0.53,green:0.56,blue:0.44,alpha:1).setStroke(); spine.stroke()
    let ribbon = NSBezierPath(); ribbon.move(to:NSPoint(x:668,y:735)); ribbon.line(to:NSPoint(x:668,y:533)); ribbon.line(to:NSPoint(x:707,y:562)); ribbon.line(to:NSPoint(x:746,y:540)); ribbon.line(to:NSPoint(x:746,y:747)); ribbon.close()
    NSColor(calibratedRed:0.69,green:0.49,blue:0.31,alpha:1).setFill(); ribbon.fill()
    image.unlockFocus()
    let rep=NSBitmapImageRep(data:image.tiffRepresentation!)!
    let png=rep.representation(using:.png,properties:[:])!
    let name = size == 1024 ? "icon_512x512@2x.png" : size == 64 ? "icon_32x32@2x.png" : "icon_\(size)x\(size).png"
    try png.write(to:directory.appendingPathComponent(name))
    if [32,256,512].contains(size) {
        try png.write(to:directory.appendingPathComponent("icon_\(size/2)x\(size/2)@2x.png"))
    }
}
