import CoreData
import Foundation

@objc(Song)
public class Song: NSManagedObject {
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(0, forKey: "playCount")
        setPrimitiveValue(0, forKey: "positionInTape")
    }
}
