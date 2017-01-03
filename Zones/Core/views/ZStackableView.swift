//
//  ZStackableView.swift
//  Zones
//
//  Created by Jonathan Sand on 1/1/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZStackableView: ZView {


    @IBOutlet var hideableView: NSView?
    @IBOutlet var   titleLabel: NSTextField?
    @IBOutlet var toggleButton: NSButton?


    // MARK:- state
    // MARK:-
    

    var state: ZSettingsState {
        get {
            if let kind = identifier {
                switch kind {
                case        "help": return .Help
                case "preferences": return .Preferences
                case     "details": return .Details
                case     "actions": return .Actions
                case           nil: return .All
                default:            return .All
                }
            }

            return .All
        }
    }


    var hideableIsHidden: Bool {
        get {
            return settingsState.contains(state)
        }

        set {
            if newValue {
                settingsState.insert(state)
            } else {
                settingsState.remove(state)
            }
        }
    }


    // MARK:- update to UI
    // MARK:-
    

    @IBAction func toggleAction(_ sender: NSButton) {
        hideableIsHidden = !hideableIsHidden

        update()
    }


    override func awakeFromNib() {
        update()
    }


    func update() {
        updateToggleImage()
        updateHideableView()
    }


    func updateToggleImage() {
        var image = ZImage(named: "yangle.png")

        if hideableIsHidden {
            image = (image?.imageRotatedByDegrees(180.0))! as ZImage
        }

        toggleButton?.image = image
    }


    func updateHideableView() {
        if hideableIsHidden {
            addSubview(hideableView!)
            titleLabel?.snp.removeConstraints()
            hideableView?.snp.makeConstraints({ (make: ConstraintMaker) in
                make.top.equalTo((self.toggleButton?.snp.bottom)!)
                make.left.right.bottom.equalTo(self)
            })
        } else {
            hideableView?.removeFromSuperview()
            titleLabel?.snp.makeConstraints({ (make: ConstraintMaker) in
                make.bottom.equalTo(self)
            })
        }
    }
}
