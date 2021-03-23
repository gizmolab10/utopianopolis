//
//  ZMobileKeyInput.swift
//  Seriously
//
//  Created by Jonathan Sand on 4/28/19.
//  Copyright © 2019 Jonathan Sand. All rights reserved.
//

import UIKit

class ZMobileKeyInput : UIControl, UIKeyInput {
    
    var hasText = false
    override var canBecomeFirstResponder: Bool {return true}
    
    func deleteBackward() {}

    public func insertText(_ text: String) {
        gMapEditor.handleKey(text, flags: ZEventFlags(), isWindow: true)
    }

}
