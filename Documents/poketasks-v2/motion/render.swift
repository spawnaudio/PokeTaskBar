import AppKit
import CoreGraphics
import ImageIO
import Foundation

// Standalone concept-film renderer. Reuses the existing motion-preview export
// approach and screenshot pixels; it never calls app stores or Linear mutations.
let base = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let output = base.appendingPathComponent("motion", isDirectory: true)
let W = 1440, H = 1000, fps = 60
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
var ctx: CGContext!
let shell = NSColor(srgbRed: 23/255, green: 24/255, blue: 27/255, alpha: 1)
func color(_ hex: Int, _ alpha: Double = 1) -> NSColor {
    NSColor(srgbRed: Double((hex >> 16) & 255)/255,
            green: Double((hex >> 8) & 255)/255, blue: Double(hex & 255)/255, alpha: alpha)
}
let panel = color(0x1F2023), ink = color(0xF1F1F3), muted = color(0x92949B)
func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
func smooth(_ x: Double) -> Double { let p = clamp(x); return p*p*(3-2*p) }
func step(_ t: Double, _ start: Double, _ duration: Double) -> Double {
    duration == 0 ? (t >= start ? 1 : 0) : smooth((t-start)/duration)
}
func mix(_ a: Double, _ b: Double, _ p: Double) -> Double { a+(b-a)*p }
func box(_ x: Double, _ y: Double, _ w: Double, _ h: Double,
         _ r: Double = 0, _ fill: NSColor = panel, _ outline: NSColor? = nil) {
    guard w > 0 && h > 0 else { return }
    let path = CGPath(roundedRect: CGRect(x:x,y:y,width:w,height:h), cornerWidth:r, cornerHeight:r, transform:nil)
    ctx.addPath(path); ctx.setFillColor(fill.cgColor); ctx.fillPath()
    if let outline { ctx.addPath(path); ctx.setStrokeColor(outline.cgColor); ctx.setLineWidth(1); ctx.strokePath() }
}
func clip(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r: Double = 0) {
    ctx.addPath(CGPath(roundedRect: CGRect(x:x,y:y,width:max(0,w),height:max(0,h)), cornerWidth:r, cornerHeight:r, transform:nil)); ctx.clip()
}
func text(_ s: String, _ x: Double, _ y: Double, _ size: Double = 16,
          _ weight: NSFont.Weight = .regular, _ c: NSColor = ink, _ width: Double = 1200, mono: Bool = false) {
    let p = NSMutableParagraphStyle(); p.lineBreakMode = .byTruncatingTail
    let f = mono ? NSFont.monospacedDigitSystemFont(ofSize:size,weight:weight) : NSFont.systemFont(ofSize:size,weight:weight)
    (s as NSString).draw(in:NSRect(x:x,y:y,width:width,height:size*1.5),
        withAttributes:[.font:f,.foregroundColor:c,.paragraphStyle:p])
}
let iconCache = NSMutableDictionary()
func icon(_ name: String, _ x: Double, _ y: Double, _ size: Double = 20, _ c: NSColor = ink, _ alpha: Double = 1) {
    let key = "\(name)-\(size)-\(c.description)" as NSString
    let im: NSImage
    if let saved = iconCache[key] as? NSImage { im = saved }
    else {
        guard let source = NSImage(systemSymbolName:name,accessibilityDescription:nil) else { return }
        im = source.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize:size,weight:.regular).applying(.init(paletteColors:[c]))) ?? source
        iconCache[key] = im
    }
    let aspect=im.size.width/max(1,im.size.height)
    let dw=aspect>=1 ? size:size*aspect, dh=aspect>=1 ? size/aspect:size
    im.draw(in:NSRect(x:x+(size-dw)/2,y:y+(size-dh)/2,width:dw,height:dh),from:.zero,operation:.sourceOver,fraction:alpha,respectFlipped:true,hints:nil)
}
func image(_ name: String) -> NSImage {
    let url = base.appendingPathComponent(name)
    guard let source = CGImageSourceCreateWithURL(url as CFURL,nil), let cg = CGImageSourceCreateImageAtIndex(source,0,nil) else { fatalError("Missing source: \(url.path)") }
    return NSImage(cgImage:cg,size:NSSize(width:cg.width,height:cg.height))
}
let projects = image("assets/references/current-projects-window.png")
let planner = image("assets/mockups/foldable-today-planner.png")
let timer = image("assets/mockups/timer-actions-over-title.png")
func slice(_ source: NSImage, _ src: NSRect, _ dst: NSRect, _ alpha: Double = 1) {
    guard dst.width > 0 && dst.height > 0 && alpha > 0 else { return }
    source.draw(in:dst,from:NSRect(x:src.minX,y:source.size.height-src.minY-src.height,width:src.width,height:src.height),
                operation:.sourceOver,fraction:alpha,respectFlipped:true,hints:[.interpolation:NSImageInterpolation.high])
}
func pointer(_ x: Double, _ y: Double, _ click: Double = -1) {
    if click >= 0 && click < 0.3 {
        let p = click/0.3, r = 7+p*16
        ctx.setStrokeColor(color(0x5C96EF,(1-p)*0.65).cgColor); ctx.setLineWidth(2)
        ctx.strokeEllipse(in:CGRect(x:x-r,y:y-r,width:r*2,height:r*2))
    }
    ctx.saveGState();ctx.setShadow(offset:CGSize(width:0,height:1),blur:2,color:color(0x000000,0.75).cgColor)
    icon("cursorarrow",x-2,y-1,24,ink);ctx.restoreGState()
}
func heading(_ title: String, _ detail: String, _ tag: String, _ t: Double, _ duration: Double) {
    text(title,42,28,29,.semibold)
    text(detail,42,70,16,.regular,muted)
    text(tag,1080,38,12,.medium,muted,320)
    text("POKETASKS v2  ·  MOTION CONCEPT  ·  1 OCT 2026",42,955,12,.medium,muted)
    text("Planning study · app behavior unchanged",1100,955,12,.regular,muted,300)
    box(42,986,1356,2,1,color(0x303238)); box(42,986,1356*clamp(t/duration),2,1,color(0x6F7787))
}
let navItems = [("Today","house"),("Focus","scope"),("Issues","list.bullet.rectangle"),
                ("Projects","folder"),("Collection","square.grid.2x2"),("Token usage","chart.bar")]
func nav(_ width: Double, _ selected: Int, _ labelAlpha: Double) {
    ctx.saveGState(); clip(53,191,width-8,716)
    slice(projects,NSRect(x:56,y:75,width:25,height:25),NSRect(x:66,y:209,width:25,height:25))
    ctx.saveGState(); ctx.setAlpha(labelAlpha)
    text("PokeTaskBar",103,211,17,.semibold); text("Your workspace",66,245,13,.regular,muted)
    ctx.restoreGState()
    box(59,285,width-20,34,7,color(0x27282C),color(0x383A41));icon("magnifyingglass",70,295,15)
    ctx.saveGState();ctx.setAlpha(labelAlpha);text("Search pages…",96,294,12,.regular,muted);ctx.restoreGState()
    for (i,item) in navItems.enumerated() {
        let y = 344+Double(i)*44
        if selected == i { box(59,y,width-20,38,8,color(0x303138)) }
        icon(item.1,70,y+9,20)
        ctx.saveGState();ctx.setAlpha(labelAlpha);text(item.0,103,y+10,14,.medium);ctx.restoreGState()
    }
    icon("gearshape",70,882,20)
    ctx.saveGState();ctx.setAlpha(labelAlpha);text("Settings",103,884,14,.medium);ctx.restoreGState()
    ctx.restoreGState()
}
func window(_ title: String, _ leftWidth: Double, _ selected: Int, _ width: Double = 1360) {
    box(40,132,width,800,16,shell,color(0x34353B))
    for (i,c) in [0xFF6058,0xFEBB2E,0x28C840].enumerated() { box(54+Double(i)*20,145,11,11,5.5,color(c)) }
    icon("sidebar.left",139,146,17);icon("chevron.left",177,145,17);icon("chevron.right",211,145,17,muted)
    let tab = max(254,58+leftWidth)
    box(tab,143,164,29,7,color(0x27282C),color(0x393B43));icon(title == "Projects" ? "folder":"house",tab+12,151,14)
    text(title,tab+37,151,12,.medium)
    icon("sidebar.right",width+4,146,17)
    nav(leftWidth,selected,clamp((leftWidth-56)/90))
}
func menu(_ x: Double, _ y: Double, _ alpha: Double, _ selected: Int = -1) {
    guard alpha > 0 else { return }
    ctx.saveGState();ctx.setAlpha(alpha)
    box(x,y,246,206,10,color(0x27282C),color(0x4B4D56))
    let labels = ["Fold all", "Unfold all", "Sort by", "View", "Hide descriptions", "Collapse sidebar"]
    for (i,s) in labels.enumerated() {
        let yy = y+10+Double(i)*31
        if i == selected { box(x+5,yy-1,236,29,5,color(0x3C3F47)) }
        text(s,x+14,yy+5,14)
        if i == 2 || i == 3 { icon("chevron.right",x+218,yy+7,13,muted,alpha) }
    }
    ctx.restoreGState()
}
func projectFrame(_ t: Double) {
    var u=t, speed="NORMAL SPEED", disclosureDuration=0.16, navDuration=0.22
    if t >= 14 && t < 18 { u=7.8+(t-14)*0.25; speed="¼ SPEED REPLAY"; }
    if t >= 18 { u=7.8+(t-18); speed="REDUCED MOTION"; disclosureDuration=0; navDuration=0 }
    let fold=step(u,5.0,disclosureDuration)-step(u,7.0,disclosureDuration)
    let collapse=step(u,8.2,navDuration)-step(u,11.0,navDuration)
    let lw=mix(212,56,collapse), x=58+lw, cw=970-lw
    let subtitle = t>=18 ? "The same state changes, without movement." : t>=14 ? "Slow replay: labels clip; icons remain; the canvas expands." : u<3 ? "Approach a secondary control: reveal in place." : u<8 ? "Right-click → Fold all. Unfold without losing context." : "Collapse to icons. Reopen at the saved width."
    heading("Workspace behavior. Current cards.",subtitle,speed+" · 60 FPS",t,22)
    ctx.saveGState();ctx.translateBy(x:180,y:0)
    window("Projects",lw,3,1000);box(x,184,cw,733,14,panel,color(0x393A42))
    text("Projects",x+24,210,30,.semibold)
    // Reuse the actual search/filter header and card pixels. Text never scales
    // during folding; only the viewport/layout bounds animate.
    slice(projects,NSRect(x:261,y:140,width:618,height:81),NSRect(x:x+24,y:262,width:618,height:81))
    let viewportY=359.0, viewportH=535.0
    ctx.saveGState();clip(x+24,viewportY,min(cw-48,618),viewportH,11)
    let rects=[NSRect(x:261,y:238,width:618,height:378),NSRect(x:261,y:628,width:618,height:333),NSRect(x:261,y:973,width:618,height:195)]
    var y=viewportY
    let scrolling=105*(step(u,12.0,0.7)-step(u,13.0,0.7))
    y-=scrolling
    for r in rects {
        let h=mix(r.height,63,fold)
        ctx.saveGState();clip(x+24,y,618,h,10)
        slice(projects,r,NSRect(x:x+24,y:y,width:618,height:r.height))
        ctx.restoreGState()
        y+=h+12
    }
    ctx.restoreGState()
    let hover=step(u,2.1,0.09)-step(u,3.0,0.10)
    if hover>0 { ctx.saveGState();ctx.setAlpha(hover);box(x+660,363,28,28,6,color(0x34363D));icon("ellipsis",x+665,368,18,ink,hover);ctx.restoreGState() }
    let ma=step(u,3.3,0.08)-step(u,5.0,0.1)
    menu(x+426,401,ma,u>4.3 ? 0:-1)
    if u<3 { pointer(mix(x+570,x+674,step(u,1.1,0.8)),mix(680,377,step(u,1.1,0.8))) }
    else if u<5.3 { pointer(x+471,425,u-5.0) }
    else if u<7.5 { pointer(x+360,339,u-7.0) }
    else if u<11.6 { pointer(146,151,u-8.2) }
    else { pointer(x+420,859) }
    ctx.restoreGState()
}
func group(_ x: Double,_ y: Double,_ w: Double,_ name: String,_ count: Int,_ open: Double,_ imageRect: NSRect?) -> Double {
    let fullHeight=imageRect == nil ? 0.0:((imageRect!.height)*0.74+20)
    let h=48+fullHeight*open
    box(x,y,w,h,10,color(0x242529),color(0x3A3B43))
    ctx.saveGState();ctx.translateBy(x:x+18,y:y+23);ctx.rotate(by:open*Double.pi/2);icon("chevron.right",-7,-7,14);ctx.restoreGState()
    text(name,x+41,y+14,16,.semibold);text("\(count)",x+41+Double(name.count)*10+11,y+16,13,.regular,muted)
    if let r=imageRect, open>0 {
        ctx.saveGState();clip(x+12,y+48,w-24,max(0,h-56),8)
        slice(planner,r,NSRect(x:x+12,y:y+48,width:r.width*0.74,height:r.height*0.74))
        if name=="Soon" {
            // Fictional issue identity for this separate group; avoid depicting
            // the same task assigned to two planning groups at once.
            box(x+26,y+61,125,22,0,color(0x292A2E))
            text("PT-31",x+27,y+65,10,.regular,muted)
            box(x+46,y+79,425,29,0,color(0x292A2E))
            text("Review task planning rules",x+47,y+86,14,.semibold)
        }
        ctx.restoreGState()
    }
    return h
}
func todayFrame(_ t: Double) {
    var u=t, d=0.2, gd=0.16, tag="NORMAL SPEED · 60 FPS"
    if t>=18 && t<22 { u=2.8+(t-18)*0.25;tag="¼ SPEED REPLAY" }
    if t>=22 { u=2.8+(t-22);d=0;gd=0;tag="REDUCED MOTION" }
    let rightFold=step(u,3.0,d)-step(u,5.5,d)
    let allFold=step(u,9.0,gd)-step(u,11.6,gd)
    let todayOpen=1-step(u,7.0,gd)+step(u,8.1,gd)-allFold
    let soonOpen=step(u,6.0,gd)-step(u,8.6,gd)
    let detail = t>=22 ? "Immediate folding; selection and controls remain available." : t>=18 ? "Slow replay: the timeline closes independently." : u<6 ? "Fold the day panel independently; reopen at its saved width." : u<12 ? "Each section folds. Fold all moves together, without a stagger." : "Drag and resize track the pointer directly; duration updates immediately."
    heading("Today, Soon, Later. Room when you need it.",detail,tag,t,26)
    window("Today",56,0)
    let x=114.0, rightW=330*(1-rightFold), cw=1274-rightW-16*(1-rightFold)
    box(x,184,cw,733,14,panel,color(0x393A42))
    text("Today",x+24,207,30,.semibold);text("Thursday, 1 October 2026",x+24,251,14,.regular,muted)
    box(x+24,294,680,36,7,color(0x27282C),color(0x3B3D44));icon("magnifyingglass",x+36,304,16,muted);text("Search issues…",x+62,305,13,.regular,muted)
    ctx.saveGState();clip(x+24,349,min(cw-48,680),545,11)
    let gh=group(x+24,349,680,"Today",2,clamp(todayOpen),NSRect(x:148,y:361,width:795,height:481))
    let sy=349+gh+12
    let sh=group(x+24,sy,680,"Soon",4,clamp(soonOpen),NSRect(x:148,y:361,width:795,height:234))
    _=group(x+24,sy+sh+12,680,"Later",7,0,nil)
    ctx.restoreGState()
    if rightW>0 {
        let rx=1400-rightW-12
        ctx.saveGState();clip(rx,184,rightW,733,14)
        box(rx,184,330,733,14,panel,color(0x393A42))
        text("Day plan",rx+18,207,21,.semibold);text("Thu, 1 October 2026",rx+18,242,13,.regular,muted)
        icon("sidebar.right",rx+286,211,18)
        for i in 0..<6 {
            let yy=301+Double(i)*100
            text(i<3 ? "\(9+i) AM":(i==3 ? "12 PM":"\(i-3) PM"),rx+14,yy-8,12,.regular,muted)
            box(rx+65,yy,252,1,0,color(0x34363D))
        }
        let drag=step(u,13.0,0.7)
        let resize=step(u,15.0,1.0)
        let by=401+50*drag, bh=50+25*resize
        let start=600+Int((30*drag/5).rounded())*5
        let minutes=30+Int((15*resize/5).rounded())*5
        func clock(_ n: Int) -> String { String(format:"%d:%02d",n/60,n%60) }
        let times="\(clock(start)) AM – \(clock(start+minutes)) AM"
        box(rx+72,by,242,bh,7,color(0x292B30),color(0x5A606B))
        box(rx+72,by,3,bh,1,color(0x4393F3));text("Refine floating timer hover",rx+83,by+10,12,.medium,ink,223)
        text(times,rx+83,by+31,11,.regular,muted,222)
        if u>=12.5 && u<16.8 {
            box(rx+179,by-55,132,44,7,color(0x292B30),color(0x51555F))
            text("\(minutes) min",rx+191,by-47,13,.medium)
            text("\(clock(start)) – \(clock(start+minutes))",rx+191,by-28,11,.regular,muted)
        }
        ctx.restoreGState()
        if u>=13 && u<16.8 { pointer(rx+210,u>=15 ? by+bh-2:by+20) }
    }
    let ma=step(u,8.8,0.08)-step(u,9.1,0.08)
    menu(x+433,384,ma,0)
    if u<6 { pointer(1371,151,u-3.0) }
    else if u<8.7 { pointer(x+41,u<7 ? sy+22:371,u-7.0) }
    else if u<12.2 { pointer(x+468,410,u-9.0) }
    else if u>=17 { pointer(1371,151,u-3.0) }
}
func timerFrame(_ t: Double) {
    var u=t, duration=0.12, tag="NORMAL SPEED · 60 FPS"
    if t>=9 && t<13 { u=1.85+(t-9)*0.25;tag="¼ SPEED REPLAY" }
    if t>=13 { u=1.85+(t-13);duration=0;tag="REDUCED MOTION" }
    let alpha=step(u,2.0,duration)-step(u,5.2,duration)+step(u,6.5,duration)
    let a=clamp(alpha)
    let title = t>=13 ? "Reduced Motion: title and actions swap immediately." : t>=9 ? "Slow replay: actions occupy exactly the title area." : u<2 ? "At rest, only title and time." : u<5.2 ? "Hover reveals actions over the title. Width and clock stay fixed." : u<6.5 ? "Leave the bar: the title returns." : "Keyboard focus reveals the same controls."
    heading("A quieter floating timer.",title,tag,t,18)
    let bx=270.0, by=400.0, scale=0.70, bw=1200*scale, bh=126*scale
    // Align both screenshots to one immutable component rectangle. Crossfade
    // only the title/action slot, never the clock or whole timer window.
    slice(timer,NSRect(x:306,y:248,width:1200,height:126),NSRect(x:bx,y:by,width:bw,height:bh))
    ctx.saveGState();clip(bx+211*scale,by+8,bw-211*scale-10,bh-16,5)
    slice(timer,NSRect(x:306,y:530,width:1200,height:126),NSRect(x:bx,y:by,width:bw,height:bh),a)
    ctx.restoreGState()
    // The supplied still includes a baked cursor over More. Re-render that
    // single native button in the film so the moving cursor remains singular.
    if a>0 {
        ctx.saveGState();ctx.setAlpha(a);clip(bx,by,bw,bh,23)
        box(bx+bw-124,by+2,122,bh-4,0,color(0x1B1C1F))
        box(bx+bw-116,by+18,78,51,12,color(0x303237),color(0x41434B))
        icon("ellipsis",bx+bw-89,by+32,24,ink,a)
        ctx.restoreGState()
    }
    if u>=6.5 && t<9 { box(bx+238*scale,by+18,70,54,9,color(0x000000,0),color(0x709CEF)) }
    if t<9 {
        if u>=5.2 && u<6.5 { pointer(1130,615) }
        else if u<6.5 { pointer(mix(1120,1045,step(u,1.2,0.7)),mix(660,446,step(u,1.2,0.7))) }
        else { pointer(1130,615) }
    } else { pointer(1045,446) }
    text("Same bar bounds",bx,by+140,15,.medium,muted)
    text("Same clock anchor",bx+330,by+140,15,.medium,muted)
    text("No reserved trailing area",bx+590,by+140,15,.medium,muted)
}
let clips:[(String,Double,(Double)->Void)] = [
    ("workspace-motion",22,projectFrame),("today-timeline-motion",26,todayFrame),("floating-timer-motion",18,timerFrame)
]
func render(_ t: Double,_ draw: (Double)->Void) -> CGContext {
    let c=CGContext(data:nil,width:W,height:H,bitsPerComponent:8,bytesPerRow:W*4,space:cs,
        bitmapInfo:CGImageAlphaInfo.premultipliedFirst.rawValue|CGBitmapInfo.byteOrder32Little.rawValue)!
    ctx=c;c.translateBy(x:0,y:Double(H));c.scaleBy(x:1,y:-1)
    NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(cgContext:c,flipped:true)
    box(0,0,Double(W),Double(H),0,color(0x111216));draw(t)
    NSGraphicsContext.restoreGraphicsState();return c
}
func png(_ c: CGContext,_ path: URL) {
    let dst=CGImageDestinationCreateWithURL(path as CFURL,"public.png" as CFString,1,nil)!
    CGImageDestinationAddImage(dst,c.makeImage()!,nil);precondition(CGImageDestinationFinalize(dst))
}
try FileManager.default.createDirectory(at:output.appendingPathComponent("stills"),withIntermediateDirectories:true)
if CommandLine.arguments.contains("--check") {
    precondition(step(1.99,2,0.12)==0 && step(2.12,2,0.12)==1)
    precondition(step(2,2,0)==1 && step(1.99,2,0)==0)
    for (name,d,draw) in clips {
        for t in [0.0,2.16,3.15,5.2,6.2,9.1,14.5,d-0.5] {
            autoreleasepool { png(render(t,draw),output.appendingPathComponent("stills/\(name)-\(String(format:"%05.2f",t)).png")) }
        }
    }
    print("Motion self-check and preview stills passed");exit(0)
}
for (name,duration,draw) in clips {
    let process=Process(),pipe=Pipe()
    process.executableURL=URL(fileURLWithPath:"/opt/homebrew/bin/ffmpeg")
    process.arguments=["-hide_banner","-loglevel","error","-y","-f","rawvideo","-pixel_format","bgra",
        "-video_size","\(W)x\(H)","-framerate","\(fps)","-i","pipe:0","-an","-c:v","libx264","-preset","fast",
        "-crf","18","-pix_fmt","yuv420p","-movflags","+faststart","-metadata","title=PokeTasks v2 — \(name)",
        output.appendingPathComponent(name+".mp4").path]
    process.standardInput=pipe;try process.run()
    for frame in 0..<Int(duration*Double(fps)) {
        try autoreleasepool {
            let cg=render(Double(frame)/Double(fps),draw)
            try pipe.fileHandleForWriting.write(contentsOf:Data(bytes:cg.data!,count:W*H*4))
        }
        if frame % 300 == 0 { print("\(name): \(frame/fps)/\(Int(duration)) sec");fflush(stdout) }
    }
    try pipe.fileHandleForWriting.close();process.waitUntilExit();precondition(process.terminationStatus==0)
    print("Completed \(name)");fflush(stdout)
}
