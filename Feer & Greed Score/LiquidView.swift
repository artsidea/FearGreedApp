import SwiftUI
import SpriteKit

struct LiquidView: View {
    @ObservedObject private var motion = MotionManager.shared
    let score: Int
    let color: Color
    
    @StateObject private var sceneHolder = SceneHolder()
    let viewHeight: CGFloat = UIScreen.main.bounds.height * 0.6
    
    var body: some View {
        SpriteView(scene: sceneHolder.scene)
            .ignoresSafeArea()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                let screenSize = UIScreen.main.bounds.size
                if sceneHolder.scene.size != screenSize {
                    sceneHolder.scene.size = screenSize
                    sceneHolder.scene.scaleMode = .resizeFill
                }
                let dropletCount = max(1, score * 4)
                sceneHolder.scene.updateDropletCount(dropletCount)
            }
            .onChange(of: motion.gravity) { _ in
                sceneHolder.scene.setGravity(dx: motion.gravity.x * 6, dy: motion.gravity.y * 6)
            }
            .onChange(of: score) { newScore in
                let dropletCount = max(1, newScore * 4)
                sceneHolder.scene.updateDropletCount(dropletCount)
            }
    }
}

class SceneHolder: ObservableObject {
    @Published var scene: LiquidScene
    init() {
        let initialDropletCount = 1
        self.scene = LiquidScene(dropletCount: initialDropletCount)
        self.scene.size = .zero // 실제 크기는 onAppear에서 지정
        self.scene.scaleMode = .resizeFill
    }
} 