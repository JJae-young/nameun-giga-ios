import BackgroundTasks
import Foundation

enum BackgroundRefreshCoordinator {
    static let identifier = "com.edward.DataView.refresh"

    @MainActor
    static func register(appModel: AppModel) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            let operation = Task { @MainActor in
                guard !Task.isCancelled else {
                    refreshTask.setTaskCompleted(success: false)
                    return
                }
                appModel.refresh()
                refreshTask.setTaskCompleted(
                    success: !Task.isCancelled && appModel.errorMessage == nil
                )
                schedule()
            }
            refreshTask.expirationHandler = {
                operation.cancel()
            }
        }
    }

    static func schedule() {
        // This measurement is a short local state refresh, which matches
        // BGAppRefreshTask. BGProcessingTask is intended for longer work while
        // the device is idle and was less likely to sample useful boundaries.
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
