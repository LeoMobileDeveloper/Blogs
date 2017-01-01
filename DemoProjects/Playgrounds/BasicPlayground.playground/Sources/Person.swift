import Foundation


public class Person{
    public var name:String
    public var age:UInt
    public init(name:String,age:UInt) {
        self.name = name
        self.age = age
    }
}

extension Person:CustomStringConvertible{
    public var description: String{
        get{
            return "\(name) is \(age) years old"
        }
    }
}
