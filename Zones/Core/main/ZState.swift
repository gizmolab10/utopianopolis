//
//  ZState.swift
//  Zones
//
//  Created by Jonathan Sand on 10/14/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


enum ZEditMode: Int {
    case task
    case essay
}


enum ZFileMode: Int {
    case local
    case cloud
}


enum ZWorkMode: Int {
    case searchMode
    case essayMode
    case editMode
}


var recursivelyExpand = false
var    showsSearching = false
var     textCapturing = false
var          editMode = ZEditMode.task
var          fileMode = ZFileMode.cloud
var          workMode = ZWorkMode.editMode
var     genericOffset = CGSize(width: 0.0, height: 4.0)
var         lineColor = ZColor.purple //(hue: 0.6, saturation: 0.6, brightness: 1.0,                alpha: 1)
var     bookmarkColor = ZColor.blue
var   unselectedColor = ZColor(hue: 0.6, saturation: 0.0, brightness: unselectBrightness, alpha: 1)
var      lineThicknes = 1.25
var         dotHeight = 12.0


var               asTask:   Bool { get { return editMode == .task             } }
var grabbedBookmarkColor: ZColor { get { return bookmarkColor.darker(by: 1.5) } }
var     grabbedTextColor: ZColor { get { return lineColor    .darker(by: 1.8) } }
