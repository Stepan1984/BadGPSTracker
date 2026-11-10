import CoreMotion
import Foundation

/// Core Motion pedometer + attitude hooks for DR / step odometry.
@MainActor
final class MotionSensor: ObservableObject {
    @Published private(set) var lastPedometerSample: SensorSample?
    @Published private(set) var isRunning = false

    var onSample: ((SensorSample) -> Void)?

    private let pedometer = CMPedometer()
    private let motionManager = CMMotionManager()
    private var startDate: Date?

    func start() {
        guard !isRunning else { return }
        startDate = Date()
        isRunning = true

        if CMPedometer.isStepCountingAvailable() {
            pedometer.startUpdates(from: startDate ?? Date()) { [weak self] data, _ in
                guard let data else { return }
                let sample = SensorSample(
                    kind: .pedometer,
                    timestamp: data.endDate,
                    stepCount: data.numberOfSteps.intValue,
                    distanceFromPedometer: data.distance?.doubleValue
                )
                Task { @MainActor in
                    self?.lastPedometerSample = sample
                    self?.onSample?(sample)
                }
            }
        }

        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.2
            motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: .main) { [weak self] motion, _ in
                guard let motion else { return }
                let heading = motion.attitude.yaw * 180 / .pi
                let sample = SensorSample(
                    kind: .motion,
                    timestamp: Date(),
                    headingDegrees: heading
                )
                self?.onSample?(sample)
            }
        }
    }

    func stop() {
        pedometer.stopUpdates()
        motionManager.stopDeviceMotionUpdates()
        isRunning = false
        startDate = nil
    }
}
