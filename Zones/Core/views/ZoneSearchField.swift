//
//  ZoneSearchField.swift
//  Zones
//
//  Created by Jonathan Sand on 12/16/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZoneSearchField: ZSearchField, ZSearchFieldDelegate {


    var isResigning = false


    @discardableResult override func resignFirstResponder() -> Bool {
        var result = false

        if !isResigning {
            isResigning = true
            result      = super.resignFirstResponder()

            self.dispatchAsyncInForegroundAfter(0.5) {
                self.isResigning = false
            }
        }

        return result
    }


    @discardableResult override func becomeFirstResponder() -> Bool {
        return super.becomeFirstResponder()
    }

}
