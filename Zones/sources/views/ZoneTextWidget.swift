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
    var             isEditingHyperlink = false
    var                 isEditingEmail = false
    var                 _isEditingText = false


    var textToEdit: String {
        if  let    name = isEditingHyperlink ? widgetZone?.hyperLink: isEditingEmail ? widgetZone?.email : widgetZone?.unwrappedName, name != kNullLink {
            return name
        }

        return kNoName
    }


    override var isEditingText: Bool {
        get { return _isEditingText }
        set {
            let                 s = gTextManager

            if  _isEditingText   != newValue {
                _isEditingText    = newValue
                font              = preferredFont

                if  let     zone  = widgetZone {
                    if !_isEditingText {
                        let  grab = s.currentlyEditingZone == zone
                        textColor = grab || zone.colorized ? zone.grabbedTextColor : ZColor.black

                        abortEditing() // NOTE: this does NOT remove selection highlight !!!!!!!
                        deselectAllText()

                        if  grab {
                            s.clearEdit()

                            zone.grab()
                        }

                        clearEditState()

                        text      = zone.unwrappedName
                    } else {
                        s.edit(zone)
                        textColor = ZColor.black

                        gSelectionManager.deselectGrabs()
                        enableUndo()
                    }

                    layoutText()
                } else {
                    s.clearEdit()
                }
            } else if newValue, let zone = widgetZone {
                s.edit(zone)
            }
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


    override func updateText() {
        if  let   zone = widgetZone {
            text       = textToEdit
            var   need = 0

            switch gCountsMode {
            case .fetchable: need = zone.indirectFetchableCount
            case .progeny:   need = zone.indirectFetchableCount + zone.progenyCount
            default:         return
            }

            if !isFirstResponder {
                var decoration: String? = nil

                /////////////////////////////////////////
                // add decoration for "show counts as" //
                /////////////////////////////////////////

                if  gShowIdentifiers, let id = widgetZone?.record.recordID {
                    decoration = id.recordName
                } else if (need > 1) && (!zone.showChildren || (gCountsMode == .progeny)) {
                    decoration = String(describing: need)
                }

                if  let d = decoration {
                    text?.append("  (" + d + ")")
                }
            }
        }
    }


    override func alterCase(up: Bool) {
        if  var t = text {
            t = up ? t.uppercased() : t.lowercased()

            gTextManager.assign(t, to: widgetZone)
            updateGUI()
        }
    }


    func clearEditState() {
        isEditingEmail     = false
        isEditingHyperlink = false
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
