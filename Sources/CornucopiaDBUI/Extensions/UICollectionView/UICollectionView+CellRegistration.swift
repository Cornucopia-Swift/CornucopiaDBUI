//
//  Cornucopia – (C) Dr. Lauer Information Technology
//
import UIKit.UICollectionView

public extension UICollectionView {

    func CC_registerNib<CellType: UICollectionViewCell & ViaModelConfigurable>(for class: CellType.Type) {
        let nibName = String(describing: CellType.self)
        let reuseIdentifier = String(describing: CellType.MODELTYPE.self)
        let nib = UINib(nibName: nibName, bundle: nil)
        self.register(nib, forCellWithReuseIdentifier: reuseIdentifier)
    }

}
