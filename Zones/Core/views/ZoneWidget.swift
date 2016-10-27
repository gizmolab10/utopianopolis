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


private let widgetFont: ZFont = ZFont.userFont(ofSize: 17.0)!


class ZoneWidget: ZView, ZTextFieldDelegate, ZoneTextFieldDelegate {


    private var    _textField: ZoneTextField!
    var            widgetZone: Zone!
    private var _childrenView: ZView!
    var       childrenWidgets: [ZoneWidget] = []


    var hasChildren: Bool {
        get { return widgetZone.children.count > 0 }
    }


    var textField: ZoneTextField {
        get {
            if _textField == nil {
                _textField                      = ZoneTextField()
                _textField.font                 = widgetFont
                _textField.delegate             = self
                _textField.alignment            = .center
                _textField.bezelStyle           = .roundedBezel
                _textField.isBordered           = false
                _textField.zoneDelegate         = self
                _textField.backgroundColor      = NSColor(cgColor: CGColor.white)
                _textField.maximumNumberOfLines = 1

                addSubview(_textField)

                _textField.snp.makeConstraints { (make) -> Void in
                    make.width.equalTo(200.0)
                }

                snp.makeConstraints { (make) -> Void in
                    make.centerY.left.equalTo(_textField)
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


    func updateChildrensView() {
        var                 index = widgetZone.children.count
        var previous: ZoneWidget? = nil

        for view in childrenView.subviews {
            view.removeFromSuperview()
        }

        childrenView.removeFromSuperview()

        _childrenView = nil

        childrenWidgets.removeAll()

        while childrenWidgets.count != index {
            childrenWidgets.append(ZoneWidget())
        }

        while index > 0 {
            index                 -= 1
            let childWidget        = childrenWidgets[index]
            childWidget.widgetZone = widgetZone.children[index]

            childWidget.updateInView(childrenView, atIndex: index)
            childWidget.snp.makeConstraints({ (make) in
                if let widget = previous {
                    make.bottom.equalTo(widget.snp.top).offset(-stateManager.genericOffset.height)
                } else {
                    make.bottom.equalTo(childrenView)
                }

                if index == 0 {
                    make.top.equalTo(childrenView)
                }

                make.left.equalTo(childrenView)
                make.right.height.lessThanOrEqualTo(childrenView)
            })

            childWidget.layoutForText()
            
            previous = childWidget
        }

        if modelManager.selectedZone == widgetZone {
            textField.becomeFirstResponder()
        }
    }


    func updateInView(_ inView: ZView, atIndex: Int) {
        if !inView.subviews.contains(self) {
            inView.addSubview(self)

            if atIndex == -1 {
                snp.remakeConstraints { (make) -> Void in
                    make.center.equalTo(inView)
                }
            }
        }

        updateChildrensView()
        layoutForText()
    }


    func layoutForText() {
        textField.text = widgetZone.zoneName ?? "empty"

        updateLayout()
    }


    func updateLayout() {
        textField.snp.removeConstraints()
        textField.snp.makeConstraints { (make) -> Void in
            let width = textField.text!.widthForFont(widgetFont) + 10.0

            make.width.equalTo(width)
            make.centerY.left.equalTo(self)

            if hasChildren {
                make.right.equalTo(childrenView.snp.left).offset(-stateManager.genericOffset.width)
            }
        }

        updateConstraints()
        textField   .addBorder(thickness: 5.0, fractionalRadius: 0.5, color: CGColor.black)
        childrenView.addBorder(thickness: 1.0, fractionalRadius: 0.5, color: CGColor.black)
    }


    func captureText() {
        modelManager.selectedZone = nil
        widgetZone.zoneName       = textField.text!
    }


    // MARK:- delegates
    // MARK:-


    func select() {
        modelManager.selectedZone = widgetZone
    }


#if os(OSX)

    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        captureText()

        return true
    }
    

    override func controlTextDidChange(_ obj: Notification) {
        updateLayout()
        select()
    }

#elseif os(iOS)

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        captureText()

        return true
    }


//    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
//        updateLayout()
//        select()
//
//        return true
//    }

#endif
}
