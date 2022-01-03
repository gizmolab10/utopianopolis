//
//  ZPhoneController.swift
//  Seriously
//
//  Created by Jonathan Sand on 7/2/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//


import SnapKit
import UIKit


class ZPhoneController: ZGenericController, UITabBarDelegate {

    override  var           controllerID : ZControllerID { return .idMain }
    @IBOutlet var editorBottomConstraint : NSLayoutConstraint?
    @IBOutlet var    editorTopConstraint : NSLayoutConstraint?
    @IBOutlet var         hereTextWidget : ZoneTextWidget?
	@IBOutlet var             mapsButton : UIButton?
	@IBOutlet var             undoButton : UIButton?
    @IBOutlet var            actionsView : UIView?
    @IBOutlet var               lineView : UIView?
    var                         isCached : Bool      =  false
    var                     cachedOffset : CGPoint   = .zero
    var                   keyboardHeight : CGFloat   =  0.0

	
	var nextMapFunction: ZFunction {
		switch gCurrentMapFunction {
		case .eMe:     return .ePublic
		case .ePublic: return .eFavorites
		default:       return .eMe
		}
	}
	

    // MARK: - hide and show
    // MARK: -
	

	override func handleSignal(_ object: Any?, kind: ZSignalKind) {
		update()
	}


	@IBAction func mapsButtonAction(iButton: UIButton) {
		gCurrentMapFunction = nextMapFunction

		gActionsController.switchView(to: gCurrentMapFunction)
		update()
	}
	

	@IBAction func undoButtonAction(iButton: UIButton) {
		gMapEditor.undoManager.undo()
	}
	

    func update() {
        let               selectorHeight = CGFloat(48)
        let                    hereTitle = gHereMaybe?.zoneName ?? kEmpty
        editorBottomConstraint?.constant = gKeyboardIsVisible ? keyboardHeight : selectorHeight
        editorTopConstraint?   .constant = gSmallMapIsVisible ? selectorHeight : 2.0
        hereTextWidget?            .text = hereTitle
		mapsButton? 			  .title = gCurrentMapFunction.rawValue
		mapsButton?            .isHidden = false
		actionsView?           .isHidden = false
		undoButton?            .isHidden = false

		gActionsController.update()
		layoutForKeyboard()
    }


    // MARK: - keyboard
    // MARK: -


    override func viewDidLoad() {
        super    .viewDidLoad()
        hereTextWidget?.setup()

        handleKeyboard = true
    }


    var handleKeyboard: Bool? {
        get { return nil }
        set {
            gNotificationCenter.removeObserver (self,                                                                name: UIResponder.keyboardWillShowNotification, object: nil)
            gNotificationCenter.removeObserver (self,                                                                name: UIResponder.keyboardWillHideNotification, object: nil)

            if  newValue ?? false {
                gNotificationCenter.addObserver(self, selector: #selector(ZPhoneController.updateHeightForKeyboard), name: UIResponder.keyboardWillShowNotification, object: nil)
                gNotificationCenter.addObserver(self, selector: #selector(ZPhoneController.updateHeightForKeyboard), name: UIResponder.keyboardWillHideNotification, object: nil)
            }
        }
    }


    @objc func updateHeightForKeyboard(_ notification: Notification) {
        gKeyboardIsVisible     = notification.name == UIResponder.keyboardWillShowNotification
        keyboardHeight         = 0.0

        if  gKeyboardIsVisible,
            let info           = notification.userInfo,
            let frame: NSValue = info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            keyboardHeight     = frame.cgRectValue.height
        }

        update()
    }


    func layoutForKeyboard() {
        var              changed = false

        if  gKeyboardIsVisible && !isCached {
            cachedOffset         = gScrollOffset

            if  let       center = gMapView?.bounds.center,
                let       widget = gWidgets.currentlyEditedWidget?.textWidget {
                let widgetOffset = widget.convert(widget.bounds.center, to: gMapView)
                gScrollOffset    = CGPoint(center - widgetOffset)
                isCached         = true
                changed          = true
            }
        } else if !gKeyboardIsVisible && isCached {
            isCached             = false
            changed              = true
            gScrollOffset        = cachedOffset
        }

        if changed {
            gMapController?.layoutForCurrentScrollOffset()
        }
    }

}
