import Foundation
var lifecycle=CaptureLifecycle()
let first=lifecycle.begin()!
assert(lifecycle.begin()==nil)
for missing in 0..<4 {
 let gates=(0..<4).map{$0 != missing}
 assert(!lifecycle.ready(first,applicationActive:gates[0],keyWindow:gates[1],padFocused:gates[2],onActiveSpace:gates[3]))
 assert(lifecycle.phase == .preparing)
}
assert(lifecycle.end())
let second=lifecycle.begin()!
assert(!lifecycle.owns(first))
assert(!lifecycle.ready(first,applicationActive:true,keyWindow:true,padFocused:true,onActiveSpace:true))
assert(lifecycle.ready(second,applicationActive:true,keyWindow:true,padFocused:true,onActiveSpace:true))
assert(!lifecycle.ready(second,applicationActive:true,keyWindow:true,padFocused:true,onActiveSpace:true))
assert(lifecycle.end());assert(!lifecycle.end());assert(!lifecycle.owns(second))
for code:UInt16 in [36,76]{assert(DrawingCommand.decode(keyCode:code,characters:nil,modified:false) == .submit)}
assert(DrawingCommand.decode(keyCode:53,characters:nil,modified:false) == .cancel)
assert(DrawingCommand.decode(keyCode:8,characters:"C",modified:false) == .clear)
assert(DrawingCommand.decode(keyCode:8,characters:"c",modified:true) == nil)
assert(DrawingCommand.decode(keyCode:0,characters:"a",modified:false) == nil)
print("PASS: all focus readiness gates, duplicate activation, cancelled presentation, stale session callbacks, double cleanup and command modifiers")
