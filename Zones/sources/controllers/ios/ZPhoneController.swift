//
//  ZPhoneController.swift
//  Zones
//
//  Created by Jonathan Sand on 7/2/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import SnapKit
import UIKit


let selectorHeight: CGFloat = 48.0


class ZPhoneController: ZGenericController, UITabBarDelegate {


    override  var                   controllerID: ZControllerID { return .main }
    @IBOutlet var favoritesButtonWidthConstraint: NSLayoutConstraint?
    @IBOutlet var   actionsButtonWidthConstraint: NSLayoutConstraint?
    @IBOutlet var         editorBottomConstraint: NSLayoutConstraint?
    @IBOutlet var            editorTopConstraint: NSLayoutConstraint?
    @IBOutlet var                favoritesButton: UIButton?
    @IBOutlet var                  actionsButton: UIButton?
    @IBOutlet var                  favoritesView: UIView?
    @IBOutlet var                    actionsView: UIView?
    var                                 isCached: Bool               =  false
    var                             cachedOffset: CGPoint            = .zero
    var                           keyboardHeight: CGFloat            =  0.0
    let                       notificationCenter: NotificationCenter = .default


    var handleKeyboard: Bool? {
        get { return nil }
        set {
            notificationCenter.removeObserver (self,                                                                name: .UIKeyboardWillShow, object: nil)
            notificationCenter.removeObserver (self,                                                                name: .UIKeyboardWillHide, object: nil)

            if  newValue ?? false {
                notificationCenter.addObserver(self, selector: #selector(ZPhoneController.updateHeightForKeyboard), name: .UIKeyboardWillShow, object: nil)
                notificationCenter.addObserver(self, selector: #selector(ZPhoneController.updateHeightForKeyboard), name: .UIKeyboardWillHide, object: nil)
            }
        }
    }


    override func viewDidLoad() {
        super    .viewDidLoad()

        handleKeyboard = true
    }


    override func handleSignal(_ object: Any?, in storageMode: ZStorageMode, kind: ZSignalKind) {
        if ![.search, .found, .startup].contains(kind) {
            update()
        }
    }


    func updateHeightForKeyboard(_ notification: Notification) {
        gKeyboardIsVisible     = notification.name == .UIKeyboardWillShow
        keyboardHeight         = 0.0

        if  gKeyboardIsVisible,
            let info           = notification.userInfo,
            let frame: NSValue = info[UIKeyboardFrameEndUserInfoKey] as? NSValue {
            keyboardHeight     = frame.cgRectValue.height
        }

        update()
    }


    func update() {
        let                      emphasizedColor = ZColor.blue.lighter(by: 5.0)
        let                            textColor = ZColor.blue
        let                                 font = UIFont.systemFont(ofSize: 15.0)
        let                         actionsTitle = gActionsAreVisible   ? " Hide " : " Actions ... "
        let                       favoritesTitle = gFavoritesAreVisible ? " Hide " : " Favorites ... "
        editorTopConstraint?           .constant = gFavoritesAreVisible ? selectorHeight : 0.0
        editorBottomConstraint?        .constant = gKeyboardIsVisible   ? keyboardHeight : gActionsAreVisible ? selectorHeight : 0.0
        actionsButtonWidthConstraint?  .constant = actionsTitle  .widthForFont(font) + 10.0
        favoritesButtonWidthConstraint?.constant = favoritesTitle.widthForFont(font) + 10.0
        favoritesButton?               .isHidden = false
        actionsButton?                 .isHidden = false
        favoritesView?                 .isHidden = false
        actionsView?                   .isHidden = false
        let                          buttonSetup = { (iButton: UIButton?, iTitle: String, iHidden: Bool) in
            if  let                       button = iButton {
                button                    .title = iTitle
                button          .backgroundColor = iHidden ? emphasizedColor : ZColor.clear

                button.setTitleColor(              iHidden ? ZColor.white    : textColor, for: .normal)
                button.addBorder(thickness: 1.0, radius: 5.0, color: iHidden ? textColor.cgColor : ZColor.clear.cgColor)
            }
        }

        buttonSetup(favoritesButton, favoritesTitle, gFavoritesAreVisible)
        buttonSetup(  actionsButton,   actionsTitle,   gActionsAreVisible)
        layoutForKeyboard()
    }


    func layoutForKeyboard() {
        var              changed = false

        if  gKeyboardIsVisible {
            cachedOffset         = gScrollOffset

            if  let       center = gEditorView?.bounds.center,
                let       widget = gWidgetsManager.currentEditingWidget?.textWidget {
                let widgetOffset = widget.convert(widget.bounds.center, to: gEditorView)
                gScrollOffset    = CGPoint(center - widgetOffset)
                isCached         = true
                changed          = true
            }
        } else if isCached {
            isCached             = false
            changed              = true
            gScrollOffset        = cachedOffset
        }

        if changed {
            gEditorController?.layoutForCurrentScrollOffset()
            gEditorView?.setNeedsDisplay()
        }
    }


    @IBAction func favoritesVisibilityButtonAction(iButton: UIButton) {
        gFavoritesAreVisible = !gFavoritesAreVisible

        update()
    }


    @IBAction func actionsVisibilityButtonAction(iButton: UIButton) {
        gActionsAreVisible = !gActionsAreVisible

        update()
    }
}
