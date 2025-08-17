import CoreData
import Foundation
import SharedTypes

@objc(MixTape)
public class MixTape: NSManagedObject {
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(Date(), forKey: "createdDate")
        setPrimitiveValue(0, forKey: "numberOfSongs")
        setPrimitiveValue(0, forKey: "playCount")
        setPrimitiveValue(false, forKey: "aiGenerated")
    }
}
