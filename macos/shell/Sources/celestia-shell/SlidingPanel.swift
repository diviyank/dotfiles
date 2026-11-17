import AppKit

class SlidingPanel: NSPanel {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    func configureAsChrome() {
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }

    func slide(to frame: NSRect, entering: Bool, completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = entering ? Motion.enterDuration : Motion.exitDuration
            context.timingFunction = entering ? Motion.enterCurve : Motion.exitCurve
            animator().setFrame(frame, display: true)
        } completionHandler: { completion?() }
    }
}
