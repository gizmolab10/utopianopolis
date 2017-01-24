//
//  ZCheckboxCell.swift
//  Zones
//
//  Created by Jonathan Sand on 1/23/17.
//  Copyright © 2017 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZCheckboxCell: NSTableCellView {


    override var objectValue: Any? {
        get { return super.objectValue }
        set {
            super.objectValue = newValue
        }
    }

}
