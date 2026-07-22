import AppKit
import Carbon

final class HotKeyManager {
    var handler: (() -> Void)?

    private var hotKeyReference: EventHotKeyRef?
    private var eventHandlerReference: EventHandlerRef?
    private var currentConfiguration: HotKeyConfiguration?
    private var isEventHandlerInstalled = false
    private var isHotKeyPressed = false

    init() {
        installEventHandler()
    }

    deinit {
        if let hotKeyReference { UnregisterEventHotKey(hotKeyReference) }
        if let eventHandlerReference { RemoveEventHandler(eventHandlerReference) }
    }

    func register(_ configuration: HotKeyConfiguration) -> Result<Void, HotKeyRegistrationError> {
        guard configuration.isValid else { return .failure(.missingModifier) }
        guard isEventHandlerInstalled else { return .failure(.registrationUnavailable) }
        if configuration == currentConfiguration { return .success(()) }

        let previousConfiguration = currentConfiguration
        if let hotKeyReference {
            UnregisterEventHotKey(hotKeyReference)
            self.hotKeyReference = nil
        }
        currentConfiguration = nil
        isHotKeyPressed = false

        let status = registerHotKey(configuration)
        guard status == noErr else {
            if let previousConfiguration {
                _ = registerHotKey(previousConfiguration)
            }
            return .failure(.registrationFailed(status))
        }
        return .success(())
    }

    private func installEventHandler() {
        var eventTypes = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            ),
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyReleased)
            )
        ]
        let status = eventTypes.withUnsafeMutableBufferPointer { buffer in
            InstallEventHandler(
                GetApplicationEventTarget(),
                { _, event, userData in
                    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                    var identifier = EventHotKeyID()
                    let status = GetEventParameter(
                        event,
                        EventParamName(kEventParamDirectObject),
                        EventParamType(typeEventHotKeyID),
                        nil,
                        MemoryLayout<EventHotKeyID>.size,
                        nil,
                        &identifier
                    )
                    guard status == noErr,
                          identifier.signature == HotKeyIdentifier.signature,
                          identifier.id == HotKeyIdentifier.id else {
                        return OSStatus(eventNotHandledErr)
                    }

                    let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                    switch GetEventKind(event) {
                    case UInt32(kEventHotKeyPressed):
                        guard !manager.isHotKeyPressed else { return noErr }
                        manager.isHotKeyPressed = true
                        if Thread.isMainThread {
                            manager.handler?()
                        } else {
                            DispatchQueue.main.async { manager.handler?() }
                        }
                    case UInt32(kEventHotKeyReleased):
                        manager.isHotKeyPressed = false
                    default:
                        return OSStatus(eventNotHandledErr)
                    }
                    return noErr
                },
                buffer.count,
                buffer.baseAddress,
                Unmanaged.passUnretained(self).toOpaque(),
                &eventHandlerReference
            )
        }
        isEventHandlerInstalled = status == noErr && eventHandlerReference != nil
    }

    private func registerHotKey(_ configuration: HotKeyConfiguration) -> OSStatus {
        let identifier = EventHotKeyID(
            signature: HotKeyIdentifier.signature,
            id: HotKeyIdentifier.id
        )
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            configuration.keyCode,
            carbonModifiers(from: configuration.modifierFlags),
            identifier,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard status == noErr, let reference else {
            return status == noErr ? OSStatus(paramErr) : status
        }
        hotKeyReference = reference
        currentConfiguration = configuration
        return noErr
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
}

enum HotKeyRegistrationError: LocalizedError {
    case missingModifier
    case registrationUnavailable
    case registrationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .missingModifier:
            return "快捷键至少需要包含 Command、Control 或 Option。"
        case .registrationUnavailable:
            return "快捷键服务暂时不可用。"
        case .registrationFailed:
            return "这个快捷键已被系统或其他应用占用，请换一个。"
        }
    }
}

private enum HotKeyIdentifier {
    static let signature: OSType = 0x514C_5044
    static let id: UInt32 = 1
}
