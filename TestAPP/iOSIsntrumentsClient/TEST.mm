//
//  TEST.m
//  cccc
//
//  Created by 任玉乾 on 2022/11/16.
//

#import "TEST.h"

#include "ios_instruments_client.h"

@implementation TEST

+ (void)testWithC:(NSInteger)c andArgv:(NSArray<NSString *> *)argv {
    
    const char ** list = (const char **)malloc(sizeof(char *) * c);
    
    for (int i = 0; i < c; i++) {
        list[i] = [argv[i] cStringUsingEncoding:NSUTF8StringEncoding];
    }
    
    test(int(c), list);
    free(list);
    
}

@end
