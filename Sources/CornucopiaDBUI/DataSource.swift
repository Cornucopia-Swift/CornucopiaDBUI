//
//  Cornucopia – (C) Dr. Lauer Information Technology
//
import Foundation

public protocol DataSource {

    var isEmpty: Bool { get }
    var totalNumberOfElements: Int { get }
    var numberOfSections: Int { get }
    func numberOfItems(in section: Int) -> Int
    func item(at indexPath: IndexPath) -> Any?
    func allItems() -> [Any]

}

public protocol ViaModelConfigurable {

    associatedtype MODELTYPE

    func configure(_ model: MODELTYPE)

    //    var model: MODELTYPE? { get }

}
