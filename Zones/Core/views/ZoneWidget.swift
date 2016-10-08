//
//  ZoneWidget.swift
//  Zones
//
//  Created by Jonathan Sand on 10/7/16.
//  Copyright © 2016 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZoneWidget: ZoneTextField {

    var            widgetZone: Zone!
    @IBOutlet weak var  width: NSLayoutConstraint!


    func layoutWithText(_ value: String) {
        self.text = value

        updateLayout()
    }


    func updateLayout() {
        self.width.constant = self.text!.widthForFont(self.font! as ZFont) + 25.0
    }


    func submit() {
        updateLayout()

        widgetZone.zoneName = self.text!
    }
}
