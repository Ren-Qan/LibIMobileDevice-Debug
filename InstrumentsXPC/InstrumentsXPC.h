//
//  InstrumentsXPC.h
//  InstrumentsXPC
//
//  Created by 任玉乾 on 2023/12/7.
//

#import <Foundation/Foundation.h>
#import "InstrumentsXPCProtocol.h"

// This object implements the protocol which we have defined. It provides the actual behavior for the service. It is 'exported' by the service to make it available to the process hosting the service over an NSXPCConnection.
@interface InstrumentsXPC : NSObject <InstrumentsXPCProtocol>
@end
