//
//  ZPhoneController.swift
//  Zones
//
//  Created by Jonathan Sand on 7/2/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import SnapKit
import UIKit


class ZPhoneController: ZGenericController, UITabBarDelegate {


    override  var                   controllerID: ZControllerID { return .main }
    @IBOutlet var favoritesButtonWidthConstraint: NSLayoutConstraint?
    @IBOutlet var   actionsButtonWidthConstraint: NSLayoutConstraint?
    @IBOutlet var         editorBottomConstraint: NSLayoutConstraint?
    @IBOutlet var            editorTopConstraint: NSLayoutConstraint?
    @IBOutlet var            titleLeftConstraint: NSLayoutConstraint?
    @IBOutlet var            hereWidthConstraint: NSLayoutConstraint?
    @IBOutlet var                 hereTextWidget: ZoneTextWidget?
    @IBOutlet var                favoritesButton: UIButton?
    @IBOutlet var                  actionsButton: UIButton?
    @IBOutlet var                  favoritesView: UIView?
    @IBOutlet var                    actionsView: UIView?
    var                                 isCached: Bool               =  false
    var                             cachedOffset: CGPoint            = .zero
    var                           keyboardHeight: CGFloat            =  0.0
    let                       notificationCenter: NotificationCenter = .default


    // MARK:- hide and show
    // MARK:-


    override func handleSignal(_ object: Any?, in storageMode: ZStorageMode, kind: ZSignalKind) {
        if ![.search, .found, .startup].contains(kind) {
            update()
        }
    }


    @IBAction func goLeftButtonAction(iButton: UIButton) {
        gEditingManager.moveOut(selectionOnly: true, extreme: false)
        update()
    }


    @IBAction func favoritesVisibilityButtonAction(iButton: UIButton) {
        gFavoritesAreVisible = !gFavoritesAreVisible

        update()
    }


    @IBAction func actionsVisibilityButtonAction(iButton: UIButton) {
        gActionsAreVisible = !gActionsAreVisible

        update()
    }


    func update() {
        let                       selectorHeight = CGFloat(48.0)
        let                      emphasizedColor = ZColor.blue.lighter(by: 5.0)
        let                            textColor = ZColor.blue
        let                                 font = gWidgetFont
        let                            hereTitle = gHere.zoneName ?? ""
        let                         actionsTitle = gActionsAreVisible   ? " -> " : " Actions"
        let                       favoritesTitle = gFavoritesAreVisible ? " -> " : " Favorites"
        let                       favoritesWidth = favoritesTitle.widthForFont(font) + 10.0
        actionsButtonWidthConstraint?  .constant = actionsTitle  .widthForFont(font) + 10.0
        favoritesButtonWidthConstraint?.constant = favoritesWidth
        editorBottomConstraint?        .constant = gKeyboardIsVisible   ? keyboardHeight : gActionsAreVisible ? selectorHeight : 0.0
        editorTopConstraint?           .constant = gFavoritesAreVisible ? selectorHeight : 0.0
        titleLeftConstraint?           .constant = gFavoritesAreVisible ? favoritesWidth : 0.0
        hereWidthConstraint?           .constant = hereTitle.widthForFont(font)
        hereTextWidget?                    .text = hereTitle
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


    // MARK:- keyboard
    // MARK:-


    override func viewDidLoad() {
        super    .viewDidLoad()
        hereTextWidget?.setup()

        handleKeyboard = true
    }


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


    func layoutForKeyboard() {
        var              changed = false

        if  gKeyboardIsVisible && !isCached {
            cachedOffset         = gScrollOffset

            if  let       center = gEditorView?.bounds.center,
                let       widget = gWidgetsManager.currentEditingWidget?.textWidget {
                let widgetOffset = widget.convert(widget.bounds.center, to: gEditorView)
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
            gEditorController?.layoutForCurrentScrollOffset()
            gEditorView?.setNeedsDisplay()
        }
    }

}
