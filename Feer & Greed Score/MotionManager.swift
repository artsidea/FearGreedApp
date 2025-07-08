import Foundation
import CoreMotion

struct Gravity: Equatable {
    var x: Double
    var y: Double
}

class MotionManager: ObservableObject {
    static let shared = MotionManager()
    private let motionManager = CMMotionManager()
    @Published var gravity: Gravity = Gravity(x: 0, y: -1)
    
    private init() {
        motionManager.deviceMotionUpdateInterval = 1/30
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let g = motion?.gravity else { return }
            self?.gravity = Gravity(x: g.x, y: g.y)
        }
    }
} 