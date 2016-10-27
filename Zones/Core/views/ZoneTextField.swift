//
//  ZoneTextField.swift
//  Zones
//
//  Created by Jonathan Sand on 10/27/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


protocol ZoneTextFieldDelegate {
    func select()
}


class ZoneTextField: ZTextField {


    var zoneDelegate: ZoneTextFieldDelegate?

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with:event)

        zoneDelegate!.select()
    }

}
