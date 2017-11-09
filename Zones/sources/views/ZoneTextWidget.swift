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


    var                     widgetZone : Zone? { return widget?.widgetZone }
    override var         preferredFont : ZFont { return (widgetZone?.isInFavorites ?? false) ? gFavoritesFont : gWidgetFont }
    weak var                    widget : ZoneWidget?
    var                   originalText = ""
    var                 _isTextEditing = false


    override var isTextEditing: Bool {
        get { return _isTextEditing }
        set {
            if  _isTextEditing != newValue {
                _isTextEditing  = newValue
                font            = preferredFont
                let           s = gSelectionManager

                if  let   zone  = widgetZone {
                    if !_isTextEditing {
                        let  grab = s.currentlyEditingZone == zone
                        textColor = !grab ? ZColor.black : zone.grabbedTextColor

                        abortEditing()

                        if  grab {
                            s.clearEdit()

                            zone.grab()
                        }
                    } else {
                        s.currentlyEditingZone = zone
                        textColor              = ZColor.black
                        originalText           = zone.zoneName ?? ""

                        s.deselectGrabs()
                        enableUndo()
                        updateText()

                        //                    #if os(iOS)
                        //                        selectAllText()
                        //                    #endif
                    }
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
        snp.removeConstraints()
        snp.makeConstraints { make in
            let zoneHidden = !(widgetZone?.isVisible ?? true)
            let  textWidth = text!.widthForFont(preferredFont)
            let     height = gGenericOffset.height
            let      width = zoneHidden ? 0.0 : textWidth + 5.0
            let       view = superview!

            make.centerY.equalTo(view).offset(-verticalTextOffset)
            make   .left.equalTo(view).offset(gGenericOffset.width + 4.0)
            make  .right.lessThanOrEqualTo(view).offset(-29.0)
            make .height.lessThanOrEqualTo(view).offset(-height)
            make  .width.equalTo(width)
        }
    }


//    @discardableResult override func resignFirstResponder() -> Bool {
//        var result = false
//
//        if !gSelectionManager.isEditingStateChanging {
////            gSelectionManager.deferEditingStateChange()
//            captureText(force: false)
//
//            result = super.resignFirstResponder()
//
//            if result && isTextEditing {
//                gSelectionManager.clearGrab()
//
//                FOREGROUND { // avoid state garbling
//                    self.isTextEditing = false
//                }
//            }
//        }
//
//        return result
//    }


    @discardableResult override func becomeFirstResponder() -> Bool {
        if !gSelectionManager.isEditingStateChanging && widgetZone?.isWritableByUseer ?? false {

            if window?.firstResponder == self {
                gSelectionManager.deferEditingStateChange()
            }

            isTextEditing = super.becomeFirstResponder() // becomeFirstResponder is called first so delegate methods will be called

            return isTextEditing
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
            text     = zone.unwrappedName
            var need = 0

            switch gCountsMode {
            case .fetchable: need = zone.fetchableCount
            case .progeny:   need = zone.fetchableCount + zone.progenyCount
            default:         return
            }

            if (need > 1) && !isTextEditing && (!zone.showChildren || (gCountsMode == .progeny)) {
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
        if  let t = iText, var zone = iZone {
            gTextCapturing          = true

            let        assignTextTo = { (iTarget: Zone) in
                let      components = t.components(separatedBy: "  (")
                iTarget   .zoneName = components[0]

                if !iTarget.isInFavorites {
                    iTarget.needFlush()
                }
            }

            prepareUndoForTextChange(gUndoManager) {
                self.captureText(force: true)
                self.updateGUI()
            }

            assignTextTo(zone)

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


    override func captureText(force: Bool) {
        let zone = widgetZone

        if !gTextCapturing || force, zone?.zoneName != text! {
            assign(text, to: zone)
        }
    }


    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        if  let zone = widgetZone,
            zone.isBookmark,
            !zone.isInFavorites,
            !zone.isGrabbed,
            !isTextEditing {

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
