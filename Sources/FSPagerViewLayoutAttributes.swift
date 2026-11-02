//
//  FSPagerViewLayoutAttributes.swift
//  FSPagerViewExample
//
//  Created by Wenchao Ding on 26/02/2017.
//  Copyright © 2017 Wenchao Ding. All rights reserved.
//

import UIKit

open class FSPagerViewLayoutAttributes: UICollectionViewLayoutAttributes {

    open var position: CGFloat = 0
    
    open override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? FSPagerViewLayoutAttributes else {
            return false
        }
        // UIKit compares layout attributes on the main thread.
        return MainActor.assumeIsolated {
            super.isEqual(object) && self.position == object.position
        }
    }
    
    open override func copy(with zone: NSZone? = nil) -> Any {
        let copy = super.copy(with: zone) as! FSPagerViewLayoutAttributes
        copy.position = self.position
        return copy
    }
    
}
