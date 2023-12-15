//
//  InstrumentsXPC.m
//  InstrumentsXPC
//
//  Created by 任玉乾 on 2023/12/7.
//

#import "InstrumentsXPC.h"

@implementation InstrumentsXPC

// This implements the example protocol. Replace the body of this class with the implementation of this service's protocol.
- (void)performCalculationWithNumber:(NSNumber *)firstNumber 
                           andNumber:(NSNumber *)secondNumber
                           withReply:(void (^)(NSNumber *))reply {
    NSInteger result = firstNumber.integerValue + secondNumber.integerValue;
    reply(@(result));
}

@end
