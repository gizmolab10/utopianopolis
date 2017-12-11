//
//  ZoneTextWidget.swift
//  Zones
//
//  Created by Jonathan Sand on 10/27/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZoneTextWidget: ZTextField, ZTextFieldDelegate {


    override var         preferredFont : ZFont { return (widgetZone?.isInFavorites ?? false) ? gFavoritesFont : gWidgetFont }
    var                     widgetZone : Zone? { return widget?.widgetZone }
    weak var                    widget : ZoneWidget?
    var            isEditiingHyperlink = false
    var                isEditiingEmail = false
    var                 _isEditingText = false
    var                   originalText = ""


    var textToEdit: String {
        if  let    name = isEditiingHyperlink ? widgetZone?.hyperLink: isEditiingEmail ? widgetZone?.email : widgetZone?.unwrappedName, name != gNullLink {
            return name
        }

        return gNoName
    }


    override var isEditingText: Bool {
        get { return _isEditingText }
        set {
            if  _isEditingText != newValue {
                _isEditingText  = newValue
                font            = preferredFont
                let           s = gSelectionManager

                if  let   zone  = widgetZone {
                    if !_isEditingText {
                        let            grab = s.currentlyEditingZone == zone
                        textColor           = !grab ? ZColor.black : zone.grabbedTextColor

                        abortEditing() // NOTE: this does NOT remove selection highlight !!!!!!!
                        deselectAllText()

                        if  grab {
                            s.clearEdit()

                            zone.grab()
                        }

                        isEditiingEmail        = false
                        isEditiingHyperlink    = false
                    } else {
                        s.currentlyEditingZone = zone
                        textColor              = ZColor.black
                        originalText           = textToEdit

                        s.deselectGrabs()
                        enableUndo()
                    }

                    layoutText()
                } else {
                    s.clearEdit()
                }
            }
        }
    }


    override func setup() {
        delegate                   = self
        isBordered                 = false
        textAlignment              = .left
        backgroundColor            = gClearColor
        zlayer.backgroundColor     = gClearColor.cgColor
        font                       = preferredFont

        #if os(iOS)
            autocapitalizationType = .none
        #else
            isEditable             = widgetZone?.isWritableByUseer ?? false
        #endif
    }


    func layoutText() {
        updateText()
        layoutTextField()
    }

    func updateGUI() {
        layoutTextField()
        widget?.setNeedsDisplay()
    }


    func layoutTextField() {
        if  let           view = superview {
            snp.removeConstraints()
            snp.makeConstraints { make in
                let textWidth = text!.widthForFont(preferredFont)
                let  hideText = widgetZone?.onlyShowToggleDot ?? true
                let    height = gGenericOffset.height
                let     width = hideText ? 0.0 : textWidth + 5.0

                make.centerY.equalTo(view).offset(-verticalTextOffset)
                make   .left.equalTo(view).offset(gGenericOffset.width + 4.0)
                make  .right.lessThanOrEqualTo(view).offset(-29.0)
                make .height.lessThanOrEqualTo(view).offset(-height)
                make  .width.equalTo(width)
            }
        }
    }


    @discardableResult override func becomeFirstResponder() -> Bool {
        if !gSelectionManager.isEditingStateChanging && widgetZone?.isWritableByUseer ?? false {

            if  isFirstResponder {
                gSelectionManager.deferEditingStateChange()
            }

            isEditingText = super.becomeFirstResponder() // becomeFirstResponder is called first so delegate methods will be called

            return isEditingText
        }

        return false
    }


    override func selectCharacter(in range: NSRange) {
        #if os(OSX)
        if let textInput = currentEditor() {
            textInput.selectedRange = range
        }
        #endif
    }


    override func updateText() {
        if  let zone = widgetZone {
            text     = textToEdit
            var need = 0

            switch gCountsMode {
            case .fetchable: need = zone.indirectFetchableCount
            case .progeny:   need = zone.indirectFetchableCount + zone.progenyCount
            default:         return
            }

            if (need > 1) && !isEditingText && (!zone.showChildren || (gCountsMode == .progeny)) {
                text?.append("  (\(need))")
            }
        }
    }


    override func alterCase(up: Bool) {
        if  var t = text {
            t = up ? t.uppercased() : t.lowercased()

            assign(t, to: widgetZone)
            updateGUI()
        }
    }
    

    func prepareUndoForTextChange(_ manager: UndoManager?,_ onUndo: @escaping Closure) {
        if originalText != text {
            manager?.registerUndo(withTarget:self) { iUndoSelf in
                let            newText = iUndoSelf.text ?? ""
                iUndoSelf        .text = iUndoSelf.originalText
                iUndoSelf.originalText = newText

                onUndo()
            }
        }
    }



    func assign(_ iText: String?, to iZone: Zone?) {
        if  let t = iText, var  zone = iZone, t != gNoName {
            gTextCapturing           = true

            let         assignTextTo = { (iAssignee: Zone) in
                let       components = t.components(separatedBy: "  (")
                var newText: String? = components[0]

                if  newText == gNoName || newText == gNullLink || newText == "" {
                    newText  = nil
                }

                if self.isEditiingHyperlink {
                    iAssignee.hyperLink = newText
                    iAssignee    .email = nil
                } else if self.isEditiingEmail {
                    iAssignee.hyperLink = nil
                    iAssignee    .email = newText
                } else {
                    iAssignee .zoneName = newText
                }

                iAssignee.needSave()
                self.redrawAndSync()
            }

            prepareUndoForTextChange(gUndoManager) {
                self.captureText(force: true)
                self.updateGUI()
            }

            assignTextTo(zone)

            if isEditiingHyperlink || isEditiingEmail {
                gTextCapturing = false
            } else {
                if  let target = zone.bookmarkTarget {
                    zone       = target

                    assignTextTo(target)
                }

                var bookmarks = [Zone] ()

                for bookmark in gRemoteStoresManager.bookmarksFor(zone) {
                    bookmarks.append(bookmark)
                    assignTextTo(bookmark)
                }

                redrawAndSync {
                    gTextCapturing = false

                    for bookmark in bookmarks {
                        self.signalFor(bookmark, regarding: .datum)
                    }
                }
            }
        }
    }


    override func captureText(force: Bool = false) {
        let zone = widgetZone

        if (!gTextCapturing && originalText != text!) || force {
            assign(text, to: zone)
        }
    }


    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        if  let zone = widgetZone,
            (zone.isBookmark || zone.isHyperlink || zone.isEmail),
            !zone.isFavorite,
            !zone.isGrabbed,
            !isEditingText {

            ///////////////////////////////////////////////////////////
            // draw line underneath text indicating it is a bookmark //
            ///////////////////////////////////////////////////////////

            var         rect = dirtyRect.insetBy(dx: 3.0, dy: 0.0)
            rect.size.height = 0.0
            rect.size.width -= 4.0
            rect.origin.y    = dirtyRect.maxY - 1.0
            let path         = ZBezierPath(rect: rect)
            path  .lineWidth = 0.7

            zone.color.setStroke()
            path.stroke()
        }
    }
}
