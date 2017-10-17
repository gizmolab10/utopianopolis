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


    var             widgetZone : Zone   { return widget.widgetZone }
    override var preferredFont : ZFont  { return widgetZone.isInFavorites ? gFavoritesFont : gWidgetFont }
    weak var            widget : ZoneWidget!
    var           originalText = ""
    var         _isTextEditing = false


    override var isTextEditing: Bool {
        get { return _isTextEditing }
        set {
            if  _isTextEditing != newValue {
                _isTextEditing  = newValue
                let       zone  = widgetZone
                font            = preferredFont

                if !_isTextEditing {
                    let  grab = gSelectionManager.currentlyEditingZone == zone
                    textColor = !grab ? ZColor.black :zone.grabbedTextColor

                    abortEditing()

                    if  grab {
                        gSelectionManager.clearEdit()

                        zone.grab()
                    }
                } else {
                    gSelectionManager.currentlyEditingZone = zone
                    textColor                              = ZColor.black
                    originalText                           = zone.zoneName ?? ""

                    gSelectionManager.deselectGrabs()
                    enableUndo()
                    updateText()

                    #if os(iOS)
                        selectAllText()
                    #endif
                }
            }
        }
    }


    #if os(OSX)

    override func textShouldBeginEditing(_ textObject: NSText) -> Bool {

        //////////////////////////
        // THIS IS NEVER CALLED //
        //////////////////////////

        isTextEditing = true

        return true
    }


    override func keyDown(with event: NSEvent) {
        textInputReport("text field \"\(widgetZone.decoratedName)\"")
        super.keyDown(with: event)
    }

    #endif


    override func setup() {
        delegate               = self
        isBordered             = false
        textAlignment          = .left
        backgroundColor        = gClearColor
        zlayer.backgroundColor = gClearColor.cgColor
        font                   = preferredFont

        #if os(iOS)
            autocapitalizationType = .none
        #endif
    }


    func layoutText() {
        updateText()
        layoutTextField()
    }

    func updateGUI() {
        layoutTextField()
        widget.setNeedsDisplay()
    }


    func layoutTextField() {
        snp.removeConstraints()
        snp.makeConstraints { make in
            let textWidth = text!.widthForFont(preferredFont)
            let    height = gGenericOffset.height
            let     width = !widgetZone.isVisible ? 0.0 : textWidth + 5.0
            let      view = superview!

            make.centerY.equalTo(view).offset(-verticalTextOffset)
            make   .left.equalTo(view).offset(gGenericOffset.width + 4.0)
            make  .right.lessThanOrEqualTo(view).offset(-29.0)
            make .height.lessThanOrEqualTo(view).offset(-height)
            make  .width.equalTo(width)
        }
    }


    @discardableResult override func resignFirstResponder() -> Bool {
        var result = false

        if !gSelectionManager.isEditingStateChanging {
            captureText(force: false)

            result = super.resignFirstResponder()

            if result && isTextEditing {
                gSelectionManager.clearGrab()

                FOREGROUND { // avoid state garbling
                    self.isTextEditing = false
                }
            }
        }

        return result
    }


    @discardableResult override func becomeFirstResponder() -> Bool {
        if !gSelectionManager.isEditingStateChanging {
            super.becomeFirstResponder() // do this first so delegate methods will be called

            isTextEditing = true
        }

        return true
    }


    override func selectCharacter(in range: NSRange) {
        #if os(OSX)
        if let textInput = currentEditor() {
            textInput.selectedRange = range
        }
        #endif
    }


    override func updateText() {
        let zone = widgetZone
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
        if  let t = iText, let zone = iZone {
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

            if  zone.isBookmark, let link = zone.crossLink, let mode = link.storageMode, let target = gRemoteStoresManager.cloudManagerFor(mode).zoneForRecordID(link.record.recordID) {
                assignTextTo(target)
            }

            var bookmarks = [Zone] ()

            for bookmark in gRemoteStoresManager.bookmarksFor(zone) {
                bookmarks.append(bookmark)
                assignTextTo(bookmark)
            }

            redrawAndSync() {
                gTextCapturing = false

                for bookmark in bookmarks {
                    self.signalFor(bookmark, regarding: .datum)
                }
            }
        }
    }


    override func captureText(force: Bool) {
        let zone = widgetZone

        if !gTextCapturing || force, zone.zoneName != text! {
            assign(text, to: zone)
        }
    }


    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        let             zone = widgetZone

        if  zone.isBookmark, !zone.isGrabbed, !isTextEditing {
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
