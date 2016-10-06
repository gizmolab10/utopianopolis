//
//  XBClosures.h
//  XIMBLE
//
//  Created by Jonathan Sand on 3/9/16.
//  Copyright © 2016 Xicato. All rights reserved.
//


import Foundation;
import CloudKit


public typealias Closure                 = ()         -> (Void)
public typealias ObjectClosure           = (NSObject) -> (Void)
public typealias RecordClosure           = (CKRecord) -> (Void)
public typealias BooleanClosure          = (ObjCBool) -> (Void)
public typealias TimerClosure            = (Timer)    -> (ObjCBool)
public typealias ClosureClosure          = (Closure)  -> (Void)
public typealias IntegerClosure          = (UInt)     -> (Void)
public typealias ObjectToObjectClosure   = (NSObject) -> (NSObject)
public typealias BooleanToBooleanClosure = (ObjCBool) -> (ObjCBool)
public typealias ObjectToStringClosure   = (NSObject) -> (String)
