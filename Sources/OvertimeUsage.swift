import Foundation
import CoreData

@objc(OvertimeUsage)
public class OvertimeUsage: NSManagedObject {
    
}

extension OvertimeUsage {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<OvertimeUsage> {
        return NSFetchRequest<OvertimeUsage>(entityName: "OvertimeUsage")
    }

    @NSManaged public var date: Date?
    @NSManaged public var hoursUsed: Double
    @NSManaged public var reason: String?
}
