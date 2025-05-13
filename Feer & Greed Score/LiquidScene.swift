import SpriteKit

class LiquidScene: SKScene {
    private var particles: [SKShapeNode] = []
    private var particleCount: Int
    private let particleSize: CGFloat = 30
    private let particleColor = UIColor.systemTeal.withAlphaComponent(0.7)
    private var scoreBody: SKNode?
    
    // 그라데이션 색상 정의
    private let colors: [(UIColor, CGFloat)] = [
        (.systemRed, 0.0),      // Extreme Greed (위쪽)
        (.systemOrange, 0.2),   // Greed
        (.systemYellow, 0.45),  // Neutral
        (.systemGreen, 0.55),   // Fear
        (.systemBlue, 0.75)     // Extreme Fear (아래쪽)
    ]
    
    init(dropletCount: Int) {
        self.particleCount = dropletCount
        super.init(size: .zero)
        self.scaleMode = .resizeFill
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMove(to view: SKView) {
        backgroundColor = .clear
        physicsWorld.gravity = CGVector(dx: 0, dy: -2)
        physicsBody = SKPhysicsBody(edgeLoopFrom: frame)
        physicsBody?.categoryBitMask = 2 // 벽은 2번
        createParticles()
        
        // 파티클 색상 업데이트를 위한 타이머 설정
        let updateTimer = Timer.scheduledTimer(withTimeInterval: 1/30, repeats: true) { [weak self] _ in
            self?.updateParticleColors()
        }
        RunLoop.current.add(updateTimer, forMode: .common)
    }
    
    func setGravity(dx: CGFloat, dy: CGFloat) {
        physicsWorld.gravity = CGVector(dx: dx, dy: dy)
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
                return interpolateColor(from: color1, to: color2, t: t)
            }
        }
        return colors.last?.0 ?? .systemBlue
    }
    
    private func createParticles() {
        for p in particles { p.removeFromParent() }
        particles.removeAll()
        let minDist = particleSize + 20 // 20px padding
        var positions: [CGPoint] = []
        let maxTries = 1000
        
        for _ in 0..<particleCount {
            var pos: CGPoint
            var tries = 0
            repeat {
                let x = CGFloat.random(in: particleSize...(size.width-particleSize))
                let y = CGFloat.random(in: particleSize...(size.height-particleSize))
                pos = CGPoint(x: x, y: y)
                tries += 1
            } while positions.contains(where: { hypot($0.x-pos.x, $0.y-pos.y) < minDist }) && tries < maxTries
            positions.append(pos)
            
            let particle = SKShapeNode(circleOfRadius: particleSize/2)
            particle.fillColor = .clear // 내부 색상은 투명
            particle.strokeColor = colorForY(pos.y / size.height)
            particle.lineWidth = 30
            particle.position = pos
            particle.physicsBody = SKPhysicsBody(circleOfRadius: particleSize/2)
            particle.physicsBody?.restitution = 0.9
            particle.physicsBody?.friction = 0.01
            particle.physicsBody?.linearDamping = 0.1
            particle.physicsBody?.allowsRotation = false
            particle.physicsBody?.mass = 0.01
            particle.physicsBody?.categoryBitMask = 1
            particle.physicsBody?.collisionBitMask = 1 | 2
            particle.physicsBody?.contactTestBitMask = 0
            addChild(particle)
            particles.append(particle)
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
} 