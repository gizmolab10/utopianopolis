//
//  ZEditorViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 7/2/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import SnapKit


class ZEditorViewController: ZGenericViewController {

    
    var widget: ZoneWidget = ZoneWidget()


    override func identifier() -> ZControllerID { return .editor }


    override func updateFor(_ object: Any?, kind: ZUpdateKind) {
        switch kind {
        case .key:   handleKey  (object as! String); break
        case .arrow: handleArrow(object as! String); break
        default:
            let                        zone = object as? Zone
            var specificWidget: ZoneWidget? = widget
            var specificView:        ZView? = view
            var specificindex:          Int = -1
            var recursing:             Bool = kind == .data
            widget.widgetZone               = travelManager.rootZone!

            if zone == nil || zone == travelManager.rootZone! {
                recursing = true

                toConsole("all")
                widgetsManager.clear()
            } else {
                specificWidget = widgetsManager.widgetForZone(zone!)
                specificView   = specificWidget?.superview
                specificindex  = zone!.siblingIndex()

                if let name = zone?.zoneName {
                    toConsole(name)
                }
            }

            specificWidget?.layoutInView(specificView, atIndex: specificindex, recursing: recursing)
            specificWidget?.updateConstraints()
            specificWidget?.layoutFinish()
            specificWidget?.display()

            stateManager.textCapturing = false
        }
    }


    override func setup() {
        view.setupGestures(self, action: #selector(ZEditorViewController.gestureEvent))
        super.setup()
    }


    func handleKey(_ key: String) {
        switch key {
        case "\r":
            if let widget = widgetsManager.currentEditingWidget {
                widget.textField.resignFirstResponder()
                editingManager.addZoneTo(widget.widgetZone.parentZone)
            }

            break
        default:
            break
        }
    }


    func handleArrow(_ arrow: String) {
        toConsole(arrow)
    }

    
    func gestureEvent(_ sender: ZGestureRecognizer?) {
        selectionManager.deselect()
    }
}
