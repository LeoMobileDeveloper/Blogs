//: [Previous](@previous)

import Foundation
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

let concurrentQueue = DispatchQueue(label: "com.leo.concurrent", attributes: .concurrent)
concurrentQueue.async {
    readDataTask(label: "1", cost: 3)
}

concurrentQueue.async {
    readDataTask(label: "2", cost: 3)
}
concurrentQueue.async(flags: .barrier, execute: {
    NSLog("Task from barrier 1 begin")
    sleep(3)
    NSLog("Task from barrier 1 end")
})

concurrentQueue.async {
    readDataTask(label: "3", cost: 3)
}
