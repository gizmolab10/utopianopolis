//
//  ZKeyView.swift
//  Zones
//
//  Created by Jonathan Sand on 2/3/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation
import UIKit


class ZKeyView: ZView, UIKeyInput {
    var hasText: Bool { get { return true } }


    func insertText(_ text: String) {
        gEditingManager.handleKey(text, flags: ZEventFlags.presses, isWindow: true)
    }


    func deleteBackward() {}


    override func becomeFirstResponder() -> Bool {
        return super.becomeFirstResponder()
    }


    override var canBecomeFirstResponder: Bool { get { return true } }
}
