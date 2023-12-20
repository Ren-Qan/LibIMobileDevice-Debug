//
//  DVTSrvice.m
//  T17
//
//  Created by 任玉乾 on 2023/12/19.
//

#import "DVTSrvice.h"


@interface DVTSrvice() <NSNetServiceBrowserDelegate>

@property (nonatomic, strong) NSNetServiceBrowser *browser;

@end

@implementation DVTSrvice

- (NSNetServiceBrowser *)browser {
    if (!_browser) {
        _browser = [NSNetServiceBrowser.alloc init];
        _browser.delegate = self;
    }
    return _browser;
}

@end
