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


class ZoneWidget: ZoneTextField, ZoneTextFieldDelegate {

    var                      widgetZone: Zone!
    @IBOutlet weak var  widthConstraint: NSLayoutConstraint!


    func layoutWithText(_ value: String) {
        self.text     = value
        self.delegate = self

        updateLayout()
    }


    func updateLayout() {
        self.widthConstraint.constant = self.text!.widthForFont(self.font! as ZFont) + 35.0
    }


    func submit() {
        updateLayout()

        widgetZone.zoneName = self.text!
    }


#if os(OSX)

    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        submit()

        return true
    }


    override func controlTextDidChange(_ obj: Notification) {
        updateLayout()
    }

#elseif os(iOS)

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        submit()

        return true
    }


//    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
//        updateLayout()
//
//        return true
//    }

#endif
}
