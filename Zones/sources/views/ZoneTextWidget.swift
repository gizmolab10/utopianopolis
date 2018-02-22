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


    override var         preferredFont : ZFont { return (widget?.isInMain ?? true) ? gWidgetFont : gFavoritesFont }
    var                     widgetZone : Zone? { return widget?.widgetZone }
    weak var                    widget : ZoneWidget?
    var                 _isEditingText = false


    override var isEditingText: Bool {
        get { return _isEditingText }
        set {
            let                 t = gTextManager

            if  _isEditingText   != newValue {
                _isEditingText    = newValue
                font              = preferredFont

                if  let     zone  = widgetZone {
                    if !_isEditingText {
                        let  grab = t.currentlyEditingZone == zone
                        abortEditing() // NOTE: this does NOT remove selection highlight !!!!!!!
                        deselectAllText()

                        if  grab {
                            t.clearEdit()

                            zone.grab()
                        }

                        text      = zone.unwrappedName
                    } else {
                        t.edit(zone)

                        gSelectionManager.deselectGrabs()
                        enableUndo()
                    }

                    layoutText(isEditing: true)
                } else {
                    t.clearEdit()
                }
            } else if newValue, let zone = widgetZone {
                t.edit(zone)
            }
        }
    }


    func updateTextColor() {
        if  let  zone = widgetZone {
            textColor = zone.colorized ? zone.grabbedTextColor : ZColor.black
        }
    }


    override func setup() {
        delegate                   = self
        isBordered                 = false
        textAlignment              = .left
        backgroundColor            = kClearColor
        zlayer.backgroundColor     = kClearColor.cgColor
        font                       = preferredFont

        #if os(iOS)
            autocapitalizationType = .none
        #else
            isEditable             = widgetZone?.isWritableByUseer ?? false
        #endif
    }


    func layoutText(isEditing: Bool = false) {
        gTextManager.updateText(inZone: widgetZone, isEditing: isEditing)
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
                let  hideText = widgetZone?.onlyShowRevealDot ?? true
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
        if !gTextManager.isEditingStateChanging && widgetZone?.isWritableByUseer ?? false {

            if  isFirstResponder {
                gTextManager.deferEditingStateChange()
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


    var textWithSuffix: String {
        var   result = widgetZone?.unwrappedName ?? kNoName

        if  let zone = widgetZone {
            var need = 0

            switch gCountsMode {
            case .fetchable: need = zone.indirectFetchableCount
            case .progeny:   need = zone.indirectFetchableCount + zone.progenyCount
            default:         return result
            }

            var suffix: String? = nil

            /////////////////////////////////////
            // add suffix for "show counts as" //
            /////////////////////////////////////

            if  gDebugShowIdentifiers && zone.record != nil {
                suffix = zone.recordName
            } else if (need > 1) && (!zone.showChildren || (gCountsMode == .progeny)) {
                suffix = String(describing: need)
            }

            if  let s = suffix {
                result.append("  (" + s + ")")
            }
        }

        return result
    }


    override func alterCase(up: Bool) {
        if  var t = text {
            t = up ? t.uppercased() : t.lowercased()

            gTextManager.assign(t, to: widgetZone)
            updateGUI()
        }
    }


    override func draw(_ dirtyRect: CGRect) {
        if  let  zone = widgetZone {
            textColor = zone.colorized ? zone.color : ZColor.black
        }

        super.draw(dirtyRect)

        if  let zone = widgetZone,
             zone.canTravel,
            !zone.isGrabbed,
            !isFirstResponder {

            ////////////////////////////////////////////////////////
            // draw line underneath text indicating it can travel //
            ////////////////////////////////////////////////////////

            var         rect = dirtyRect.insetBy(dx: 3.0, dy: 0.0)
            rect.size.height = 0.0
            rect.size.width -= 4.0
            rect.origin.y    = dirtyRect.maxY - 1.0
            let path         = ZBezierPath(rect: rect)
            path  .lineWidth = 0.4

            zone.color.setStroke()
            path.stroke()
        }
    }
}
