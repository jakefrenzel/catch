import CoreLocation
import Foundation

/// "While using" location access and one-off fixes, for Places.
/// Place reminders themselves are delivered by iOS (location notification
/// triggers), so Catch never tracks the user in the background.
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var authorizationWaiters: [CheckedContinuation<Void, Never>] = []
    private var locationWaiters: [CheckedContinuation<CLLocation?, Never>] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var isAllowed: Bool {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return true
        default: return false
        }
    }

    /// Precise Location is off, so saved places can be well off target.
    var isApproximate: Bool {
        isAllowed && manager.accuracyAuthorization == .reducedAccuracy
    }

    var isDenied: Bool {
        switch manager.authorizationStatus {
        case .denied, .restricted: return true
        default: return false
        }
    }

    /// Asks once if iOS hasn't asked yet. Returns whether access is allowed.
    func requestAccess() async -> Bool {
        if manager.authorizationStatus == .notDetermined {
            await withCheckedContinuation { continuation in
                authorizationWaiters.append(continuation)
                manager.requestWhenInUseAuthorization()
                // If iOS never answers, stop waiting after a minute.
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(60))
                    guard let self else { return }
                    let waiters = self.authorizationWaiters
                    self.authorizationWaiters = []
                    waiters.forEach { $0.resume() }
                }
            }
        }
        return isAllowed
    }

    /// Where the phone is now, or nil without access or a fix.
    func currentLocation() async -> CLLocation? {
        guard await requestAccess() else { return nil }
        return await withCheckedContinuation { continuation in
            locationWaiters.append(continuation)
            manager.requestLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard manager.authorizationStatus != .notDetermined else { return }
            let waiters = authorizationWaiters
            authorizationWaiters = []
            waiters.forEach { $0.resume() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor in finishLocation(location) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in finishLocation(nil) }
    }

    private func finishLocation(_ location: CLLocation?) {
        let waiters = locationWaiters
        locationWaiters = []
        waiters.forEach { $0.resume(returning: location) }
    }
}
