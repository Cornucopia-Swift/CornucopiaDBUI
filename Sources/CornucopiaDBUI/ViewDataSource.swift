//
//  Cornucopia – (C) Dr. Lauer Information Technology
//
import CornucopiaDB
import YapDatabase
import UIKit
import OSLog

private var logger = OSLog(subsystem: "de.vanille.Cornucopia.DBUI", category: "ViewDataSource")

public extension CornucopiaDBUI {

    /// (Abstract) Base class for Database-driven UIKit data sources
    class ViewDataSource: NSObject, DataSource {

        public let mappings: YapDatabaseViewMappings
        public let connection: YapDatabaseConnection

        init(with mappings: YapDatabaseViewMappings, for databaseView: String, connection: YapDatabaseConnection) {
            self.mappings = mappings
            self.connection = connection
        }

        convenience init(for databaseView: String, connection: YapDatabaseConnection, mappings: YapDatabaseViewMappings? = nil) {
            let m = mappings ?? {
                let filtering: YapDatabaseViewMappingGroupFilter = { group, transaction in
                    true
                }
                let sorting: YapDatabaseViewMappingGroupSort = { group1, group2, transaction in
                    group1.caseInsensitiveCompare(group2)
                }
                return YapDatabaseViewMappings(groupFilterBlock: filtering, sortBlock: sorting, view: databaseView)
            }()
            self.init(with: m, for: databaseView, connection: connection)
        }

        public var isEmpty: Bool { self.mappings.numberOfItemsInAllGroups() > 0 }

        public var totalNumberOfElements: Int { Int(self.mappings.numberOfItemsInAllGroups()) }

        public var numberOfSections: Int { Int(self.mappings.numberOfSections()) }

        public func numberOfItems(in section: Int) -> Int { Int(self.mappings.numberOfItems(inSection: UInt(section))) }

        public func item(at indexPath: IndexPath) -> Any? {
            var item: Any? = nil
            self.connection.read {
                guard let vt = $0.ext(self.mappings.view) as? YapDatabaseViewTransaction else {
                    fatalError("Can't get view transaction for view '\(self.mappings.view)'")
                }
                item = vt.object(at: indexPath, with: mappings)
            }
            return item
        }

        public func keyForItem(at indexPath: IndexPath) -> String? {
            guard let group = self.mappings.group(forSection: UInt(indexPath.section)) else {
                fatalError("Can't get group for section \(indexPath.section)")
            }
            var key: String? = nil
            self.connection.read {
                guard let vt = $0.ext(self.mappings.view) as? YapDatabaseViewTransaction else {
                    fatalError("Can't get view transaction for view '\(self.mappings.view)'")
                }
                key = vt.key(at: UInt(indexPath.item), inGroup: group)
            }
            return key
        }

        public func keyedItem(at indexPath: IndexPath) -> (key: String, item: Any)? {
            guard let group = self.mappings.group(forSection: UInt(indexPath.section)) else {
                fatalError("Can't get group for section \(indexPath.section)")
            }
            var item: Any? = nil
            var key: String? = nil
            self.connection.read {
                guard let vt = $0.ext(self.mappings.view) as? YapDatabaseViewTransaction else {
                    fatalError("Can't get view transaction for view '\(self.mappings.view)'")
                }
                key = vt.key(at: UInt(indexPath.item), inGroup: group)
                item = vt.object(at: indexPath, with: mappings)
            }
            return key != nil && item != nil ? (key!, item!) : nil
        }

        public func allItems() -> [Any] {
            var items: [Any] = []
            self.connection.read {
                guard let vt = $0.ext(self.mappings.view) as? YapDatabaseViewTransaction else {
                    fatalError("Can't get view transaction for view '\(self.mappings.view)'")
                }

                for section: Int in 0...Int(self.mappings.numberOfSections()) {
                    for item: Int in 0...Int(self.mappings.numberOfItems(inSection: UInt(section))) {
                        let indexPath = IndexPath(item: item, section: section)
                        guard let any = vt.object(at: indexPath, with: mappings) else {
                            continue
                        }
                        items.append(any)
                    }
                }
            }
            return items
        }

        func populateMappings() {
            os_log(.debug, log: logger, "View '%s' Populate Mappings start", self.mappings.view)
            self.connection.beginLongLivedReadTransaction()
            self.connection.read { t in
                self.mappings.update(with: t)
            }
            NotificationCenter.default.addObserver(self, selector: #selector(self.onDatabaseModified(notification:)), name: Notification.Name.YapDatabaseModified, object: self.connection.database)
            os_log(.debug, log: logger, "View '%s' Populate Mappings end", self.mappings.view)
        }

        // Subclasses should provide this call. If you override it, make sure to either call the base implementation, or update the mappings manually within this call (i.e. by calling `getChanges` on the view connection).
        func updateUserInterface(notifications: [Notification]) {
            self.connection.read { t in
                self.mappings.update(with: t)
            }
        }
    }
}

extension CornucopiaDBUI.ViewDataSource {

    @objc func onDatabaseModified(notification: Notification) {
        let notifications = self.connection.beginLongLivedReadTransaction()
        guard notifications.count > 0 else {
            os_log(.debug, log: logger, "View '%s', nothing to update.", self.mappings.view)
            return
        }
        let snapshot = self.mappings.snapshotOfLastUpdate
        os_log(.debug, log: logger, "View '%s' Update Mappings start", self.mappings.view)
        self.updateUserInterface(notifications: notifications)
        assert(self.mappings.snapshotOfLastUpdate > snapshot, "Fails here, if the mappings were not updated within the implementation of `updateUserInterface`.")
        os_log(.debug, log: logger, "View '%s' Update Mappings end", self.mappings.view)
    }
}
