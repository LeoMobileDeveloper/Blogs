//: Playground - noun: a place where people can play

import UIKit
import PlaygroundSupport
import XCPlayground

var str = "Hello, playground"

//: This is the basic usage about moudle
let person = Person(name: "Leo", age: 25)

/*:
 ## PlaygroundSupport
 Then we look at how to write a simple view which will change background Color on Tap
*/
let demoView = RandomColorView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
PlaygroundPage.current.liveView = demoView


/*:
 ## Mark Up
 Swift Playground has powerful mark up comments. You can see mark up by clicking *Editor* -> *Show Rendered Markup*
 To see mark up, See [Next](@next).
 */
 