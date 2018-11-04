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
    @IBOutlet var      titleButton : ZButton?
    @IBOutlet var       toggleIcon : ZButton?
    @IBOutlet var   stackableBelow : ZStackableView?
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
                case       "debug": return .Debug
                case       "tools": return .Tools
                default:            return .All
                }
            }
        #endif

        return .All
    }


    var hideHideable: Bool {
        get {
            return !gIsReadyToShowUI || gHiddenDetailViewIDs.contains(identity)
        }

        set {
            if  newValue {
                gHiddenDetailViewIDs.insert(identity)
            } else {
                gHiddenDetailViewIDs.remove(identity)
            }
        }
    }


    // MARK:- update to UI
    // MARK:-
    

    @IBAction func toggleAction(_ sender: Any) {
        hideHideable = !hideHideable

        update()
    }


    override func awakeFromNib() {
        super.awakeFromNib()
        gDetailsController?.register(id: identity, for: self)
        update()
    }


    func update() {
        titleButton?.state = NSOnState
        
        if  isDebugView {
            if !gShowDebugDetails {
                removeFromSuperview()
            } else if superview == nil {
                gDetailsController?.view.addSubview(self)
            }
        }

        if !isDebugView || gShowDebugDetails {
            updateToggleImage()
            updateBannerGradient()
            updateHideableView()
        }
    }


    func updateBannerGradient() {
        if  let gradientView = bannerView {
            let gradientLayer = CAGradientLayer()
            gradientLayer.frame = gradientView.bounds
            gradientLayer.colors = [gDarkerBackgroundColor, gLighterBackgroundColor]
            gradientView.zlayer = gradientLayer
        }
    }


    func updateToggleImage() {
        #if os(OSX)
        var image = ZImage(named: kTriangleImageName)

        if !hideHideable {
            image = (image?.imageRotatedByDegrees(180.0))! as ZImage
        }

        toggleIcon?.image = image
        #endif
    }


    func updateHideableView() {
        let  hide = hideHideable
        let shown = subviews.contains(hideableView!)

        if  hide && shown {
            hideableView?.removeFromSuperview()
            bannerView?.snp.makeConstraints { make in
                make.bottom.equalTo(self)
            }
        } else if !hide && !shown {
            addSubview(hideableView!)
            
            bannerView?.snp.removeConstraints()
            hideableView?.snp.makeConstraints { make in
                make.top.equalTo((self.bannerView?.snp.bottom)!)
                make.left.right.bottom.equalTo(self)
            }
//
//            let  isLast = stackableBelow?.superview == nil
//            let isFirst = identity == .Information
//
//            snp.removeConstraints()
//            snp.makeConstraints { make in
//                if isFirst {
//                    make.top.equalToSuperview()
//                }
//
//                if  isLast {
//                    make.bottom.equalToSuperview()
//                } else {
//                    make.bottom.equalTo(stackableBelow!)
//                }
//            }

//            FOREGROUND(after: 0.2) {
//                self.hideableView?.setNeedsDisplay()
//            }
        }
    }
}
