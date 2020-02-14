//
//  ZStackableView.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 1/1/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZStackableView: ZView {


    @IBOutlet var     bannerView : ZView?
    @IBOutlet var   hideableView : ZView?
    @IBOutlet var    titleButton : ZButton?
    @IBOutlet var     toggleIcon : ZToggleButton?
    @IBOutlet var stackableBelow : ZStackableView?
    let             debugViewIDs : [ZDetailsViewID] = [.Debug, .Tools]
    var              isDebugView : Bool { return debugViewIDs.contains(identity) }

    // MARK:- identity
    // MARK:-
    

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
        toggleHideableVisibility()
        update()
    }


    override func awakeFromNib() {
        super.awakeFromNib()
        self.update()

        repeatUntil({ () -> (Bool) in
            return gDetailsController != nil
        }) {
            gDetailsController?.register(id: self.identity, for: self)
        }
    }

    
    func toggleHideableVisibility() {
        hideHideable = !hideHideable
    }
    
    
    func update() {
        turnOnTitleButton()

		let show = gDebugMode.contains(.info)

        if  isDebugView {
            if !show {
                removeFromSuperview()
            } else if superview == nil {
                gDetailsController?.view.addSubview(self)
            }
        }

		if !isDebugView || show {
            toggleIcon?.setState(!hideHideable)
            updateBannerGradient()
            updateHideableView()
        }
    }


    func updateBannerGradient() {
        if  let gradientView = bannerView {
            let gradientLayer = CAGradientLayer()
            gradientLayer.frame = gradientView.bounds
			gradientLayer.colors = [gDarkerBackgroundColor.cgColor, gLighterBackgroundColor.cgColor]
            gradientView.zlayer.insertSublayer(gradientLayer, at: 0)
        }
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
