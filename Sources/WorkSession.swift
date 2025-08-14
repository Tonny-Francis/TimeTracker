import Foundation
import CoreData

@objc(WorkSession)
public class WorkSession: NSManagedObject {
    
}

extension WorkSession {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<WorkSession> {
        return NSFetchRequest<WorkSession>(entityName: "WorkSession")
    }

    @NSManaged public var startTime: Date?
    @NSManaged public var endTime: Date?
    @NSManaged public var duration: Double
    @NSManaged public var isActive: Bool
}
