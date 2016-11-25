//
//  XBClosures.h
//  XIMBLE
//
//  Created by Jonathan Sand on 3/9/16.
//  Copyright © 2016 Xicato. All rights reserved.
//


import Foundation;
import CloudKit


typealias Closure                 = ()          -> (Void)
typealias TimerClosure            = (Timer)     -> (ObjCBool)
typealias ObjectClosure           = (NSObject)  -> (Void)
typealias RecordClosure           = (CKRecord?) -> (Void)
typealias BooleanClosure          = (ObjCBool)  -> (Void)
typealias ClosureClosure          = (Closure)   -> (Void)
typealias IntegerClosure          = (UInt)      -> (Void)
typealias ToObjectClosure         = (Void)      -> (NSObject)
typealias ObjectToObjectClosure   = (NSObject)  -> (NSObject)
typealias BooleanToBooleanClosure = (ObjCBool)  -> (ObjCBool)
typealias ObjectToStringClosure   = (NSObject)  -> (String)
typealias SignalClosure           = (Any?, ZUpdateKind) -> (Void)
