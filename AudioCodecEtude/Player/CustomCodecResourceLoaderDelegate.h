//
//  CustomCodecResourceLoaderDelegate.h
//  AudioCodecEtude
//
//  Created by Doug Mccoy on 4/13/18.
//  Copyright © 2018 Doug Mccoy. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AVFoundation;

@interface CustomCodecResourceLoaderDelegate : NSObject <AVAssetResourceLoaderDelegate>

-(NSString*)schemePrefix;
-(NSURL*)redirectURL:(NSURL*)originalURL;
-(dispatch_queue_t)loaderQueue;

@end
