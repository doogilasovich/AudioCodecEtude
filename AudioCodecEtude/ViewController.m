//
//  ViewController.m
//  AudioCodecEtude
//
//  Created by Doug Mccoy on 4/13/18.
//  Copyright © 2018 Doug Mccoy. All rights reserved.
//

#import "ViewController.h"
@import AVFoundation;
@import DLMCore;
#import "CustomCodecResourceLoaderDelegate.h"


@interface ViewController ()
{
    CustomCodecResourceLoaderDelegate *loaderDelegate;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    

    
    // set up url resource
//    let audioURL = [[NSBundle mainBundle] URLForResource:@"sample" withExtension:@"m4a"];
    let audioURL = [NSURL URLWithString:@"https://github.com/robovm/apple-ios-samples/raw/master/avTouch/sample.m4a"];
//    let audioURL = [NSURL URLWithString:@"https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"];
//    let audioURL = [NSURL URLWithString:@"https://github.com/mediaelement/mediaelement-files/raw/master/AirReview-Landmarks-02-ChasingCorporate.mp3"];
//    let audioURL = [NSURL URLWithString:@"http://localhost/SampleAudio_0.7mb.mp3"];
//    let audioURL = [NSURL URLWithString:@"http://10.0.1.10/SampleAudio_0.7mb.mp3"];

    

//    setenv("CFNETWORK_DIAGNOSTICS", "3", 1);

    
    // need this to do some operations below
    loaderDelegate = [CustomCodecResourceLoaderDelegate new];

    // modify url scheme so loader delegate can handle it
    let modifiedURL = [loaderDelegate redirectURL:audioURL];
    
    let assset = [AVURLAsset assetWithURL:modifiedURL];
    
    [assset.resourceLoader setDelegate:loaderDelegate queue:loaderDelegate.loaderQueue];
    
    let item = [AVPlayerItem playerItemWithAsset:assset];
    
    player = [AVPlayer playerWithPlayerItem:item];
    
    [player play];
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
