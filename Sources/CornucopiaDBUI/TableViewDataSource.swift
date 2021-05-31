//
//  Cornucopia – (C) Dr. Lauer Information Technology
//
import CornucopiaDB
import YapDatabase
import UIKit
import OSLog

private var logger = OSLog(subsystem: "de.vanille.Cornucopia.DBUI", category: "TableViewDataSource")

public extension CornucopiaDBUI {

    /// A Database-driven data source for a UITableView.
    /// NOTE: Classic-style editing is no longer supported. This is better handled
    /// via swipe actions in the `UITableViewDelegate`.
    class TableViewDataSource<CELLTYPE: UITableViewCell & ViaModelConfigurable,
                                   HEADERTYPE: UITableViewHeaderFooterView & ViaModelConfigurable>: ViewDataSource, UITableViewDataSource {

        weak var tableView: UITableView!
        var supplementaryViewClasses: [String: AnyClass] = [:]
        //public var delegate: YapDatabaseDataSourceDelegate?

        /// The number of sections required for us to show the index bar
        public var sectionThresholdForIndexAppearance = 10
        /// number of elements required for us to show the index bar
        public var itemThresholdForIndexAppearance = 20
        /// The number of elements required for us to show index title
        public var itemThresholdForSectionHeaderAppearance = 20

        /// Register (and set) the data source for use with the specified `collectionView`.
        public func registerAsDataSource(for tableView: UITableView) {
            tableView.dataSource = self
            self.tableView = tableView
            self.populateMappings()
        }

        #if false
        public func registerReusableView(klass: AnyClass, forSupplementaryViewOfKind: String) {
            precondition(self.collectionView != nil, "Not registered as data source for a collection view yet. Call registerAsDataSource first!")
            supplementaryViewClasses[forSupplementaryViewOfKind] = klass
            self.collectionView.register(klass, forSupplementaryViewOfKind: forSupplementaryViewOfKind, withReuseIdentifier: forSupplementaryViewOfKind)
        }
        #endif

        //MARK: <UITableViewDataSource>
        public func numberOfSections(in tableView: UITableView) -> Int {
            Int(self.mappings.numberOfSections())
        }

        public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            Int(self.mappings.numberOfItems(inSection: UInt(section)))
        }

        public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            guard let modelObject = self.item(at: indexPath) as? CELLTYPE.MODELTYPE else {
                fatalError("Can't get a \(CELLTYPE.MODELTYPE.self) for indexPath \(indexPath)")
            }
            let identifier = "\(type(of:modelObject))"
            let reusableCell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
            guard let cell = reusableCell as? CELLTYPE else {
                fatalError("Expected a \(CELLTYPE.self), but got a \(type(of: reusableCell)) instead")
            }
            cell.configure(modelObject)
            return cell
        }

        //MARK: - Internal
        override func updateUserInterface(notifications: [Notification]) {
            guard self.tableView.window != nil else {
                self.connection.read { self.mappings.update(with: $0) }
                // don't bother updating animated, if we're not visible
                self.tableView.reloadData()
                return
            }
            self.animateDatabaseUpdates(notifications: notifications)
        }
    }
}

extension CornucopiaDBUI.TableViewDataSource {

    func animateDatabaseUpdates(notifications: [Notification]) {

        guard let dbView = self.connection.extension(self.mappings.view) as? YapDatabaseViewConnection else { fatalError("Extension for view '\(self.mappings.view) not present") }
        let changes = dbView.changes(for: notifications, with: self.mappings)
        guard !changes.isEmpty else { return }

        self.tableView.performBatchUpdates {
            changes.sections.forEach { sectionChange in
                let indexSet = IndexSet([Int(sectionChange.index)])
                switch sectionChange.type {
                    case .insert:
                        self.tableView.insertSections(indexSet, with: .automatic)
                    case .delete:
                        self.tableView.deleteSections(indexSet, with: .automatic)
                    default:
                        fatalError("Unhandled section change \(sectionChange)")
                }
            }

            changes.rows.forEach { rowChange in
                switch rowChange.type {
                    case .insert:
                        guard let indexPath = rowChange.newIndexPath else { return }
                        self.tableView.insertRows(at: [indexPath], with: .automatic)
                    case .delete:
                        guard let indexPath = rowChange.indexPath else { return }
                        self.tableView.deleteRows(at: [indexPath], with: .automatic)
                    case .move:
                        guard let indexPath = rowChange.indexPath, let newIndexPath = rowChange.newIndexPath else { return }
                        self.tableView.moveRow(at: indexPath, to: newIndexPath)
                    case .update:
                        guard let indexPath = rowChange.indexPath else { return }
                        self.tableView.reloadRows(at: [indexPath], with: .automatic)
                    default:
                        fatalError("Unhandled row change \(rowChange)")
                }
            }
        }
    }
}

public extension CornucopiaDB.View {

    func tableViewDataSource<C, H>(connection: CornucopiaDB.Connection) -> CornucopiaDBUI.TableViewDataSource<C, H> {
        CornucopiaDBUI.TableViewDataSource(for: self.name, connection: connection)
    }

}
