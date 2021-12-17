//
//  ZTogglingView.swift
//  Seriously
//
//  Created by Jonathan Sand on 1/1/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//

import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

class ZBannerButton : ZButton {
	@IBOutlet var togglingView : ZTogglingView? // point back at the container (specific stack view)
	var                     on : Bool { return togglingView?.hideHideable ?? false }
	var          offStateImage : ZImage?
	var           onStateImage : ZImage?

	func setup() {
		imagePosition = .imageLeft
		onStateImage  = kTriangleImage?.resize(CGSize(width: 11, height: 12))
		offStateImage = onStateImage?.imageRotatedByDegrees(180.0)
	}

	func updateImageForState() {
		image = on ? onStateImage : offStateImage
	}

}

class ZTogglingView: ZView {

	@IBOutlet var      spinner : ZProgressIndicator?
	@IBOutlet var  titleButton : ZBannerButton?
	@IBOutlet var  extraButton : ZButton?
    @IBOutlet var hideableView : ZView?
	@IBOutlet var   bannerView : ZView?

    // MARK: - identity
    // MARK: -

	var kind: String? {
		return gConvertFromOptionalUserInterfaceItemIdentifier(identifier)
	}

	var toolTipText: String {
		switch identity {
			case .vPreferences : return "preference controls"
			case .vSimpleTools : return "some simple tools which can get you oriented"
			case .vSmallMap    : return "\(gCurrentSmallMapName)s map"
			case .vSubscribe   : return "license details"
			case .vData        : return "useful data about Seriously"
			default            : return kEmpty
		}
	}

	var identity: ZDetailsViewID {
		if  let    k = kind {
			switch k {
				case "preferences": return .vPreferences
				case "simpleTools": return .vSimpleTools
				case "subscribe":   return .vSubscribe
				case "smallMap":    return .vSmallMap
				case "data":        return .vData
				default:            return .vAll
			}
		}

		return .vAll
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

			titleButton?.updateImageForState()
        }
    }

	func toggleHideableVisibility() {
		hideHideable = !hideHideable
	}

    // MARK: - update UI
    // MARK: -

	@IBAction func toggleAction(_ sender: Any) {
		toggleHideableVisibility()
		gDetailsController?.redisplayOnToggle()
	}

    override func awakeFromNib() {
        super.awakeFromNib()
		titleButton?.setup()

		zlayer              .backgroundColor =      kClearColor.cgColor
		hideableView?.zlayer.backgroundColor =      kClearColor.cgColor
		titleButton? .zlayer.backgroundColor =     gAccentColor.cgColor
		extraButton? .zlayer.backgroundColor = gDarkAccentColor.cgColor

        repeatUntil({ () -> (Bool) in
            return gDetailsController != nil
        }) {
            gDetailsController?.register(id: self.identity, for: self)
        }

		update()
    }

	@IBAction func extraButtonAction(_ sender: Any) {
		switch identity {
			case .vSmallMap:  gToggleSmallMapMode(forceToggle: true)
			case .vSubscribe: gSubscriptionController?.toggleViews()
			case .vData:      gMapController?.toggleMaps()
			default:          return
		}

		gRelayoutMaps()
		gSignal([.sDetails])
	}

	fileprivate func updateTitleButton() {
		if  gIsReadyToShowUI {
			switch identity {
				case .vSmallMap:  titleButton?.title = gSmallMapHere?.ancestralString ?? "gerglagaster"
				case .vData:      titleButton?.title = gDatabaseID.userReadableString.capitalized + " Data"
				case .vSubscribe: titleButton?.title = gSubscriptionController?.bannerTitle ?? kSubscribe
				default:          titleButton?.title = titleButton?.alternateTitle ?? "gargleblaster"
			}

			titleButton?.updateImageForState()
		}
	}

	func update() {
		updateSpinner()
		updateTitleButton()
		updateHideableView()
    }

	func updateSpinner() {
		if  let      s = spinner {
			let   hide = gCurrentOp.isDoneOp && gCoreDataStack.isDoneOp
			s.isHidden = hide

			if  hide {
				s.stopAnimation (spinner)
			} else {
				s.startAnimation(spinner)
			}
		}
	}

    func updateHideableView() {
        let    hide = hideHideable
        let visible = subviews.contains(hideableView!)

		titleButton?.updateTooltips()

		if  hide == visible { // need for update
			hideableView?.isHidden = hide

			hideableView?.snp.removeConstraints()
			bannerView?.snp.removeConstraints()

			if  hide {
				hideableView?.removeFromSuperview()
				bannerView?.snp.makeConstraints { make in
					make.bottom.equalTo(self)
				}
			} else {
				addSubview(hideableView!)
				hideableView?.snp.makeConstraints { make in
					make.bottom.equalTo(self)

					if  let b = self.bannerView {
						make.top.equalTo(b.snp.bottom)
						make.left.right.equalTo(b)
					}
				}
			}
		}
    }

}
