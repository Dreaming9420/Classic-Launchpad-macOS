import Foundation

final class EditModeController {
    private var longPressWorkItem: DispatchWorkItem?
    private var persistentEditing = false
    private var optionKeyPressed = false
    private var didRecognizeLongPress = false

    var isEditing: Bool {
        persistentEditing || optionKeyPressed
    }

    func beginPress() {
        cancelLongPress()
        didRecognizeLongPress = false
    }

    func scheduleLongPress(action: @escaping () -> Void) {
        cancelLongPress()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            longPressWorkItem = nil
            didRecognizeLongPress = true
            action()
        }
        longPressWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + EditTiming.longPressDuration,
            execute: workItem
        )
    }

    func cancelLongPress() {
        longPressWorkItem?.cancel()
        longPressWorkItem = nil
    }

    func endPress() -> Bool {
        cancelLongPress()
        let recognized = didRecognizeLongPress
        didRecognizeLongPress = false
        return recognized
    }

    func enter() {
        cancelLongPress()
        persistentEditing = true
    }

    func setOptionKeyPressed(_ pressed: Bool) {
        optionKeyPressed = pressed
    }

    func exit() {
        cancelLongPress()
        persistentEditing = false
        optionKeyPressed = false
        didRecognizeLongPress = false
    }
}

private enum EditTiming {
    static let longPressDuration: TimeInterval = 0.8
}
