//
//  ZStackableView.swift
//  Seriously
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

    // MARK:- update UI
    // MARK:-

    override func awakeFromNib() {
        super.awakeFromNib()
        self.update()

        repeatUntil({ () -> (Bool) in
            return gDetailsController != nil
        }) {
            gDetailsController?.register(id: self.identity, for: self)
        }
    }

	@IBAction func toggleAction(_ sender: Any) {
		toggleHideableVisibility()
		update()
	}

    func toggleHideableVisibility() {
        hideHideable = !hideHideable
    }
    
    func update() {
        turnOnTitleButton()
		toggleIcon?.setState(!hideHideable)
		updateBannerGradient()
		updateHideableView()
    }

	var colors: [CGColor] {
		let lighter = gAccentColor.lighter(by: 4.0).cgColor
		let  darker = gAccentColor.darker (by: 4.0).cgColor

		return gIsDark ? [lighter, darker] : [darker, lighter]
	}

    func updateBannerGradient() {
        if  let gradientView     = bannerView {
            let gradientLayer    = CAGradientLayer()
            gradientLayer.frame  = gradientView.bounds
			gradientLayer.colors = colors

			gradientView.zlayer.removeAllSublayers()
			gradientView.zlayer.insertSublayer(gradientLayer, at: 0)
        }
    }


    func updateHideableView() {
        let    hide = hideHideable
        let visible = subviews.contains(hideableView!)

        if  hide && visible {
            hideableView?.removeFromSuperview()
            bannerView?.snp.makeConstraints { make in
                make.bottom.equalTo(self)
            }
        } else if !hide && !visible {
            addSubview(hideableView!)
            
            bannerView?.snp.removeConstraints()
            hideableView?.snp.makeConstraints { make in
                make.top.equalTo((self.bannerView?.snp.bottom)!)
                make.left.right.bottom.equalTo(self)
            }
        }
    }
}
