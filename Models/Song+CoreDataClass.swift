import Foundation
import CoreData

@objc(Song)
public class Song: NSManagedObject {
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(0, forKey: "playCount")
        setPrimitiveValue(0, forKey: "positionInTape")
    }
}
