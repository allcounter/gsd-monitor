import Foundation
import UserNotifications

@MainActor
@Observable
final class NotificationService {
    private let projectService: ProjectService
    private var previousPhaseStates: [String: PhaseStatus] = [:]
    private var monitoringTask: _Concurrency.Task<Void, Never>?

    var notificationsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "notificationsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "notificationsEnabled") }
    }

    init(projectService: ProjectService) {
        self.projectService = projectService
        UserDefaults.standard.register(defaults: ["notificationsEnabled": true])
    }

    func requestPermissionIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .authorized, .provisional:
            return true
        default:
            return false
        }
    }

    func startMonitoring() {
        monitoringTask?.cancel()
        snapshotCurrentStates()

        monitoringTask = _Concurrency.Task { [weak self] in
            guard let self else { return }
            while !_Concurrency.Task.isCancelled {
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self.projectService.projects
                    } onChange: {
                        continuation.resume()
                    }
                }
                // Small delay to let the state settle
                try? await _Concurrency.Task.sleep(for: .milliseconds(500))
                guard !_Concurrency.Task.isCancelled else { return }
                checkForChanges()
            }
        }
    }

    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }


    private func snapshotCurrentStates() {
        previousPhaseStates = [:]
        for project in projectService.projects {
            guard let phases = project.roadmap?.phases else { continue }
            for phase in phases {
                let key = "\(project.path.path)-\(phase.number)"
                previousPhaseStates[key] = phase.status
            }
        }
    }

    private func checkForChanges() {
        guard notificationsEnabled else {
            snapshotCurrentStates()
            return
        }

        for project in projectService.projects {
            guard let phases = project.roadmap?.phases else { continue }
            for phase in phases {
                let key = "\(project.path.path)-\(phase.number)"
                if let previous = previousPhaseStates[key], previous != phase.status {
                    scheduleNotification(
                        projectName: project.name,
                        phaseName: phase.name,
                        phaseNumber: phase.number,
                        newStatus: phase.status
                    )
                }
            }
        }
        snapshotCurrentStates()
    }

    private func scheduleNotification(projectName: String, phaseName: String, phaseNumber: Int, newStatus: PhaseStatus) {
        _Concurrency.Task {
            let authorized = await requestPermissionIfNeeded()
            guard authorized else { return }

            let content = UNMutableNotificationContent()
            let statusText: String
            switch newStatus {
            case .done: statusText = "Complete"
            case .inProgress: statusText = "In Progress"
            case .notStarted: statusText = "Not Started"
            case .cancelled: statusText = "Cancelled"
            case .deferred: statusText = "Deferred"
            }

            content.title = "Phase \(phaseNumber) - \(statusText)"
            content.body = "\(projectName): \(phaseName)"
            content.sound = .default
            content.interruptionLevel = .timeSensitive

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )

            try? await UNUserNotificationCenter.current().add(request)
        }
    }
}
