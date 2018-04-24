//
//  CustomCodecResourceLoaderDelegate.m
//  AudioCodecEtude
//
//  Created by Doug Mccoy on 4/13/18.
//  Copyright © 2018 Doug Mccoy. All rights reserved.
//

// based on http://blog.jaredsinclair.com/post/149892449150/implementing-avassetresourceloaderdelegate-a

#import "CustomCodecResourceLoaderDelegate.h"
@import AVFoundation;
@import DLMCore;

#pragma mark PassThroughDelegate

@interface PassThroughDataDelegate : NSObject <NSURLSessionDataDelegate>
{
    AVAssetResourceLoadingRequest *loadingRequest;
}
@end

@implementation PassThroughDataDelegate

-(void)dealloc
{
    NSLog(@"PassThroughDataDelegate (%p) dealloc", self);
}

-(instancetype)initWithLoadingRequest:(AVAssetResourceLoadingRequest *)request
{
    if (self = [super init])
    {
        loadingRequest = request;
    }
    return self;
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    
    // do some setup
    
    completionHandler(NSURLSessionResponseAllow);
}

-(void)URLSession:(NSURLSession *)session
         dataTask:(NSURLSessionDataTask *)dataTask
   didReceiveData:(NSData *)data
{
    
    // handle the data
    NSLog(@"handling %lu bytes of data", (unsigned long)data.length);
    [loadingRequest.dataRequest respondWithData:data];
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        [loadingRequest finishLoadingWithError:error];
        NSLog(@"loading Request finished with error: %@", error);

    }
    else {
        [loadingRequest finishLoading];
        NSLog(@"loading Request finished normally");

    }
    
}

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(nonnull NSURLAuthenticationChallenge *)challenge completionHandler:(nonnull void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler{
    NSLog(@"URLSession didReceiveChallenge");
    
    completionHandler(NSURLSessionAuthChallengeUseCredential, nil);
    return;
    
}



- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(nullable NSError *)error
{
    NSLog(@"%@", error);
}

@end




#pragma mark CustomCodecResourceLoaderDelegate

@interface CustomCodecResourceLoaderDelegate()
{
    dispatch_queue_t loaderQueue;
}
@end

@implementation CustomCodecResourceLoaderDelegate

-(void)dealloc
{
}

-(NSString*)schemePrefix{
    return @"CC-";
}

-(NSString*)redirectScheme:(NSString*)originalScheme
{
    return [self.schemePrefix stringByAppendingString: originalScheme];
}

-(NSString*)originalScheme:(NSString*)redirectScheme
{
    let prefixToRemove = [self schemePrefix];
    var originalScheme = [NSString new];
    if ([redirectScheme hasPrefix:prefixToRemove])
        originalScheme = [redirectScheme substringFromIndex:[prefixToRemove length]];
    return originalScheme;
}

-(NSURL*)redirectURL:(NSURL*)originalURL
{
    // modify url scheme so loader delegate can handle it
    let components = [NSURLComponents componentsWithURL:originalURL resolvingAgainstBaseURL:YES];
    components.scheme = [self redirectScheme:components.scheme];
    return components.URL;
}

-(NSURL*)originalURL:(NSURL*)redirectURL
{
    // un-modify url scheme so we can access real resource
    let components = [NSURLComponents componentsWithURL:redirectURL resolvingAgainstBaseURL:YES];
    components.scheme = [self originalScheme:components.scheme];
    return components.URL;
}



-(dispatch_queue_t)loaderQueue
{
    if (!loaderQueue) {
        // set up custom loader delegate
        let queueName = [NSString stringWithFormat:@"%@ loader queue (%@)", self.class, self].UTF8String;
        loaderQueue = dispatch_queue_create(queueName, DISPATCH_QUEUE_SERIAL);
    }
    return loaderQueue;
}


-(BOOL)handleInfoRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    let infoRequest = loadingRequest.contentInformationRequest;
    let dataRequest = loadingRequest.dataRequest;
    
    if (infoRequest)
    {
        NSLog(@"contentInformationRequest present");
        let redirectURL = loadingRequest.request.URL;
        let originalURL = [self originalURL:redirectURL];
        
        let request = [NSMutableURLRequest requestWithURL:originalURL];
        let session = [NSURLSession sharedSession];
        
        if (dataRequest)
        {
            let lower = dataRequest.requestedOffset;
            let upper = lower + dataRequest.requestedLength - 1;
            let rangeHeader = [NSString stringWithFormat:@"bytes=%lli-%lli", lower, upper];
            NSLog(@"Range:   %@", rangeHeader);

            [request setValue:rangeHeader forHTTPHeaderField:@"Range"];
        }
        
        NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
                                          {
                                              if (error) {
                                                  [loadingRequest finishLoadingWithError:error];
                                              }
                                              else
                                              {
                                                  let infoRequest = loadingRequest.contentInformationRequest;
                                                  infoRequest.contentType = response.MIMEType;
                                                  infoRequest.contentLength = response.expectedContentLength;
                                                  if ([response isKindOfClass:[NSHTTPURLResponse class]])
                                                  {
                                                      let httpResponse = (NSHTTPURLResponse*)response;
                                                      let contentInfo = httpResponse.allHeaderFields;
                                                      let contentRange = (NSString*)[contentInfo valueForKey:@"Content-Range"];
                                                      let contentSize = [contentRange componentsSeparatedByString:@"/"].lastObject;
                                                      infoRequest.contentLength = contentSize.integerValue;;
  }
                                                  infoRequest.byteRangeAccessSupported = YES;
                                                  
                                                  NSLog(@"contentType:   %@", infoRequest.contentType);
                                                  NSLog(@"contentLength: %lli", infoRequest.contentLength);

                                                  [loadingRequest finishLoading];
                                              }
                                              
                                          }];
        [dataTask resume];
    }
    
    
    return YES;
}

-(BOOL)handleDataRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    NSLog(@"dataRequest present");
    
    let dataRequest = loadingRequest.dataRequest;
    if (dataRequest.requestsAllDataToEndOfResource) {
        // It’s requesting the entire file, assuming
        // that dataRequest.requestedOffset is 0
        NSLog(@"requestsAllDataToEndOfResource = YES");

    }
    
    if (dataRequest.requestedLength <= 2) {
        NSLog(@"requestedLength = %ld", (long)dataRequest.requestedLength);
//        return YES;
    }
    
    let redirectURL = loadingRequest.request.URL;
    let originalURL = [self originalURL:redirectURL];
    
    let request = [NSMutableURLRequest requestWithURL:originalURL];
    
    let operationQueue = [[NSOperationQueue alloc] init];
    operationQueue.maxConcurrentOperationCount = 1;
    let processingDelegate = [PassThroughDataDelegate.alloc initWithLoadingRequest:loadingRequest];
    let session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                delegate:processingDelegate
                                           delegateQueue:operationQueue
                   ];
    
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:nil];
    
    [dataTask resume];


    return YES;
}


-(BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest
{
    NSLog(@"shouldWaitForLoadingOfRequestedResource: called");
    

    if (loadingRequest.contentInformationRequest)
        return [self handleInfoRequest:loadingRequest];
    else if (loadingRequest.dataRequest)
        return [self handleDataRequest:loadingRequest];
    else
        return NO;
}

-(void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(nonnull AVAssetResourceLoadingRequest *)loadingRequest
{
    NSLog(@"didCancelLoadingRequest: called");

    
}

@end







