//
//  ZoneWidget.swift
//  Zones
//
//  Created by Jonathan Sand on 10/7/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZoneWidget: ZView, ZTextFieldDelegate, ZoneTextFieldDelegate {


    private var      _textField: ZoneTextField!
    var              widgetZone: Zone!
    private var   _childrenView: ZView!
    private var childrenWidgets: [ZoneWidget] = []
    private var    siblingLines: [ZoneCurve]  = []
    var               toggleDot: ZoneDot      = ZoneDot()
    var                 dragDot: ZoneDot      = ZoneDot()
    static  var       capturing: Bool         = false


    var hasChildren: Bool {
        get { return widgetZone.children.count > 0 }
    }


    var textField: ZoneTextField {
        get {
            if _textField == nil {
                _textField                      = ZoneTextField()
                _textField.font                 = widgetFont
                _textField.delegate             = self
                _textField.isBordered           = false
                _textField.textAlignment        = .center
                _textField.backgroundColor      = ZColor.clear
                _textField.zoneWidgetDelegate   = self

                addSubview(_textField)

                _textField.snp.makeConstraints { (make) -> Void in
                    make.width.equalTo(200.0)
                }

                snp.makeConstraints { (make) -> Void in
                    make.centerY.equalTo(_textField)
                    make.size.greaterThanOrEqualTo(_textField)
                }
            }

            return _textField
        }
    }


    var childrenView: ZView {
        get {
            if _childrenView == nil {
                _childrenView                          = ZView()
                _childrenView.isUserInteractionEnabled = false

                addSubview(_childrenView)

                _childrenView.snp.makeConstraints { (make) -> Void in
                    make.top.bottom.right.equalTo(self)
                }
            }

            return _childrenView
        }
    }


    // MARK:- layout
    // MARK:-


    func layoutInView(_ inView: ZView, atIndex: Int) {
        if !inView.subviews.contains(self) {
            inView.addSubview(self)

            if atIndex == -1 {
                snp.remakeConstraints { (make) -> Void in
                    make.center.equalTo(inView)
                }
            }
        }

        zonesManager.registerWidget(self)
        layoutDots()
        layoutChildren()
        layoutText()
    }


    func layoutFinish() {
        layoutDecorations()

        for widget in childrenWidgets {
            widget.layoutFinish()
        }
    }


    func layoutDecorations() {
        // self        .addBorderRelative(thickness: 1.0, radius: 0.5, color: ZColor.green.cgColor)
        // childrenView.addBorderRelative(thickness: 1.0, radius: 0.5, color: ZColor.orange.cgColor)
        // textField.addBorder(thickness: 5.0, radius: 0.5, color: CGColor.black)
    }


    func layoutText() {
        textField.text = widgetZone.zoneName ?? "empty"

        layoutTextField()

        if zonesManager.currentlyEditingZone == widgetZone {
            textField.becomeFirstResponder()
        }
    }


    func layoutTextField() {
        textField.snp.removeConstraints()
        textField.snp.makeConstraints { (make) -> Void in
            let width = textField.text!.widthForFont(widgetFont) + 5.0

            make.width.equalTo(width)
            make.centerY.equalTo(self)
            make.right.lessThanOrEqualTo(self).offset(-29.0)
            make.left.equalTo(self).offset(12.0 + stateManager.genericOffset.width)
            make.height.lessThanOrEqualTo(self).offset(-stateManager.genericOffset.height)

            if hasChildren {
                make.right.equalTo(childrenView.snp.left)
            }
        }
    }


    func layoutChildren() {
        var                 index = widgetZone.children.count
        var previous: ZoneWidget? = nil
        let       hasSiblingLines = index > 0

        for view in childrenView.subviews {
            view.removeFromSuperview()
        }

        childrenView.removeFromSuperview()

        _childrenView = nil

        childrenWidgets.removeAll()

        if index > 0 && widgetZone.showChildren {
            while childrenWidgets.count != index {
                childrenWidgets.append(ZoneWidget())
            }

            while index > 0 {
                index                 -= 1
                let childWidget        = childrenWidgets[index]
                childWidget.widgetZone = widgetZone.children[index]

                childWidget.layoutInView(childrenView, atIndex: index)
                childWidget.snp.makeConstraints({ (make) in
                    if previous != nil {
                        make.bottom.equalTo((previous?.snp.top)!)
                    } else {
                        make.bottom.equalTo(childrenView)
                    }

                    if index == 0 {
                        make.top.equalTo(childrenView)
                    }

                    make.left.equalTo(childrenView).offset(20.0)
                    make.right.height.lessThanOrEqualTo(childrenView)
                })

                var siblingLine: ZoneCurve?

                if hasSiblingLines {
                    siblingLine = ZoneCurve()
                    siblingLine?.child  = childWidget
                    siblingLine?.parent = self

                    siblingLines.append(siblingLine!)
                    childrenView.addSubview(siblingLine!)
                    siblingLine?.snp.makeConstraints({ (make) in
                        make.width.height.equalTo(stateManager.lineThicknes)
                        make.center.equalTo(toggleDot)
                    })
                }

                childWidget.layoutText()

                previous = childWidget
            }
        }
    }


    func layoutDots() {
        if widgetZone.children.count != 0 {
            addSubview(toggleDot)
            toggleDot.setupForZone(widgetZone, asToggle: true)
            toggleDot.innerDot?.snp.makeConstraints({ (make) in
                make.left.equalTo(textField.snp.right).offset(-1.0)
                make.centerY.equalTo(textField).offset(1.0)
                make.right.lessThanOrEqualToSuperview().offset(-1.0)
            })
        }

        if widgetZone != zonesManager.rootZone {
            addSubview(dragDot)
            dragDot.setupForZone(widgetZone, asToggle: false)
            dragDot.innerDot?.snp.makeConstraints({ (make) in
                make.right.equalTo(textField.snp.left)
                make.centerY.equalTo(textField)
            })
        }
    }


    // MARK:- delegates
    // MARK:-


    func captureText() {
        if  ZoneWidget.capturing             == false {
            ZoneWidget.capturing              = true
            widgetZone.zoneName               = textField.text!
            zonesManager.currentlyEditingZone = nil
        }
    }


    func selectForEditing() {
        zonesManager.currentlyEditingZone = widgetZone
    }


#if os(OSX)

    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        captureText()

        return true
    }


    @discardableResult func stopEditing() -> Bool {
        if let editor = textField.currentEditor() {
            return control(textField, textShouldEndEditing: editor)
        }

        return true
    }


    override func controlTextDidChange(_ obj: Notification) {
        layoutTextField()
    }

#elseif os(iOS)

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        captureText()

        return true
    }


    @discardableResult func stopEditing() -> Bool {
        return textFieldShouldEndEditing(textField)
    }


//    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
//        updateLayout()
//        selectForEditing()
//
//        return true
//    }

#endif
}
