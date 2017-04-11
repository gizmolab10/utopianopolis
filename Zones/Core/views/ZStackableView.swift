//
//  ZStackableView.swift
//  Zones
//
//  Created by Jonathan Sand on 1/1/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//


import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZStackableView: ZView {


    @IBOutlet var hideableView: ZView?
    @IBOutlet var   titleLabel: ZTextField?
    @IBOutlet var toggleButton: ZButton?


    // MARK:- identity
    // MARK:-
    

    var identity: ZSettingsViewID {
        #if os(OSX)
            if let kind = identifier {
                switch kind {
                case        "help": return .Help
                case "preferences": return .Preferences
                case "information": return .Information
                case   "favorites": return .Favorites
                case       "tools": return .CloudTools
                case           nil: return .All
                default:            return .All
                }
            }
        #endif

        return .All
    }


    var hideableIsHidden: Bool {
        get {
            return gSettingsViewIDs.contains(identity)
        }

        set {
            if newValue {
                gSettingsViewIDs.insert(identity)
            } else {
                gSettingsViewIDs.remove(identity)
            }
        }
    }


    // MARK:- update to UI
    // MARK:-
    

    @IBAction func toggleAction(_ sender: ZButton) {
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
        #if os(OSX)
        var image = ZImage(named: "yangle.png")

        if hideableIsHidden {
            image = (image?.imageRotatedByDegrees(180.0))! as ZImage
        }

        toggleButton?.image = image
        #endif
    }


    func updateHideableView() {
        if !hideableIsHidden {
            hideableView?.removeFromSuperview()
            titleLabel?.snp.makeConstraints { (make: ConstraintMaker) in
                make.bottom.equalTo(self)
            }
        } else if !subviews.contains(hideableView!) {
            addSubview(hideableView!)
            titleLabel?.snp.removeConstraints()
            hideableView?.snp.makeConstraints { (make: ConstraintMaker) in
                make.top.equalTo((self.toggleButton?.snp.bottom)!)
                make.left.right.bottom.equalTo(self)
            }
        }
    }
}
