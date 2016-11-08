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


class ZoneWidget: ZView, ZTextFieldDelegate {


    private var        _textField: ZoneTextField!
    var                widgetZone: Zone!
    private var     _childrenView: ZView!
    private var dragHighlightView: ZView!
    private var   childrenWidgets: [ZoneWidget] = []
    private var      siblingLines: [ZoneCurve]  = []
    var                 toggleDot: ZoneDot      = ZoneDot()
    var                   dragDot: ZoneDot      = ZoneDot()


    var hasChildren: Bool {
        get { return widgetZone.children.count > 0 }
    }


    var textField: ZoneTextField {
        get {
            if _textField == nil {
                _textField            = ZoneTextField()
                _textField.widgetZone = widgetZone
                _textField.delegate   = self

                _textField.setup()
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
                _childrenView.isUserInteractionEnabled = false // does nothing in os x

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


    func layoutInView(_ inView: ZView?, atIndex: Int) {
        if inView != nil && !(inView?.subviews.contains(self))! {
            inView?.addSubview(self)

            if atIndex == -1 {
                snp.remakeConstraints { (make) -> Void in
                    make.center.equalTo(inView!)
                }
            }
        }

        inView?.zlayer.backgroundColor = ZColor.clear.cgColor
        isUserInteractionEnabled      = false

        clear()
        zonesManager.registerWidget(self)
        layoutChildren()
        layoutLines()
        layoutText()
        layoutDots()
        layoutDragHighlight()
    }


    func layoutFinish() {
        layoutDecorations()

        for widget in childrenWidgets {
            widget.layoutFinish()
        }
    }


    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        DispatchQueue.main.async {
            if self.dragHighlightView != nil {
                self.dragHighlightView.zlayer.backgroundColor = stateManager.lightFillColor.cgColor

                self.dragHighlightView.addBorderRelative(thickness: 0.15, radius: 0.5, color: stateManager.lineColor.cgColor)
            }
        }
    }


    func layoutDecorations() {
        // self        .addBorderRelative(thickness: 1.0, radius: 0.5, color: ZColor.green.cgColor)
        // childrenView.addBorderRelative(thickness: 1.0, radius: 0.5, color: ZColor.orange.cgColor)
        // textField.addBorder(thickness: 5.0, radius: 0.5, color: CGColor.black)
    }


    func layoutDragHighlight() {
        if  dragHighlightView == nil && zonesManager.isGrabbed(zone: widgetZone) {
            dragHighlightView                          = ZView()
            dragHighlightView.isUserInteractionEnabled = false

            addSubview(dragHighlightView)
            dragHighlightView.snp.makeConstraints({ (make) in
                make.top.bottom.equalTo(self)
                make.right.equalTo(self).offset(-8.0)
                make.left.equalTo(self).offset(8.0)
            })
        }
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
                make.right.equalTo(childrenView.snp.left).offset(-20.0)
            }
        }
    }


    func layoutChildren() {
        var previous: ZoneWidget? = nil
        var                 index = widgetZone.children.count

        if _childrenView != nil {
            for view in _childrenView.subviews {
                view.removeFromSuperview()
            }

            _childrenView.removeFromSuperview()

            _childrenView = nil
        }

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

                    make.left.equalTo(childrenView)//.offset(20.0)
                    make.right.height.lessThanOrEqualTo(childrenView)
                })

                childWidget.layoutText()

                previous = childWidget
            }
        }
    }


    func layoutLines() {
        for line in siblingLines {
            line.removeFromSuperview()
        }

        siblingLines.removeAll()

        if widgetZone.showChildren {
            var index = widgetZone.children.count
            var siblingLine: ZoneCurve?

            while index > 0 {
                index              -= 1
                let childWidget     = childrenWidgets[index]
                siblingLine         = ZoneCurve()
                siblingLine?.child  = childWidget
                siblingLine?.parent = self

                siblingLines.append(siblingLine!)
                addSubview(siblingLine!)
                siblingLine?.snp.makeConstraints({ (make) in
                    make.width.height.equalTo(stateManager.lineThicknes)
                    make.centerX.equalTo(textField.snp.right).offset(6.0)
                    make.centerY.equalTo(textField)
                })
            }
        }
    }


    func layoutDots() {
        if widgetZone.children.count != 0 {
            if !subviews.contains(toggleDot) {
                addSubview(toggleDot)
            }

            toggleDot.innerDot?.snp.removeConstraints()
            toggleDot.setupForZone(widgetZone, asToggle: true)
            toggleDot.innerDot?.snp.makeConstraints({ (make) in
                make.left.equalTo(textField.snp.right).offset(-1.0)
                make.centerY.equalTo(textField).offset(1.0)
                make.right.lessThanOrEqualToSuperview().offset(-1.0)
            })
        }

        if widgetZone != zonesManager.rootZone {
            if !subviews.contains(dragDot) {
                addSubview(dragDot)
            }

            dragDot.innerDot?.snp.removeConstraints()
            dragDot.setupForZone(widgetZone, asToggle: false)
            dragDot.innerDot?.snp.makeConstraints({ (make) in
                make.right.equalTo(textField.snp.left)
                make.centerY.equalTo(textField).offset(1.0)
            })
        }
    }


    // MARK:- delegates
    // MARK:-


    func captureText() {
        if  stateManager.textCapturing    == false {
            if widgetZone.zoneName        != textField.text! {
                stateManager.textCapturing = true
                widgetZone.zoneName        = textField.text!
            }
//
//            zonesManager.deselect()
        }
    }

    func stopEditingRecursively() {
        stopEditing()

        for child in childrenWidgets {
            child.stopEditingRecursively()
        }
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
//        zonesManager.currentlyEditingZone = widgetZone
//
//        return true
//    }

#endif
}
