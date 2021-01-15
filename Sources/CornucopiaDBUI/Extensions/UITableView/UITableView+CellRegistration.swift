//
//  Cornucopia – (C) Dr. Lauer Information Technology
//
import UIKit.UITableView

public extension UITableView {

    func CC_registerNib<CellType: UITableViewCell & ViaModelConfigurable>(for class: CellType.Type) {
        let nibName = String(describing: CellType.self)
        let reuseIdentifier = String(describing: CellType.MODELTYPE.self)
        let nib = UINib(nibName: nibName, bundle: nil)
        self.register(nib, forCellReuseIdentifier: reuseIdentifier)
    }

}
