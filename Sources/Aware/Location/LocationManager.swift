import CoreLocation
import Observation

/// Thin, observable wrapper around `CLLocationManager`.
///
/// CoreLocation delivers its delegate callbacks on the thread the manager was
/// created on — here, the main thread — so the `nonisolated` delegate methods
/// hop back onto the main actor with `MainActor.assumeIsolated`, which keeps the
/// whole type `@MainActor` and Swift-6-strict-concurrency clean without a
/// separate detached delegate object.
@MainActor
@Observable
final class LocationManager: NSObject {
    private let manager = CLLocationManager()

    /// The most recent fix, or `nil` until the first update arrives.
    private(set) var location: CLLocation?
    private(set) var authorization: CLAuthorizationStatus

    /// Whether we're actively streaming high-accuracy updates (live share / SOS).
    private(set) var isStreaming = false

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    /// Ask for "when in use" — the baseline the safety map and "near me" need.
    func requestWhenInUse() {
        manager.requestWhenInUseAuthorization()
    }

    /// Escalate to "always" so live sharing / SOS keep updating in the background.
    func requestAlways() {
        manager.requestAlwaysAuthorization()
    }

    /// One-shot position for centring the map.
    func requestOneShot() {
        manager.requestLocation()
    }

    /// Begin continuous updates — used while an SOS, live-share or safety-timer
    /// session is active.
    func startStreaming() {
        guard !isStreaming else { return }
        isStreaming = true
        manager.allowsBackgroundLocationUpdates =
            authorization == .authorizedAlways
        manager.startUpdatingLocation()
    }

    func stopStreaming() {
        guard isStreaming else { return }
        isStreaming = false
        manager.allowsBackgroundLocationUpdates = false
        manager.stopUpdatingLocation()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        MainActor.assumeIsolated { self.location = latest }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didChangeAuthorization status: CLAuthorizationStatus) {
        MainActor.assumeIsolated { self.authorization = status }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        // A scaffold swallows location errors; a real build would surface them.
    }
}
