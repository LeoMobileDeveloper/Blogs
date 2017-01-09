//: [Previous](@previous)

import Foundation
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true

public let timer = DispatchSource.makeTimerSource()

timer.setEventHandler {
    //这里要注意循环引用，[weak self] in
    print("Timer fired at \(NSDate())")
}
timer.setCancelHandler {
    print("Timer canceled at \(NSDate())" )
}
timer.scheduleRepeating(deadline: .now() + .seconds(1), interval: 2.0, leeway: .microseconds(10))
print("Timer resume at \(NSDate())")
timer.resume()
DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(10), execute:{
    timer.cancel()
})


//: [Next](@next)
