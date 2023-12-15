//
//  InstrumentsXPCProtocol.h
//  InstrumentsXPC
//
//  Created by 任玉乾 on 2023/12/7.
//

#import <Foundation/Foundation.h>

// The protocol that this service will vend as its API. This header file will also need to be visible to the process hosting the service.
@protocol InstrumentsXPCProtocol

// Replace the API of this protocol with an API appropriate to the service you are vending.
- (void)performCalculationWithNumber:(NSNumber *)firstNumber andNumber:(NSNumber *)secondNumber withReply:(void (^)(NSNumber *))reply;
@end

/*
 To use the service from an application or other process, use NSXPCConnection to establish a connection to the service by doing something like this:

     _connectionToService = [[NSXPCConnection alloc] initWithServiceName:@"S.r.InstrumentsXPC"];
     _connectionToService.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(InstrumentsXPCProtocol)];
     [_connectionToService resume];

Once you have a connection to the service, you can use it like this:

     [[_connectionToService remoteObjectProxy] performCalculationWithNumber:@23 andNumber:@19 withReply:^(NSNumber *reply) {
         // We have received a response.
         NSLog(@"Result from calculation is: %@", reply);
     }];

 And, when you are finished with the service, clean up the connection like this:

     [_connectionToService invalidate];
*/
