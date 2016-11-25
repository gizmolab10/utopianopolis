//
//  ZState.swift
//  Zones
//
//  Created by Jonathan Sand on 10/14/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation


var   textCapturing:      Bool = false
var        editMode: ZEditMode = .task
var   genericOffset:    CGSize = CGSize(width: 0.0, height: 4.0)
var       lineColor:    ZColor = ZColor.purple //(hue: 0.6, saturation: 0.6, brightness: 1.0,                alpha: 1)
var unselectedColor:    ZColor = ZColor(hue: 0.6, saturation: 0.0, brightness: unselectBrightness, alpha: 1)
var    lineThicknes:   CGFloat = 1.25
var       dotLength:   CGFloat = 12.0


var lightFillColor: ZColor { get { return lineColor.withAlphaComponent(0.03) } }
