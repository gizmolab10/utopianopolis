//
//  ZTextManager.swift
//  Zones
//
//  Created by Jonathan Sand on 2/19/18.
//  Copyright © 2018 Zones. All rights reserved.
//

import Foundation


let gTextManager = ZTextManager()


var gIsEditingText: Bool {
    if  gUseNewTextManager {
        return gTextManager.isEditing != nil
    } else {
        return gEditorView?.window?.firstResponder?.isKind(of: ZTextView.self) ?? false
    }
}


class ZTextManager: NSObject {


    var      isEditing:           Zone? = nil
    var isEditingTrait:         ZTrait? = nil
    var   originalText:         String? = nil
    var     textWidget: ZoneTextWidget? { return widget?.textWidget }
    var         widget:     ZoneWidget? { return gWidgetsManager.widgetForZone(isEditing) }
    var          isEditingStateChanging = false


    func fullResign() { assignAsFirstResponder (nil) } // ios broken


    func capture() {
        if  let       text = textWidget?.text {
            if  let  trait = isEditingTrait { // this takes logical priority
                trait.text = text

                trait.needSave()
            } else if let zone = isEditing { // do not process if editing a trait, above
                zone.zoneName  = text

                zone.needSave()
            }
        }
    }


    func edit(_ zRecord: ZRecord) {
        isEditingTrait   = zRecord as? ZTrait
        isEditing        = zRecord as? Zone ?? isEditingTrait?.ownerZone
        originalText     = isEditing?.unwrappedName ?? isEditingTrait?.text
        textWidget?.text = originalText
    }


    func clearEdit() {
        isEditing      = nil
        isEditingTrait = nil
    }


    func deferEditingStateChange() {
        isEditingStateChanging          = true

        FOREGROUND(after: 0.1) {
            self.isEditingStateChanging = false
        }
    }
}
