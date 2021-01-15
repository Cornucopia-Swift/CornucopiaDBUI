//
//  Cornucopia – (C) Dr. Lauer Information Technology
//
import CornucopiaDB
import YapDatabase
import UIKit
import OSLog

private var logger = OSLog(subsystem: "de.vanille.Cornucopia.DBUI", category: "CollectionViewDataSource")

public extension CornucopiaDBUI {

    /// A Database-driven data source that can drive a UICollectionView
    class CollectionViewDataSource<CELLTYPE: UICollectionViewCell & ViaModelConfigurable,
                                   HEADERTYPE: UICollectionReusableView & ViaModelConfigurable>: ViewDataSource, UICollectionViewDataSource {

        weak var collectionView: UICollectionView!
        var supplementaryViewClasses: [String: AnyClass] = [:]
        //public var delegate: YapDatabaseDataSourceDelegate?

        /// The number of sections required for us to show the index bar
        public var sectionThresholdForIndexAppearance = 10
        /// number of elements required for us to show the index bar
        public var itemThresholdForIndexAppearance = 20
        /// The number of elements required for us to show index title
        public var itemThresholdForSectionHeaderAppearance = 20

        /// Register (and set) the data source for use with the specified `collectionView`.
        public func registerAsDataSource(for collectionView: UICollectionView) {
            collectionView.dataSource = self
            self.collectionView = collectionView
            self.populateMappings()
        }

        public func registerReusableView(klass: AnyClass, forSupplementaryViewOfKind: String) {
            precondition(self.collectionView != nil, "Not registered as data source for a collection view yet. Call registerAsDataSource first!")
            supplementaryViewClasses[forSupplementaryViewOfKind] = klass
            self.collectionView.register(klass, forSupplementaryViewOfKind: forSupplementaryViewOfKind, withReuseIdentifier: forSupplementaryViewOfKind)
        }

        //MARK: <UICollectionViewDataSource>
        public func numberOfSections(in collectionView: UICollectionView) -> Int {
            Int(self.mappings.numberOfSections())
        }

        public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            Int(self.mappings.numberOfItems(inSection: UInt(section)))
        }

        public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            guard let modelObject = self.item(at: indexPath) as? CELLTYPE.MODELTYPE else {
                fatalError("Can't get a \(CELLTYPE.MODELTYPE.self) for indexPath \(indexPath)")
            }
            let identifier = "\(type(of:modelObject))"
            let reusableCell = collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath)
            guard let cell = reusableCell as? CELLTYPE else {
                fatalError("Expected a \(CELLTYPE.self), but got a \(type(of: reusableCell)) instead")
            }
            cell.configure(modelObject)
            return cell
        }

        public func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {

            switch kind {
                case UICollectionView.elementKindSectionHeader:
                    guard let v = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: kind, for: indexPath) as? HEADERTYPE else {
                        fatalError("Can't get a \(HEADERTYPE.self) as supplementary view of kind \(kind) for indexPath \(indexPath)")
                    }
                    let groupName = self.mappings.group(forSection: UInt(indexPath.section)) ?? "<untitled group>"
                    v.configure(groupName as! HEADERTYPE.MODELTYPE)
                    return v

                default:
                    os_log(.debug, "Unsupported reusable kind '%s'", kind)
            }
            return UICollectionReusableView()
        }

        public func indexTitles(for collectionView: UICollectionView) -> [String]? {
            guard self.mappings.numberOfSections() > self.sectionThresholdForIndexAppearance else { return nil }
            guard self.mappings.numberOfItemsInAllGroups() > self.itemThresholdForIndexAppearance else { return nil }
            return self.mappings.allGroups.map { String($0.first!) }
        }

        public func collectionView(_ collectionView: UICollectionView, indexPathForIndexTitle title: String, at index: Int) -> IndexPath {
            for (index, element) in self.mappings.allGroups.enumerated() {
                let firstCharacter = String(element.first!)
                if firstCharacter == title {
                    return IndexPath(item: 0, section: index)
                }
            }
            return IndexPath(item: 0, section: 0)
        }

        public func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool { true }
        public func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
            print("TODO: move item at \(sourceIndexPath) to \(destinationIndexPath)")
        }

        //MARK: - Internal

        override func updateUserInterface(notifications: [Notification]) -> Bool {
            guard self.collectionView.window != nil else {
                // don't bother updating animated, if we're not visible
                self.collectionView.reloadData()
                return false // caller needs to update mappings
            }
            self.animateDatabaseUpdates(notifications: notifications)
            return true
        }
    }
}

extension CornucopiaDBUI.CollectionViewDataSource {

    func animateDatabaseUpdates(notifications: [Notification]) {

        guard let dbView = self.connection.extension(self.mappings.view) as? YapDatabaseViewConnection else { fatalError("Extension for view '\(self.mappings.view) not present") }
        let changes = dbView.changes(for: notifications, with: self.mappings)
        guard !changes.isEmpty else { return }

        self.collectionView.performBatchUpdates {
            changes.sections.forEach { sectionChange in
                let indexSet = IndexSet([Int(sectionChange.index)])
                switch sectionChange.type {
                    case .insert:
                        self.collectionView.insertSections(indexSet)
                    case .delete:
                        self.collectionView.deleteSections(indexSet)
                    default:
                        fatalError("Unhandled section change \(sectionChange)")
                }
            }

            changes.rows.forEach { rowChange in
                switch rowChange.type {
                    case .insert:
                        guard let indexPath = rowChange.newIndexPath else { return }
                        self.collectionView.insertItems(at: [indexPath])
                    case .delete:
                        guard let indexPath = rowChange.indexPath else { return }
                        self.collectionView.deleteItems(at: [indexPath])
                    case .move:
                        guard let indexPath = rowChange.indexPath, let newIndexPath = rowChange.newIndexPath else { return }
                        self.collectionView.moveItem(at: indexPath, to: newIndexPath)
                    case .update:
                        guard let indexPath = rowChange.indexPath else { return }
                        self.collectionView.reloadItems(at: [indexPath])
                    default:
                        fatalError("Unhandled row change \(rowChange)")
                }
            }
        }
    }
}

public extension CornucopiaDB.View {

    func collectionViewDataSource<C, H>(connection: CornucopiaDB.Connection) -> CornucopiaDBUI.CollectionViewDataSource<C, H> {
        CornucopiaDBUI.CollectionViewDataSource(for: self.name, connection: connection)
    }

}
