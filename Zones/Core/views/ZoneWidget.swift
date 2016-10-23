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

    @IBOutlet weak var  widthConstraint: NSLayoutConstraint!
    var widgetZone: Zone!


    func updateInView(_ inView: ZView) -> CGRect {
        if !inView.subviews.contains(self) {
            inView.addSubview(self)
        }

        delegate = self

        layoutWithText(widgetZone.zoneName)

        return self.frame
    }


    func updateInView(_ inView: ZView, atOffset: CGPoint) {
        var rect: CGRect = updateInView(inView)
        rect.origin      = atOffset

        if rect.size.width == 0.0 {
            rect.size    = CGSize(width: 20.0, height: 20.0)
        }

        self.frame       = rect
    }
    

    func layoutWithText(_ value: String?) {
        if value != nil {
            text = value

            updateLayout()
        }
    }


    func updateLayout() {
        self.widthConstraint.constant = self.text!.widthForFont(self.font! as ZFont) + 35.0
    }


    func captureText() {
        updateLayout()

        widgetZone.zoneName = self.text!
    }


    // MARK:- delegates
    // MARK:-


#if os(OSX)

    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        captureText()

        return true
    }


    override func controlTextDidChange(_ obj: Notification) {
        updateLayout()
    }

#elseif os(iOS)

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        captureText()

        return true
    }


//    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
//        updateLayout()
//
//        return true
//    }

#endif
}
