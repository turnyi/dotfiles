// Hides the mouse cursor after it sits still, like Hyprland's
// `cursor { inactive_timeout = 3 }`. macOS has no such setting, and a
// background app normally cannot hide the cursor; the private
// "SetsCursorInBackground" connection property lifts that restriction
// (the same trick Cursorcerer uses).
import AppKit

@_silgen_name("_CGSDefaultConnection")
func _CGSDefaultConnection() -> Int32

@_silgen_name("CGSSetConnectionProperty")
func CGSSetConnectionProperty(_ cid: Int32, _ target: Int32, _ key: CFString, _ value: CFTypeRef) -> Int32

let INACTIVE_TIMEOUT: Double = Double(CommandLine.arguments.dropFirst().first ?? "") ?? 3
let POLL_INTERVAL: TimeInterval = 0.1

// Anything that means "the mouse is in use".
let MOUSE_EVENTS: [CGEventType] = [
  .mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown,
  .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .scrollWheel,
]

func secondsSinceMouseUse() -> Double {
  MOUSE_EVENTS
    .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
    .min() ?? 0
}

let cid = _CGSDefaultConnection()
_ = CGSSetConnectionProperty(cid, cid, "SetsCursorInBackground" as CFString, kCFBooleanTrue)

var hidden = false

func setHidden(_ hide: Bool) {
  guard hide != hidden else { return }
  // Hide/show calls are reference counted, so only ever toggle once.
  if hide {
    CGDisplayHideCursor(CGMainDisplayID())
  } else {
    CGDisplayShowCursor(CGMainDisplayID())
  }
  hidden = hide
}

// Never leave the cursor invisible when launchd stops us.
for sig in [SIGTERM, SIGINT, SIGHUP] {
  signal(sig) { _ in
    CGDisplayShowCursor(CGMainDisplayID())
    exit(0)
  }
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

Timer.scheduledTimer(withTimeInterval: POLL_INTERVAL, repeats: true) { _ in
  setHidden(secondsSinceMouseUse() >= INACTIVE_TIMEOUT)
}

app.run()
