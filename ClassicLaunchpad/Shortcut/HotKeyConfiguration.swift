import AppKit

struct HotKeyConfiguration: Codable, Hashable {
    let keyCode: UInt32
    let modifierRawValue: UInt

    static let defaultConfiguration = HotKeyConfiguration(
        keyCode: HotKeyDefaults.spaceKeyCode,
        modifierRawValue: NSEvent.ModifierFlags([.control, .option]).rawValue
    )

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierRawValue)
            .intersection(.deviceIndependentFlagsMask)
    }

    var isValid: Bool {
        !modifierFlags.intersection([.command, .control, .option]).isEmpty
    }

    var displayString: String {
        var value = ""
        if modifierFlags.contains(.control) { value += "⌃" }
        if modifierFlags.contains(.option) { value += "⌥" }
        if modifierFlags.contains(.shift) { value += "⇧" }
        if modifierFlags.contains(.command) { value += "⌘" }
        value += KeyCodeDisplay.string(for: keyCode)
        return value
    }
}

private enum HotKeyDefaults {
    static let spaceKeyCode: UInt32 = 49
}

private enum KeyCodeDisplay {
    private static let special: [UInt32: String] = [
        36: "↩",
        48: "⇥",
        49: "空格",
        51: "⌫",
        53: "⎋",
        123: "←",
        124: "→",
        125: "↓",
        126: "↑"
    ]

    private static let printable: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y",
        17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=",
        25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U",
        33: "[", 34: "I", 35: "P", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";",
        42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 50: "`"
    ]

    static func string(for keyCode: UInt32) -> String {
        special[keyCode] ?? printable[keyCode] ?? "键 \(keyCode)"
    }
}
