//: [Previous](@previous)

import Foundation
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true

NSLog("Group created")
let group = DispatchGroup()
group.enter()
networkTask(label: "1", cost: 2, complete: {
    group.leave()
})

group.enter()
networkTask(label: "2", cost: 4, complete: {
    group.leave()
})
NSLog("Before wait")
//在这个点，等待三秒钟
group.wait(timeout:.now() + .seconds(3))
NSLog("After wait")
group.notify(queue: .main, execute:{
    print("All network is done")
})

//: [Next](@next)
