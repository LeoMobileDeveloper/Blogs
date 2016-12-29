import UIKit
import XCPlayground
import PlaygroundSupport
/*:
## Newton's Cradle and UIKit Dynamics
This playground uses **UIKit Dynamics** to create a [Newton's Cradle](https://en.wikipedia.org/wiki/Newton%27s_cradle). Commonly seen on desks around the world, Newton's Cradle is a device that illustrates conservation of momentum and energy.
 
Let's create an instance of our UIKit Dynamics based Newton's Cradle. Try adding more colors to the array to increase the number of balls in the device.
*/
let newtonsCradle = NewtonsCradle(colors: [#colorLiteral(red: 0.8779790997505188, green: 0.3812967836856842, blue: 0.5770481824874878, alpha: 1), #colorLiteral(red: 0.2202886641025543, green: 0.7022308707237244, blue: 0.9593387842178345, alpha: 1), #colorLiteral(red: 0.9166661500930786, green: 0.4121252298355103, blue: 0.2839399874210358, alpha: 1), #colorLiteral(red: 0.521954357624054, green: 0.7994346618652344, blue: 0.3460423350334167, alpha: 1)])
/*:
### Size and spacing
Try changing the size and spacing of the balls and see how that changes the device. What happens if you make `ballPadding` a negative number?
*/
newtonsCradle.ballSize = CGSize(width: 60, height: 60)
newtonsCradle.ballPadding = 2.0
/*:
### Behavior
Adjust `elasticity` and `resistance` to change how the balls react to eachother.
*/
newtonsCradle.itemBehavior.elasticity = 1.0
newtonsCradle.itemBehavior.resistance = 0.2
/*:
### Shape and rotation
How does Newton's Cradle look if we use squares instead of circles and allow them to rotate?
*/
newtonsCradle.useSquaresInsteadOfBalls = false
newtonsCradle.itemBehavior.allowsRotation = false
/*:
### Gravity
Change the `angle` and/or `magnitude` of gravity to see what Newton's Device might look like in another world.
*/

newtonsCradle.gravityBehavior.angle = CGFloat(M_PI_2)
newtonsCradle.gravityBehavior.magnitude = 1.0
/*:
### Attachment
What happens if you change `length` of the attachment behaviors to different values?
*/
for attachmentBehavior in newtonsCradle.attachmentBehaviors {
    attachmentBehavior.length = 100
}

PlaygroundPage.current.liveView = newtonsCradle

let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
view.backgroundColor = UIColor.green


