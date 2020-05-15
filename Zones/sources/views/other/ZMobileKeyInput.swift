//
//  ZMobileKeyInput.swift
//  iFocus
//
//  Created by Jonathan Sand on 4/28/19.
//  Copyright © 2019 Zones. All rights reserved.
//

import UIKit

class ZMobileKeyInput : UIControl, UIKeyInput {
    
    var hasText = false
    override var canBecomeFirstResponder: Bool {return true}
    
    func deleteBackward() {}

    public func insertText(_ text: String) {
        gGraphEditor.handleKey(text, flags: ZEventFlags(), isWindow: true)
    }

}
