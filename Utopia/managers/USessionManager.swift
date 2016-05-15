//
//  USessionManager.swift
//  Utopia
//
//  Created by Jonathan Sand on 5/12/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation


public class USessionManager: NSObject, NSURLSessionDelegate {
    public static let sharedSessionManager = USessionManager();

    let networkObservers = NSMutableArray();
    let         sessions = NSMutableSet()
    let          baseURL = "https://utopianopolis.org"

    public func callDatabase () -> Void {
        let  url = urlWithPath("/cgi-bin/tryout.py")
        let data = NSData.init();

        sendData(data, url: url, headers: nil, method: "GET")
    }


    func urlWithPath (relativePath: String) -> NSURL {
        let urlString = "\(baseURL)\(relativePath)"

        return NSURL(string: urlString)!
    }


    func sendData(data : NSData, url: NSURL, headers: NSDictionary?, method: String?) -> Void {
        let        request = NSMutableURLRequest.init(URL: url, cachePolicy: NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData, timeoutInterval: 60.0)
        request.HTTPMethod = method ?? "POST"
        request.HTTPBody   = data

        performRequest(request)
    }

    func performRequest(request: NSURLRequest) -> Void {
        let  config = NSURLSessionConfiguration.defaultSessionConfiguration
        let session = NSURLSession.init(configuration: config(), delegate: self, delegateQueue: NSOperationQueue.currentQueue())
        let    task = session.dataTaskWithRequest(request, completionHandler: performResponse)

        task.resume();
    }

    func performResponse(data: NSData?, response: NSURLResponse?, error: NSError?) -> Void {
        if error != nil {
            print(error)
        } else if response != nil {
            print(response)
        }
    }
}


/*

- (void)sendJSON:(id)jsonObj toURL:(NSURL *)iURL withHeaders:(NSMutableDictionary *)iHeaders usingMethod:(NSString *)iMethod option:(SyncOption)iOption onSignal:(SessionClosure)iSignal {
    NSError   *error = nil;
    NSData *jsonData = jsonObj == nil ? nil : [NSJSONSerialization dataWithJSONObject:jsonObj options:0 error:&error];
    
    DDLogDebug(@"json data: %@", jsonObj);
    
    if (error == nil) {
        if (iHeaders == nil) {
            iHeaders = [NSMutableDictionary new];
        }
        
        [iHeaders setObject:@"application/json" forKey:@"Content-Type"];
        
        [self sendData:jsonData toURL:iURL withHeaders:iHeaders usingMethod:iMethod option:iOption onSignal:iSignal];
    } else if (iSignal) {
        iSignal(kSignalTypeAlert, kErrorCodeUnrecognizedFormat, error.debugDescription);
    }
}


typedef void (^ResponseClosure)(id iObject, NSURLResponse *response, NSError *error);


- (void)sendData:(NSData *)iData toURL:(NSURL *)iURL withHeaders:(NSDictionary *)iHeaders usingMethod:(NSString *)iMethod option:(SyncOption)iOption onSignal:(SessionClosure)iSignal {
    __block ErrorCode         code = kErrorCodeSuccess;

    DDLogDebug(@"url: %@\n%@", iURL, iHeaders);
    
    [self fire:kSignalTypeSetup errorCode:code object:nil withSignal:iSignal];
    
    [self dispatchInBackground:^{
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:iURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60.0];
        request.HTTPMethod           = iMethod == nil ? @"POST" : iMethod;
        request.HTTPBody             = iData;

        [iHeaders enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            [request addValue:iHeaders[key] forHTTPHeaderField:key];
        }];

        [self performRequest:request option:iOption onSignal:iSignal];
    }];
}


- (void)performRequest:(NSURLRequest *)iRequest option:(SyncOption)iOption onSignal:(SessionClosure)iSignal {
    NSOperationQueue           *queue = [NSOperationQueue mainQueue];
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession             *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:queue];
    NSDate                     *start = [NSDate new];
    __block NSURLSessionTask    *task = nil;

    @synchronized(self.sessions) {
        [self.sessions addObject:session];
    }

    weakify(self)
    weakify(session)

    ResponseClosure responder = ^(id iObject, NSURLResponse *iResponse, NSError *iError) {
        [self dispatchInBackground:^{
            strongify(session)
            strongify(self)
            NSHTTPURLResponse    *response = (NSHTTPURLResponse *)iResponse;
            NSString               *status = [NSHTTPURLResponse localizedStringForStatusCode:response.statusCode];
            NSString                  *url = response.URL.absoluteString ?: iError.userInfo[@"NSErrorFailingURLStringKey"];
            id                      result = [NSString stringWithFormat:@"%@ at %@", status, url];
            NSTimeInterval duration IGNORE = [[NSDate new] timeIntervalSinceDate:start];
            SignalType                type = kSignalTypeSuccess;
            ErrorCode                 code = kErrorCodeSuccess;

            DDLogDebug(@"api call took %f seconds to pull %lu bytes of data from %@", duration, (unsigned long)iRequest.HTTPBody.length, iRequest.URL);

            if (iError == nil && response.statusCode == 200) {
                NSMutableDictionary  *dict = [self tweakErrorKey:[iObject JSONDictionary]];
                result                     = dict;

                if (dict == nil) {
                    type   = kSignalTypeAlert;
                    result = [NSString stringWithFormat:@"cannot parse response from server at %@", iRequest.URL];
                } else if (![strongself successfulData:dict]) {
                    code   = (ErrorCode)[dict[@"code"] integerValue];
                    type   = kSignalTypeAlert;
                }
            } else if (response) {
                code       = kErrorCodeInternalServerError;
                type       = kSignalTypeAlert;

                DDLogWarn(@"bad status \"%ld, %@\" from server at %@", (long)response.statusCode, status, iRequest.URL);
            } else {
                if (iError) {
                    result = [NSString stringWithFormat:@"Error (%@) after %f seconds from server at %@", iError, duration, iRequest.URL];
                } else {
                    result = [NSString stringWithFormat:@"No response after %f seconds from server at %@", duration, iRequest.URL];
                }

                code       = kErrorCodeServerUnavailable;
                type       = kSignalTypeIsolated;

                if (iOption == kSyncOptionGuaranteed) {
                    [self deferRequest:iRequest];
                }

                DDLogWarn(result);
            }

            [strongself fire:type errorCode:code object:result withSignal:iSignal];

            if (strongsession) {
                [strongsession invalidateAndCancel];

                @synchronized(strongself.sessions) {
                    [strongself.sessions removeObject:strongsession];
                }
            }
        }];
    };

#ifndef kDebugGunzip
    task     = [session     dataTaskWithRequest:iRequest completionHandler:responder];
#else
    if (iOption == kSyncOptionBlob) {
        task = [session downloadTaskWithRequest:iRequest completionHandler:responder];
    } else {
        task = [session     dataTaskWithRequest:iRequest completionHandler:responder];
    }
#endif

    DDLogDebug(@"%s starting request for %@", __FILE__, [iRequest.URL absoluteString]);

    // Session priority is not available starting in iOS 9
#ifndef __IPHONE_9_0
    task.priority = NSURLSessionTaskPriorityHigh;
#endif

    [task resume];
}


*/
