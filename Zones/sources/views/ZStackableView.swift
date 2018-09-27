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


    @IBOutlet var       bannerView : ZView?
    @IBOutlet var     hideableView : ZView?
    @IBOutlet var     toggleButton : ZButton?
    @IBOutlet var       titleLabel : ZTextField?
    let               debugViewIDs : [ZDetailsViewID] = [.Debug, .Tools]
    var                isDebugView : Bool { return debugViewIDs.contains(identity) }

    // MARK:- identity
    // MARK:-
    

    var identity: ZDetailsViewID {
        #if os(OSX)
            if let kind = identifier {
                switch kind {
                case "preferences": return .Preferences
                case "information": return .Information
                case   "shortcuts": return .Shortcuts
                case       "debug": return .Debug
                case       "tools": return .Tools
                default:            return .All
                }
            }
        #endif

        return .All
    }


    var hideableIsHidden: Bool {
        get {
            if gIsReadyToShowUI  {
                return gDetailsViewIDs.contains(identity)
            } else {
                return true
            }
        }

        set {
            if newValue {
                gDetailsViewIDs.insert(identity)
            } else {
                gDetailsViewIDs.remove(identity)
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
        super.awakeFromNib()
        update()
    }


    func update() {
        if  isDebugView {
            titleLabel?.superview?.isHidden = !gDebugDetails
            hideableView?         .isHidden = !gDebugDetails
        }

        if !isDebugView || gDebugDetails {
            updateToggleImage()
            updateHideableView()
        }
    }


    func updateToggleImage() {
        #if os(OSX)
        var image = ZImage(named: kTriangleImageName)

        if !hideableIsHidden {
            image = (image?.imageRotatedByDegrees(180.0))! as ZImage
        }

        toggleButton?.image = image
        #endif
    }


    func updateHideableView() {
        if  hideableIsHidden {
            hideableView?.removeFromSuperview()
            titleLabel?.snp.makeConstraints { make in
                make.bottom.equalTo(self)
            }
        } else {
            if !subviews.contains(hideableView!) {
                addSubview(hideableView!)
            }

            titleLabel?.snp.removeConstraints()
            hideableView?.snp.makeConstraints { make in
                make.top.equalTo((self.bannerView?.snp.bottom)!)
                make.left.right.bottom.equalTo(self)
            }

            FOREGROUND(after: 0.2) {
                self.hideableView?.setNeedsDisplay()
            }
        }
    }
}
