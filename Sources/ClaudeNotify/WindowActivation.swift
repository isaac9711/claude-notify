import Cocoa
import ApplicationServices

// MARK: - Private API Declarations

@_silgen_name("_SLPSSetFrontProcessWithOptions")
@discardableResult
func _SLPSSetFrontProcessWithOptions(
    _ psn: UnsafeMutablePointer<ProcessSerialNumber>,
    _ wid: CGWindowID,
    _ mode: UInt32
) -> CGError

@_silgen_name("SLPSPostEventRecordTo")
@discardableResult
func SLPSPostEventRecordTo(
    _ psn: UnsafeMutablePointer<ProcessSerialNumber>,
    _ bytes: UnsafeMutablePointer<UInt8>
) -> CGError

@_silgen_name("GetProcessForPID")
@discardableResult
func GetProcessForPID(_ pid: pid_t, _ psn: UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus

@_silgen_name("_AXUIElementGetWindow")
@discardableResult
func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: inout CGWindowID) -> AXError

// MARK: - Window Activation (handles fullscreen Space switching)

func activateWindow(windowID: CGWindowID, pid: pid_t) {
    var psn = ProcessSerialNumber()
    let psnResult = GetProcessForPID(pid, &psn)

    if psnResult == noErr {
        _SLPSSetFrontProcessWithOptions(&psn, windowID, 0x200)

        var bytes = [UInt8](repeating: 0, count: 0xf8)
        bytes[0x04] = 0xf8
        bytes[0x3a] = 0x10
        var wid = windowID
        memcpy(&bytes[0x3c], &wid, MemoryLayout<UInt32>.size)
        memset(&bytes[0x20], 0xff, 0x10)

        bytes[0x08] = 0x01
        SLPSPostEventRecordTo(&psn, &bytes)
        bytes[0x08] = 0x02
        SLPSPostEventRecordTo(&psn, &bytes)
    }
}

// MARK: - Window Queries

func getFrontWindowTitle(bundleId: String) -> String {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first else { return "" }
    let axApp = AXUIElementCreateApplication(app.processIdentifier)

    var focusedWindow: CFTypeRef?
    AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindow)

    if let window = focusedWindow {
        var titleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &titleRef)
        if let title = titleRef as? String { return title }
    }
    return ""
}

func getFrontWindowID(bundleId: String) -> (windowID: CGWindowID, pid: pid_t)? {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first else { return nil }
    let pid = app.processIdentifier

    let axApp = AXUIElementCreateApplication(pid)
    var focusedWindow: CFTypeRef?
    AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindow)

    if let window = focusedWindow {
        var windowID: CGWindowID = 0
        if _AXUIElementGetWindow(window as! AXUIElement, &windowID) == .success, windowID != 0 {
            return (windowID, pid)
        }
    }

    guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }

    for window in windowList {
        if let ownerPID = window[kCGWindowOwnerPID as String] as? Int32,
           ownerPID == pid,
           let layer = window[kCGWindowLayer as String] as? Int, layer == 0,
           let windowNumber = window[kCGWindowNumber as String] as? CGWindowID {
            return (windowNumber, pid)
        }
    }
    return nil
}
