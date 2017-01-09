//: [Previous](@previous)

import Foundation
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true

var str = "Hello, playground"

//: [Next](@next)


let userData = DispatchSource.makeUserDataAddSource()
var globalData:UInt = 0
userData.setEventHandler {
    let pendingData = userData.data
    globalData = globalData + pendingData
    print("Add \(pendingData) to global and current global is \(globalData)")
}
userData.resume()

let serialQueue = DispatchQueue(label: "com")
serialQueue.async {
    for var index in 1...1000{
        userData.add(data: 1)
    }
    for var index in 1...1000{
        userData.add(data: 1)
    }
}
