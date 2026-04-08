import Cocoa

enum DiffLineType {
    case unchanged, added, removed
}

struct DiffLine {
    let text: String
    let type: DiffLineType
}

enum DiffPreview {

    /// Compute simple line-based diff between two strings
    static func computeDiff(old: String, new: String) -> [DiffLine] {
        let oldLines = old.components(separatedBy: "\n")
        let newLines = new.components(separatedBy: "\n")

        // Simple LCS-based diff
        let oldCount = oldLines.count
        let newCount = newLines.count

        // Build LCS table
        var dp = Array(repeating: Array(repeating: 0, count: newCount + 1), count: oldCount + 1)
        for i in 1...oldCount {
            for j in 1...newCount {
                if oldLines[i - 1] == newLines[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }

        // Backtrack to produce diff
        var result: [DiffLine] = []
        var i = oldCount, j = newCount
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && oldLines[i - 1] == newLines[j - 1] {
                result.append(DiffLine(text: "  " + oldLines[i - 1], type: .unchanged))
                i -= 1; j -= 1
            } else if j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j]) {
                result.append(DiffLine(text: "+ " + newLines[j - 1], type: .added))
                j -= 1
            } else if i > 0 {
                result.append(DiffLine(text: "- " + oldLines[i - 1], type: .removed))
                i -= 1
            }
        }
        result.reverse()
        return result
    }

    /// Build NSAttributedString with colored backgrounds
    static func attributedDiff(_ lines: [DiffLine]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)

        let addedBg = NSColor(red: 0.85, green: 1.0, blue: 0.85, alpha: 1.0)
        let removedBg = NSColor(red: 1.0, green: 0.85, blue: 0.85, alpha: 1.0)
        let addedDarkBg = NSColor(red: 0.15, green: 0.30, blue: 0.15, alpha: 1.0)
        let removedDarkBg = NSColor(red: 0.35, green: 0.15, blue: 0.15, alpha: 1.0)

        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        for (index, line) in lines.enumerated() {
            var attrs: [NSAttributedString.Key: Any] = [.font: font]

            switch line.type {
            case .added:
                attrs[.backgroundColor] = isDark ? addedDarkBg : addedBg
                attrs[.foregroundColor] = isDark ? NSColor(red: 0.6, green: 1.0, blue: 0.6, alpha: 1.0) : NSColor(red: 0.0, green: 0.4, blue: 0.0, alpha: 1.0)
            case .removed:
                attrs[.backgroundColor] = isDark ? removedDarkBg : removedBg
                attrs[.foregroundColor] = isDark ? NSColor(red: 1.0, green: 0.6, blue: 0.6, alpha: 1.0) : NSColor(red: 0.6, green: 0.0, blue: 0.0, alpha: 1.0)
            case .unchanged:
                attrs[.foregroundColor] = NSColor.textColor
            }

            let text = line.text + (index < lines.count - 1 ? "\n" : "")
            result.append(NSAttributedString(string: text, attributes: attrs))
        }
        return result
    }

    /// Show diff preview dialog, returns true if user confirms
    static func showConfirmation(title: String, oldJSON: String, newJSON: String) -> Bool {
        let lines = computeDiff(old: oldJSON, new: newJSON)
        let attributed = attributedDiff(lines)

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 560, height: 320))
        textView.isEditable = false
        textView.isSelectable = true
        textView.textStorage?.setAttributedString(attributed)
        textView.textContainer?.widthTracksTextView = true

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 560, height: 320))
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = L10n.get("reviewChanges")
        alert.alertStyle = .informational
        alert.accessoryView = scrollView
        alert.addButton(withTitle: L10n.get("apply"))
        alert.addButton(withTitle: L10n.get("cancel"))

        // Force layout so scroll view displays properly
        alert.layout()

        return alert.runModal() == .alertFirstButtonReturn
    }
}
