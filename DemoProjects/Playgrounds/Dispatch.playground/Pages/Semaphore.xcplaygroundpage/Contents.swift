//: [Previous](@previous)

import Foundation
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true
let semaphore = DispatchSemaphore(value: 2)
let queue = DispatchQueue(label: "com.leo.concurrentQueue", qos: .default, attributes: .concurrent)

queue.async {
    semaphore.wait()
    usbTask(label: "1", cost: 2, complete: {
        semaphore.signal()
    })
}

queue.async {
    semaphore.wait()
    usbTask(label: "2", cost: 2, complete: {
        semaphore.signal()
    })
}

queue.async {
    semaphore.wait()
    usbTask(label: "3", cost: 1, complete: {
        semaphore.signal()
    })
}


//: [Next](@next)
