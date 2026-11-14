// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Maxim Shevchenko-Tymchuk.
import AppKit
import WebKit
final class Renderer:NSObject,WKNavigationDelegate {
 let web=WKWebView(frame:NSRect(x:0,y:0,width:1024,height:1024))
 let destination:URL
 init(source:URL,destination:URL)throws {
  self.destination=destination;super.init()
  web.setValue(false,forKey:"drawsBackground");web.navigationDelegate=self
  let svg=try String(contentsOf:source)
  web.loadHTMLString("<html><style>html,body{margin:0;width:1024px;height:1024px;background:transparent}svg{display:block;width:1024px;height:1024px}</style>\(svg)</html>",baseURL:source.deletingLastPathComponent())
 }
 func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!){
  let configuration=WKSnapshotConfiguration();configuration.rect=NSRect(x:0,y:0,width:1024,height:1024);configuration.snapshotWidth=1024
  web.takeSnapshot(with:configuration){image,error in
   guard let tiff=image?.tiffRepresentation,let bitmap=NSBitmapImageRep(data:tiff),let png=bitmap.representation(using:.png,properties:[:]) else{fputs("Icon export failed\n",stderr);exit(1)}
   do{try png.write(to:self.destination);exit(0)}catch{fputs("Icon write failed\n",stderr);exit(1)}
  }
 }
}
let app=NSApplication.shared;app.setActivationPolicy(.prohibited)
let renderer=try Renderer(source:URL(fileURLWithPath:CommandLine.arguments[1]),destination:URL(fileURLWithPath:CommandLine.arguments[2]))
DispatchQueue.main.asyncAfter(deadline:.now()+30){fputs("Icon export timed out\n",stderr);exit(1)}
app.run()
