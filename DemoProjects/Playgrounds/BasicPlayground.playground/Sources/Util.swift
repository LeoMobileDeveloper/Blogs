import Foundation
import UIKit

extension UIColor{
    public static func random()->UIColor{
        return UIColor(colorLiteralRed:Float.random0To1, green: Float.random0To1, blue:Float.random0To1, alpha: 1.0)
    }
}
extension Float{
    public static var random0To1:Float{
        get{
            let random = Float(arc4random() % 255)/255.0;
            return random
        }
    }
}
