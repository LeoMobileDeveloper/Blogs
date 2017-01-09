import Foundation


public func readDataTask(label:String, cost:UInt32){
    NSLog("Start data task%@",label)
    sleep(cost)
    NSLog("End data task%@",label)
}

public func networkTask(label:String, cost:UInt32, complete:@escaping ()->()){
    NSLog("Start network Task task%@",label)
    DispatchQueue.global().async {
        sleep(cost)
        NSLog("End networkTask task%@",label)
        DispatchQueue.main.async {
            complete()
        }
    }
}

public func usbTask(label:String, cost:UInt32, complete:@escaping ()->()){
    NSLog("Start usb task%@",label)
    sleep(cost)
    NSLog("End usb task%@",label)
    complete()
}
