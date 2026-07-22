import AppKit

final class ApplicationLauncher {
    func launch(
        _ application: InstalledApplication,
        completion: @escaping (Result<NSRunningApplication, Error>) -> Void
    ) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = true
        configuration.promptsUserIfNeeded = true

        NSWorkspace.shared.openApplication(
            at: application.url,
            configuration: configuration
        ) { runningApplication, error in
            DispatchQueue.main.async {
                if let runningApplication {
                    completion(.success(runningApplication))
                } else {
                    completion(.failure(error ?? ApplicationLaunchError.unknownFailure))
                }
            }
        }
    }

    func moveToTrash(
        _ application: InstalledApplication,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard application.canMoveToTrash else {
            completion(.failure(ApplicationLaunchError.removalNotAllowed))
            return
        }

        NSWorkspace.shared.recycle([application.url]) { _, error in
            DispatchQueue.main.async {
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
}

enum ApplicationLaunchError: LocalizedError {
    case unknownFailure
    case removalNotAllowed

    var errorDescription: String? {
        switch self {
        case .unknownFailure:
            return "无法启动这个应用。"
        case .removalNotAllowed:
            return "这个应用不能从启动台移到废纸篓。"
        }
    }
}
