import SwiftUI
import SpriteKit

struct LiquidView: View {
    @ObservedObject private var motion = MotionManager.shared
    let score: Int
    let color: Color
    let marketType: MarketType
    let scoreOffsetX: CGFloat
    
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
                sceneHolder.scene.scoreOffsetX = scoreOffsetX
                sceneHolder.scene.showScore(score)
                sceneHolder.scene.updateMarketType(marketType)
            }
            .onChange(of: motion.gravity) { oldValue, newValue in
                sceneHolder.scene.setGravity(dx: newValue.x * 6, dy: newValue.y * 6)
            }
            .onChange(of: score) { oldValue, newValue in
                let dropletCount = max(1, newValue * 4)
                sceneHolder.scene.updateDropletCount(dropletCount)
                sceneHolder.scene.scoreOffsetX = scoreOffsetX
                sceneHolder.scene.showScore(newValue)
            }
            .onChange(of: marketType) { oldValue, newValue in
                sceneHolder.scene.updateMarketType(newValue)
            }
            .onChange(of: scoreOffsetX) { oldValue, newValue in
                sceneHolder.scene.scoreOffsetX = newValue
                sceneHolder.scene.showScore(score)
            }
    }
}

class SceneHolder: ObservableObject {
    @Published var scene: LiquidScene
    init() {
        let initialDropletCount = 1
        self.scene = LiquidScene(dropletCount: initialDropletCount, marketType: .stock)
        self.scene.size = .zero // 실제 크기는 onAppear에서 지정
        self.scene.scaleMode = .resizeFill
    }
} 