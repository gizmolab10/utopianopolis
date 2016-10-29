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


    private var         _textField: ZoneTextField!
    var                 widgetZone: Zone!
    private var      _childrenView: ZView!
    private var    connectLineView: ZView!       = ZView()
    private var    childrenWidgets: [ZoneWidget] = []
    private var childVisibilityDot: ZoneDot      = ZoneDot()
    private var            dragDot: ZoneDot      = ZoneDot()


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
                // _textField.maximumNumberOfLines = 1

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
                _childrenView = ZView()

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


    func layoutView(_ inView: ZView, atIndex: Int) {
        if !inView.subviews.contains(self) {
            inView.addSubview(self)

            if atIndex == -1 {
                snp.remakeConstraints { (make) -> Void in
                    make.center.equalTo(inView)
                }
            }
        }

        if modelManager.currentlyEditingZone == widgetZone {
            textField.becomeFirstResponder()
        }

        layoutChildrensView()
        layoutDecorations()
        layoutText()
    }


    func layoutText() {
        textField.text = widgetZone.zoneName ?? "empty"

        layoutTextField()
    }


    func layoutTextField() {
        textField.snp.removeConstraints()
        textField.snp.makeConstraints { (make) -> Void in
            let width = textField.text!.widthForFont(widgetFont) + 5.0

            make.width.equalTo(width)
            make.centerY.equalTo(self)
            make.left.equalTo(self).offset(12.0)
            make.right.lessThanOrEqualToSuperview()

            if hasChildren {
                make.right.equalTo(childrenView.snp.left).offset(-stateManager.genericOffset.width)
            }
        }

        updateConstraints()
        // textField   .addBorder(thickness: 5.0, fractionalRadius: 0.5, color: CGColor.black)
        // childrenView.addBorder(thickness: 1.0, fractionalRadius: 0.5, color: NSColor.blue.cgColor)
    }


    func layoutChildrensView() {
        var                 index = widgetZone.children.count
        var previous: ZoneWidget? = nil
        let       hasSiblingLines = index > 1

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

            if index > 0 {
                childrenView.addSubview(connectLineView)

                connectLineView.wantsLayer = true
                connectLineView.zlayer.backgroundColor = stateManager.lineColor

                connectLineView.snp.makeConstraints({ (make) in
                    make.height.equalTo(stateManager.lineThicknes)
                    make.centerY.equalTo(textField).offset(1.0)
                    make.left.equalTo(childrenView).offset(10.0)
                    make.width.equalTo(stateManager.genericOffset.width + 9.0)
                })
            }

            while index > 0 {
                index                 -= 1
                let childWidget        = childrenWidgets[index]
                childWidget.widgetZone = widgetZone.children[index]

                childWidget.layoutView(childrenView, atIndex: index)
                childWidget.snp.makeConstraints({ (make) in
                    if previous != nil {
                        make.bottom.equalTo((previous?.snp.top)!).offset(-stateManager.genericOffset.height)
                    } else {
                        make.bottom.equalTo(childrenView)
                    }

                    if index == 0 {
                        make.top.equalTo(childrenView)
                    }

                    make.left.equalTo(childrenView).offset(20.0)
                    make.right.lessThanOrEqualTo(childrenView).offset(-10.0)
                    make.height.lessThanOrEqualTo(childrenView)
                })

                if hasSiblingLines && previous != nil {
                    let lineView = ZView()
                    lineView.wantsLayer = true
                    lineView.zlayer.backgroundColor = stateManager.lineColor
                    childrenView.addSubview(lineView)

                    lineView.snp.makeConstraints({ (make) in
                        make.width.equalTo(stateManager.lineThicknes)
                        make.centerX.equalTo(childWidget.dragDot)
                        make.bottom.equalTo((previous?.dragDot.snp.top)!).offset(-5.0)
                        make.top.equalTo(childWidget.dragDot.snp.bottom).offset(5.0)
                    })
                }

                childWidget.layoutText()
                
                previous = childWidget
            }
        }
    }


    func layoutDecorations() {
        if widgetZone.children.count != 0 && !subviews.contains(childVisibilityDot) {
            addSubview(childVisibilityDot)
            childVisibilityDot.setUp(asToggle: true)

            childVisibilityDot.snp.makeConstraints({ (make) in
                make.left.equalTo(textField.snp.right).offset(6.0)
                make.centerY.equalTo(textField).offset(-1.0)
                make.right.lessThanOrEqualToSuperview().offset(-3.0)
            })
        }

        if widgetZone != modelManager.rootZone && !subviews.contains(dragDot) {
            addSubview(dragDot)
            dragDot.setUp(asToggle: false)

            dragDot.snp.makeConstraints({ (make) in
                make.right.equalTo(textField.snp.left).offset(-3.0)
                make.centerY.equalTo(textField).offset(1.0)
            })
        }
    }


    // MARK:- delegates
    // MARK:-


    func captureText() {
        modelManager.currentlyEditingZone = nil
        widgetZone.zoneName               = textField.text!
    }


    func selectForEditing() {
        modelManager.currentlyEditingZone = widgetZone
    }


#if os(OSX)

    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        captureText()

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


//    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
//        updateLayout()
//        selectForEditing()
//
//        return true
//    }

#endif
}
