import UIKit
import XCPlayground

open class NewtonsCradle: UIView  {
    
    fileprivate let colors: [UIColor]
    fileprivate var balls: [UIView] = []
    
    fileprivate var animator: UIDynamicAnimator?
    fileprivate var ballsToAttachmentBehaviors: [UIView:UIAttachmentBehavior] = [:]
    fileprivate var snapBehavior: UISnapBehavior?
    
    open let collisionBehavior: UICollisionBehavior
    open let gravityBehavior: UIGravityBehavior
    open let itemBehavior: UIDynamicItemBehavior
    
    public init(colors: [UIColor]) {
        self.colors = colors
        collisionBehavior = UICollisionBehavior(items: [])
        gravityBehavior = UIGravityBehavior(items: [])
        itemBehavior = UIDynamicItemBehavior(items: [])
    
        super.init(frame: CGRect(x: 0, y: 0, width: 480, height: 320))
        backgroundColor = UIColor.white
        
        animator = UIDynamicAnimator(referenceView: self)
        animator?.addBehavior(collisionBehavior)
        animator?.addBehavior(gravityBehavior)
        animator?.addBehavior(itemBehavior)
        
        createBallViews()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        for ball in balls {
            ball.removeObserver(self, forKeyPath: "center")
        }
    }
    
    // MARK: Ball Views 
    
    func createBallViews() {
        for color in colors {
            let ball = UIView(frame: CGRect.zero)
            
            // Observe the center point of the ball view to draw the attachment behavior.
            ball.addObserver(self, forKeyPath: "center", options: NSKeyValueObservingOptions.init(rawValue: 0), context: nil)
            
            // Make the ball view round and set the background
            ball.backgroundColor = color
            
            // Add the balls as a subview before we add it to any UIDynamicBehaviors.
            addSubview(ball)
            balls.append(ball)
            
            // Layout the balls based on the ballSize and ballPadding.
            layoutBalls()
        }
    }
    
    // MARK: Properties
    
    open var attachmentBehaviors:[UIAttachmentBehavior] {
        get {
            var attachmentBehaviors: [UIAttachmentBehavior] = []
            for ball in balls {
                guard let attachmentBehavior = ballsToAttachmentBehaviors[ball] else { fatalError("Can't find attachment behavior for \(ball)") }
                attachmentBehaviors.append(attachmentBehavior)
            }
            return attachmentBehaviors
        }
    }
    
    open var useSquaresInsteadOfBalls:Bool = false {
        didSet {
            for ball in balls {
                if useSquaresInsteadOfBalls {
                    ball.layer.cornerRadius = 0
                }
                else {
                    ball.layer.cornerRadius = ball.bounds.width / 2.0
                }
            }
        }
    }
    
    open var ballSize: CGSize = CGSize(width: 50, height: 50) {
        didSet {
            layoutBalls()
        }
    }
    
    open var ballPadding: Double = 0.0 {
        didSet {
            layoutBalls()
        }
    }
    
    // MARK: Ball Layout
    
    fileprivate func layoutBalls() {
        let requiredWidth = CGFloat(balls.count) * (ballSize.width + CGFloat(ballPadding))
        for (index, ball) in balls.enumerated() {
            // Remove any attachment behavior that already exists.
            if let attachmentBehavior = ballsToAttachmentBehaviors[ball] {
                animator?.removeBehavior(attachmentBehavior)
            }
            
            // Remove the ball from the appropriate behaviors before update its frame.
            collisionBehavior.removeItem(ball)
            gravityBehavior.removeItem(ball)
            itemBehavior.removeItem(ball)
            
            // Determine the horizontal position of the ball based on the number of balls.
            let ballXOrigin = ((bounds.width - requiredWidth) / 2.0) + (CGFloat(index) * (ballSize.width + CGFloat(ballPadding)))
            ball.frame = CGRect(x: ballXOrigin, y: bounds.midY, width: ballSize.width, height: ballSize.height)
            
            // Create the attachment behavior.
            let attachmentBehavior = UIAttachmentBehavior(item: ball, attachedToAnchor: CGPoint(x: ball.frame.midX, y: bounds.midY - 50))
            ballsToAttachmentBehaviors[ball] = attachmentBehavior
            animator?.addBehavior(attachmentBehavior)
            
            // Add the collision, gravity and item behaviors.
            collisionBehavior.addItem(ball)
            gravityBehavior.addItem(ball)
            itemBehavior.addItem(ball)
        }
    }
    
    // MARK: Touch Handling
    
    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let touchLocation = touch.location(in: superview)
            for ball in balls {
                if (ball.frame.contains(touchLocation)) {
                    snapBehavior = UISnapBehavior(item: ball, snapTo: touchLocation)
                    animator?.addBehavior(snapBehavior!)
                }
            }
        }
    }
    
    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let touchLocation = touch.location(in: superview)
            if let snapBehavior = snapBehavior {
                snapBehavior.snapPoint = touchLocation
            }
        }
    }
    
    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let snapBehavior = snapBehavior {
            animator?.removeBehavior(snapBehavior)
        }
        snapBehavior = nil
    }
    
    // MARK: KVO
    
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if (keyPath == "center") {
            setNeedsDisplay()
        }
    }
    
    // MARK: Drawing
    
    open override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()
        
        for ball in balls {
            guard let attachmentBehavior = ballsToAttachmentBehaviors[ball] else { fatalError("Can't find attachment behavior for \(ball)") }
            let anchorPoint = attachmentBehavior.anchorPoint
            
            context?.move(to: CGPoint(x: anchorPoint.x, y: anchorPoint.y))
            context?.addLine(to: CGPoint(x: ball.center.x, y: ball.center.y))
            context?.setStrokeColor(UIColor.darkGray.cgColor)
            context?.setLineWidth(4.0)
            context?.strokePath()
            
            let attachmentDotWidth:CGFloat = 10.0
            let attachmentDotOrigin = CGPoint(x: anchorPoint.x - (attachmentDotWidth / 2), y: anchorPoint.y - (attachmentDotWidth / 2))
            let attachmentDotRect = CGRect(x: attachmentDotOrigin.x, y: attachmentDotOrigin.y, width: attachmentDotWidth, height: attachmentDotWidth)
            
            context?.setFillColor(UIColor.darkGray.cgColor)
            context?.fillEllipse(in: attachmentDotRect)
        }
        
        context?.restoreGState()
    }
    
}
