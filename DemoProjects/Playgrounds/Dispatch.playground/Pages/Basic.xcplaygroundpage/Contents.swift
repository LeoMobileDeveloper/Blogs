//: Playground - noun: a place where people can play

import UIKit

//: Just some basic of GCD

let mainQueue = DispatchQueue.main
let globalQueue = DispatchQueue.global()
let globalQueueWithQos = DispatchQueue.global(qos: .userInitiated)
