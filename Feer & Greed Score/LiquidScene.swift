import SpriteKit

class LiquidScene: SKScene {
    private var particles: [SKShapeNode] = []
    private var particleCount: Int
    private let particleSize: CGFloat = 30
    private var particleColor = UIColor.systemTeal.withAlphaComponent(0.7)
    private var scoreBody: SKNode?
    private var particleTimer: Timer?
    private var topBorder: SKNode?
    private var scoreLabel: SKLabelNode?
    private var marketType: MarketType
    private var baseColor: UIColor
    var scoreOffsetX: CGFloat = 0
    
    // 그라데이션 색상 정의
    private var colors: [(UIColor, CGFloat)] {
        switch marketType {
        case .stock:
            // Stock 모드 색상
            return [
                (.systemRed, 0.0),      // Extreme Greed (위쪽)
                (.systemOrange, 0.2),   // Greed
                (.systemYellow, 0.45),  // Neutral
                (.systemGreen, 0.55),   // Fear
                (.systemBlue, 0.75)     // Extreme Fear (아래쪽)
            ]
        case .crypto:
            // Crypto 모드 색상
            return [
                (.systemMint, 0.0),     // Extreme Greed (위쪽)
                (.systemCyan, 0.2),     // Greed
                (.systemBlue, 0.45),    // Neutral
                (UIColor(red: 110/255, green: 60/255, blue: 200/255, alpha: 1), 0.55), // Fear
                (.systemPurple, 0.75)   // Extreme Fear (아래쪽)
            ]
        }
    }
    
    init(dropletCount: Int, marketType: MarketType = .stock, baseColor: UIColor = .systemTeal) {
        self.particleCount = dropletCount
        self.marketType = marketType
        self.baseColor = baseColor
        super.init(size: .zero)
        self.scaleMode = .resizeFill
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMove(to view: SKView) {
        backgroundColor = .clear
        physicsWorld.gravity = CGVector(dx: 0, dy: -12)

        // 기존 벽 노드가 있으면 제거
        self.childNode(withName: "border")?.removeFromParent()

        // 좌/우/아래만 벽 생성
        let left = SKPhysicsBody(edgeFrom: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: size.height))
        let right = SKPhysicsBody(edgeFrom: CGPoint(x: size.width, y: 0), to: CGPoint(x: size.width, y: size.height))
        let bottom = SKPhysicsBody(edgeFrom: CGPoint(x: 0, y: 0), to: CGPoint(x: size.width, y: 0))
        let border = SKNode()
        border.name = "border"
        border.position = .zero
        border.zPosition = 1000
        border.physicsBody = SKPhysicsBody(bodies: [left, right, bottom])
        border.physicsBody?.categoryBitMask = 2
        border.physicsBody?.isDynamic = false
        addChild(border)

        createParticles()
        
        // 파티클 색상 업데이트를 위한 타이머 설정
        let updateTimer = Timer.scheduledTimer(withTimeInterval: 1/30, repeats: true) { [weak self] _ in
            self?.updateParticleColors()
        }
        RunLoop.current.add(updateTimer, forMode: .common)
    }
    
    override func didChangeSize(_ oldSize: CGSize) {
        self.childNode(withName: "border")?.removeFromParent()

        let left = SKPhysicsBody(edgeFrom: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: size.height))
        let right = SKPhysicsBody(edgeFrom: CGPoint(x: size.width, y: 0), to: CGPoint(x: size.width, y: size.height))
        let bottom = SKPhysicsBody(edgeFrom: CGPoint(x: 0, y: 0), to: CGPoint(x: size.width, y: 0))
        let border = SKNode()
        border.name = "border"
        border.position = .zero
        border.zPosition = 1000
        border.physicsBody = SKPhysicsBody(bodies: [left, right, bottom])
        border.physicsBody?.categoryBitMask = 2
        border.physicsBody?.isDynamic = false
        addChild(border)
    }
    
    func setGravity(dx: CGFloat, dy: CGFloat) {
        physicsWorld.gravity = CGVector(dx: dx, dy: dy)
        // 중력이 위로 향하면 위쪽 벽 생성, 아니면 제거
        if dy > 0 {
            if topBorder == nil {
                let top = SKPhysicsBody(edgeFrom: CGPoint(x: 0, y: size.height), to: CGPoint(x: size.width, y: size.height))
                let node = SKNode()
                node.name = "topBorder"
                node.physicsBody = top
                node.physicsBody?.categoryBitMask = 2
                node.physicsBody?.isDynamic = false
                addChild(node)
                topBorder = node
            }
        } else {
            topBorder?.removeFromParent()
            topBorder = nil
        }
    }
    
    private func updateParticleColors() {
        for particle in particles {
            let normalizedY = particle.position.y / size.height // 0이 위, 1이 아래
            let color = colorForY(normalizedY)
            particle.strokeColor = color
            particle.fillColor = .clear // 내부 색상은 투명
        }
    }
    
    private func colorForY(_ y: CGFloat) -> UIColor {
        for i in 0..<colors.count-1 {
            let (color1, pos1) = colors[i]
            let (color2, pos2) = colors[i+1]
            if y >= pos1 && y <= pos2 {
                let t = (y - pos1) / (pos2 - pos1)
                var color = interpolateColor(from: color1, to: color2, t: t)
                // 아래로 갈수록 아주 미세하게 어둡게
                color = color.darker(by: y * 0.08) // 0~0.08 정도만 어둡게
                return color
            }
        }
        // 마지막 색상도 어둡게 보정
        let base = colors.last?.0 ?? .systemBlue
        return base.darker(by: y * 0.08)
    }
    
    private func createParticles() {
        let minDist = particleSize + 20
        var positions: [CGPoint] = []
        let maxTries = 1000
        var created = 0
        particleTimer?.invalidate()
        particleTimer = Timer.scheduledTimer(withTimeInterval: 0.025, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            if created < self.particleCount {
            var pos: CGPoint
            var tries = 0
            repeat {
                    let x = CGFloat.random(in: self.particleSize...(self.size.width-self.particleSize))
                    let y = self.size.height + self.particleSize
                pos = CGPoint(x: x, y: y)
                tries += 1
            } while positions.contains(where: { hypot($0.x-pos.x, $0.y-pos.y) < minDist }) && tries < maxTries
            positions.append(pos)
            
                let particle = SKShapeNode(circleOfRadius: self.particleSize/2)
                particle.fillColor = .clear
                particle.strokeColor = self.colorForY(0)
            particle.lineWidth = 30
            particle.position = pos
                particle.physicsBody = SKPhysicsBody(circleOfRadius: self.particleSize/2)
                particle.physicsBody?.restitution = 0.7
            particle.physicsBody?.friction = 0.01
                particle.physicsBody?.linearDamping = 0.05
            particle.physicsBody?.allowsRotation = false
                particle.physicsBody?.mass = 0.005
            particle.physicsBody?.categoryBitMask = 1
            particle.physicsBody?.collisionBitMask = 1 | 2
            particle.physicsBody?.contactTestBitMask = 0
                self.addChild(particle)
                self.particles.append(particle)
                created += 1
            } else {
                timer.invalidate()
            }
        }
    }
    
    // 두 색상 사이를 보간하는 함수
    private func interpolateColor(from: UIColor, to: UIColor, t: CGFloat) -> UIColor {
        var fromRed: CGFloat = 0
        var fromGreen: CGFloat = 0
        var fromBlue: CGFloat = 0
        var fromAlpha: CGFloat = 0
        from.getRed(&fromRed, green: &fromGreen, blue: &fromBlue, alpha: &fromAlpha)
        
        var toRed: CGFloat = 0
        var toGreen: CGFloat = 0
        var toBlue: CGFloat = 0
        var toAlpha: CGFloat = 0
        to.getRed(&toRed, green: &toGreen, blue: &toBlue, alpha: &toAlpha)
        
        let red = fromRed + (toRed - fromRed) * t
        let green = fromGreen + (toGreen - fromGreen) * t
        let blue = fromBlue + (toBlue - fromBlue) * t
        let alpha = fromAlpha + (toAlpha - fromAlpha) * t
        
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    func updateDropletCount(_ newCount: Int) {
        particleCount = newCount
        // 기존 타이머와 파티클 완전 정리
        particleTimer?.invalidate()
        for p in particles { p.removeFromParent() }
        particles.removeAll()
        createParticles()
    }
    
    // 터치/드래그 시 파티클이 터치 지점으로 끌려가게
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        applyBlackholeEffect(touches)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        applyBlackholeEffect(touches)
    }
    private func applyBlackholeEffect(_ touches: Set<UITouch>) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let blackholeRadius: CGFloat = 60
        for particle in particles {
            let dx = particle.position.x - location.x
            let dy = particle.position.y - location.y
            let dist = max(1, sqrt(dx*dx + dy*dy))
            if dist < blackholeRadius {
                let force: CGFloat = 2.5 // 가까이 있는 파티클만 강하게
                let fx = -dx/dist * force
                let fy = -dy/dist * force
                particle.physicsBody?.applyImpulse(CGVector(dx: fx, dy: fy))
            }
        }
    }
    
    // 점수(숫자) 영역에 파티클이 겹치지 않도록 하는 함수 (ContentView_new.swift에서 호출 필요)
    func setScoreBody(rect: CGRect) {
        // 기존 점수 바디 제거
        scoreBody?.removeFromParent()
        // 점수 바디 생성 (좌표 변환 필요)
        let node = SKNode()
        let localRect = CGRect(x: rect.origin.x, y: size.height - rect.origin.y - rect.height, width: rect.width, height: rect.height)
        node.position = CGPoint(x: localRect.midX, y: localRect.midY)
        node.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: localRect.width, height: localRect.height))
        node.physicsBody?.isDynamic = false
        node.physicsBody?.categoryBitMask = 4
        node.physicsBody?.collisionBitMask = 1 // 파티클(1)과만 충돌
        node.physicsBody?.contactTestBitMask = 0
        node.alpha = 0.01 // 완전 투명
        addChild(node)
        scoreBody = node
    }
    
    func showScore(_ score: Int) {
        // 기존 라벨 제거
        scoreLabel?.removeFromParent()
        // 기존 outline sprite/crop 제거
        self.childNode(withName: "scoreOutline")?.removeFromParent()
        self.childNode(withName: "scoreOutlineCrop")?.removeFromParent()
        
        // 라벨 기본 설정
        let fontSize = min(size.width, size.height) * 0.44
        let center = CGPoint(x: size.width/2 + scoreOffsetX, y: size.height/2)
        let text = "\(score)"
        
        // 1. 그라데이션 텍스처 생성
        func gradientTexture(size: CGSize, colors: [UIColor]) -> SKTexture {
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { ctx in
                let cgColors = colors.map { $0.cgColor } as CFArray
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let gradient = CGGradient(colorsSpace: colorSpace, colors: cgColors, locations: nil)!
                ctx.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }
            return SKTexture(image: image)
        }
        let gradColors = colors.map { $0.0 }
        let gradTex = gradientTexture(size: CGSize(width: fontSize*1.2, height: fontSize*1.2), colors: gradColors)
        
        // 2. 아웃라인용 라벨 여러 개 (offset, 더 얇게)
        let outlineOffsets: [CGPoint] = [
            CGPoint(x: -2, y: 0), CGPoint(x: 2, y: 0),
            CGPoint(x: 0, y: -2), CGPoint(x: 0, y: 2),
            CGPoint(x: -1, y: -1), CGPoint(x: 1, y: 1),
            CGPoint(x: -1, y: 1), CGPoint(x: 1, y: -1)
        ]
        let outlineNode = SKNode()
        outlineNode.name = "scoreOutline"
        for offset in outlineOffsets {
            let shadow = SKLabelNode(text: text)
            shadow.fontName = "HelveticaNeue-UltraLight"
            shadow.fontSize = fontSize
            shadow.position = CGPoint(x: center.x + offset.x, y: center.y + offset.y)
            shadow.zPosition = 9999
            shadow.horizontalAlignmentMode = .center
            shadow.verticalAlignmentMode = .center
            shadow.fontColor = .white
            shadow.alpha = 1.0
            outlineNode.addChild(shadow)
        }
        // 그라데이션 텍스처를 outlineNode에 마스킹 (SKCropNode 사용)
        let gradSprite = SKSpriteNode(texture: gradTex)
        gradSprite.size = CGSize(width: fontSize*1.2, height: fontSize*1.2)
        gradSprite.position = center
        gradSprite.zPosition = 9999
        gradSprite.alpha = 0.9
        let crop = SKCropNode()
        crop.name = "scoreOutlineCrop"
        crop.addChild(gradSprite)
        crop.maskNode = outlineNode
        crop.zPosition = 9999
        addChild(crop)
        
        // 3. 실제 숫자 라벨(검은색)
        let label = SKLabelNode(text: text)
        label.fontName = "HelveticaNeue-UltraLight"
        label.fontSize = fontSize
        label.fontColor = .black
        label.position = center
        label.zPosition = 10000
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.blendMode = .alpha
        scoreLabel = label
        addChild(label)
    }
    
    func updateMarketType(_ newType: MarketType) {
        self.marketType = newType
        // 파티클 색상 업데이트
        for particle in particles {
            let normalizedY = particle.position.y / size.height
            particle.strokeColor = colorForY(normalizedY)
        }
        // marketType 변경 후 점수 라벨도 최신 그라데이션으로 다시 그림
        if let scoreLabel = scoreLabel, let scoreText = scoreLabel.text, let score = Int(scoreText) {
            showScore(score)
        }
    }
}

// UIColor extension 추가
extension UIColor {
    func darker(by amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: max(r - amount, 0), green: max(g - amount, 0), blue: max(b - amount, 0), alpha: a)
    }
} 