import Foundation
import Testing
@testable import ShellCore

private let displaysJSON = #"""
[{"id":2,"uuid":"7B05FE65","index":1,"label":"","spaces":[1,2,3],"has-focus":true},
 {"id":1,"uuid":"37D8832A","index":2,"label":"","spaces":[4,5,6,7,8,9,10,11,12],"has-focus":false}]
"""#

private func spacesJSON(fullscreenSix: Bool = false) -> String {
    #"""
    [{"id":8,"index":1,"label":"five","display":1,"windows":[],"is-visible":false,"has-focus":false,"is-native-fullscreen":false},
     {"id":1,"index":2,"label":"one","display":1,"windows":[19529],"is-visible":true,"has-focus":true,"is-native-fullscreen":false},
     {"id":6,"index":3,"label":"three","display":1,"windows":[44412],"is-visible":false,"has-focus":false,"is-native-fullscreen":false},
     {"id":426,"index":4,"label":"","display":2,"windows":[],"is-visible":false,"has-focus":false,"is-native-fullscreen":false},
     {"id":12,"index":5,"label":"nine","display":2,"windows":[],"is-visible":false,"has-focus":false,"is-native-fullscreen":false},
     {"id":13,"index":6,"label":"ten","display":2,"windows":[46980],"is-visible":false,"has-focus":false,"is-native-fullscreen":false},
     {"id":9,"index":7,"label":"six","display":2,"windows":[26405],"is-visible":true,"has-focus":false,"is-native-fullscreen":\#(fullscreenSix)},
     {"id":5,"index":8,"label":"two","display":2,"windows":[45482,1],"is-visible":false,"has-focus":false,"is-native-fullscreen":false},
     {"id":10,"index":9,"label":"seven","display":2,"windows":[2],"is-visible":false,"has-focus":false,"is-native-fullscreen":false},
     {"id":14,"index":10,"label":"eleven","display":2,"windows":[14850],"is-visible":false,"has-focus":false,"is-native-fullscreen":false},
     {"id":7,"index":11,"label":"four","display":2,"windows":[],"is-visible":false,"has-focus":false,"is-native-fullscreen":false},
     {"id":15,"index":12,"label":"eight","display":2,"windows":[3],"is-visible":false,"has-focus":false,"is-native-fullscreen":false}]
    """#
}

private let windowsJSON = #"""
[{"id":19529,"pid":76105,"app":"kitty","title":"tmux","space":2,"display":1,"has-focus":true,"is-minimized":false,"is-hidden":false,"scratchpad":""},
 {"id":26405,"pid":79214,"app":"Discord","title":"Fentech - Discord","space":7,"display":2,"has-focus":false,"is-minimized":false,"is-hidden":false,"scratchpad":""},
 {"id":14850,"pid":8015,"app":"kitty","title":"Scratchpad","space":10,"display":2,"has-focus":false,"is-minimized":false,"is-hidden":false,"scratchpad":"kitty"},
 {"id":44412,"pid":553,"app":"Finder","title":"devis","space":3,"display":1,"has-focus":false,"is-minimized":false,"is-hidden":false,"scratchpad":""},
 {"id":45482,"pid":99468,"app":"Zen","title":"Jira","space":8,"display":2,"has-focus":false,"is-minimized":false,"is-hidden":false,"scratchpad":""},
 {"id":1,"pid":99468,"app":"Zen","title":"Mail","space":8,"display":2,"has-focus":false,"is-minimized":false,"is-hidden":false,"scratchpad":""},
 {"id":2,"pid":300,"app":"Mail","title":"Inbox","space":9,"display":2,"has-focus":false,"is-minimized":true,"is-hidden":false,"scratchpad":""},
 {"id":3,"pid":301,"app":"Calendar","title":"Week","space":12,"display":2,"has-focus":false,"is-minimized":false,"is-hidden":true,"scratchpad":""},
 {"id":46980,"pid":10796,"app":"Microsoft Teams","title":"Calendar","space":6,"display":2,"has-focus":false,"is-minimized":false,"is-hidden":false,"scratchpad":""}]
"""#

private func decode(spaces: String = spacesJSON(), windows: String = windowsJSON, displays: String = displaysJSON) -> [BarDisplay]? {
    decodeBarDisplays(displays: Data(displays.utf8), spaces: Data(spaces.utf8), windows: Data(windows.utf8))
}

@Test func labelsMapToNumbers() {
    #expect(spaceNumber(label: "one") == 1)
    #expect(spaceNumber(label: "ten") == 10)
    #expect(spaceNumber(label: "eleven") == nil)
    #expect(spaceNumber(label: "") == nil)
}

@Test func spacesGroupedPerDisplaySorted() throws {
    let displays = try #require(decode())
    #expect(displays.map(\.uuid) == ["7B05FE65", "37D8832A"])
    #expect(displays[0].spaces.map(\.number) == [1, 3, 5])
    #expect(displays[1].spaces.map(\.number) == [2, 4, 6, 7, 8, 9, 10])
    #expect(displays[0].spaces.map(\.label) == ["one", "three", "five"])
    #expect(displays[0].spaces.first?.isVisible == true)
}

@Test func windowsAttachedToTheirSpace() throws {
    let displays = try #require(decode())
    let byLabel = Dictionary(uniqueKeysWithValues: displays.flatMap(\.spaces).map { ($0.label, $0) })
    #expect(byLabel["one"]?.windows.map(\.app) == ["kitty"])
    #expect(byLabel["two"]?.windows.map(\.id) == [45482, 1])
    #expect(byLabel["seven"]?.windows.isEmpty == true)
    #expect(byLabel["eight"]?.windows.isEmpty == true)
    #expect(byLabel["one"]?.windows.first == BarWindow(id: 19529, pid: 76105, app: "kitty", title: "tmux", hasFocus: true))
}

@Test func fullscreenFlag() throws {
    let displays = try #require(decode(spaces: spacesJSON(fullscreenSix: true)))
    #expect(displays[0].isFullscreen == false)
    #expect(displays[1].isFullscreen == true)
    #expect(try #require(decode())[1].isFullscreen == false)
}

@Test(arguments: ["", "[{"])
func garbageIsNil(_ junk: String) {
    #expect(decode(spaces: junk) == nil)
    #expect(decode(windows: junk) == nil)
    #expect(decode(displays: junk) == nil)
}

@Test func focusedWindowFound() throws {
    let displays = try #require(decode())
    #expect(focusedWindow(displays)?.title == "tmux")
    #expect(focusedWindow([]) == nil)
}
