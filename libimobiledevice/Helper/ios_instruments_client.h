#ifndef IOS_INSTRUMENTS_CLIENT
#define IOS_INSTRUMENTS_CLIENT

#include "cftypes.hpp"
//#include "libimobiledevice/libimobiledevice.h"
//#include "include/libimobiledevice/libimobiledevice.h"
#include <libimobiledevice/libimobiledevice.h>

//-----------------------------------------------------------------------------
struct DTXMessageHeader
{
    uint32_t magic;
    uint32_t cb;
    uint16_t fragmentId;
    uint16_t fragmentCount;
    uint32_t length;
    uint32_t identifier;
    uint32_t conversationIndex;
    uint32_t channelCode;
    uint32_t expectsReply;
};

//-----------------------------------------------------------------------------
struct DTXMessagePayloadHeader
{
    uint32_t flags;
    uint32_t auxiliaryLength;
    uint64_t totalLength;
};

//------------------------------------------------------------------------------
// helper class for serializing method arguments
class message_aux_t
{
    bytevec_t buf;
    
public:
    void append_int(int32_t val);
    void append_long(int64_t val);
    void append_obj(CFTypeRef _Nullable obj);
    
    void get_bytes(bytevec_t * _Nullable out) const;
};


bool test(idevice_connection_t _Nullable conn);

#endif // IOS_INSTRUMENTS_CLIENT


//instruments连接建立之后，传输的消息为 DTXMessage
//DTXMessage = (DTXMessageHeader + DTXPayload)

//- DTXMessageHeader 主要用来对数据进行封包传输，以及说明是否需要应答
//DTXPayload = (DTXPayloadHeader + DTXPayloadBody)

//- DTXPayloadHeader 中的flags字段规定了 DTXPayloadBody 的数据类型
//- DTXPayloadBody 可以是任何数据类型 (None, (None, None), List) 都有可能

//        前32个字节(两行) 为DTXMessage的头部 (包含了消息的类型和请求的channel)
//        后面是携带的payload
//        Returns:
//            DTXMessageHeader, payload
//
//        Raises:
//            MuxError
//        Returns:
//            retobj  contains the return value for the method invoked by send_message()
//            aux     usually empty, except in specific situations (see _notifyOfPublishedCapabilities)
//
//        # Refs: https://github.com/troybowman/dtxmsg/blob/master/dtxmsg_client.cpp
//        数据解析说明
//        >> 全部数据
//        00000000: 79 5B 3D 1F 20 00 00 00  00 00 01 00 2C 1C 00 00  y[=. .......,...
//        00000010: 02 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  ................
//        00000020: 02 00 00 00 71 1B 00 00  1C 1C 00 00 00 00 00 00  ....q...........
//        00000030: F0 1B 00 00 00 00 00 00  61 1B 00 00 00 00 00 00  ........a.......
//        00000040: 0A 00 00 00 02 00 00 00  55 1B 00 00 62 70 6C 69  ........U...bpli
//        00000050: 73 74 30 30 D4 00 01 00  02 00 03 00 04 00 05 00  st00............
//        00000060: 06 01 2F 01 30 58 24 76  65 72 73 69 6F 6E 58 24  ../.0X$versionX$
//        00000070: 6F 62 6A 65 63 74 73 59
//        >> 前32个字节
//        00000000: 79 5B 3D 1F 20 00 00 00  00 00 01 00 2C 1C 00 00  y[=. .......,...
//        00000010: 02 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00
//        \\\\
//        struct DTXMessageHeader {
//            u32 magic  # 79 5B 3D 1F
//            u32 cb # 20 00 00 00      # sizeof(DTXMessageHeader)
//            u16 fragmentId # 00 00
//            u16 fragmentCount # 01 00
//            u32 length # 2C 1C 00 00  # 不包括MessageHeader自身的长度
//            u32 messageId # 02 00 00 00
//            u32 conversationIndex # 00 00 00 00 # 1 indicate a reply message
//            u32 channelCode # 00 00 00 00
//            u32 expectReply # 00 00 00 00    # 1 or 0
//        }
//
//        00000020: 02 00 00 00 71 1B 00 00  1C 1C 00 00 00 00 00 00
//        \\\\
//        # 紧跟在MessageHeader的后面
//        struct payloadHeader {
//            u32 flags # 02 00 00 00 # 02(包含两个值), 00(empty), 01,03,04(只有一个值)
//            u32 auxiliaryLength # 71 1B 00 00
//            u64 totalLength # 1C 1C 00 00 00 00 00 00
//        }
//
//        >> Body 部分
//        00000030: F0 1B 00 00 00 00 00 00  61 1B 00 00 00 00 00 00  ........a.......
//        \\\\
//        # 前面8个字节 0X1BF0 据说是Magic word
//        # 后面的 0x1B61 是整个序列化数据的长度
//        # 解析的时候可以直接跳过这部分
//        # 序列化的数据部分, 使用OC的NSKeyedArchiver序列化
//        # 0A,00,00,00: 起始头
//        # 02,00,00,00: 2(obj) 3(u32) 4(u64) 5(u32) 6(u64)
//        # 55,1B,00,00: 序列化的数据长度
//        00000040: 0A 00 00 00 02 00 00 00  55 1B 00 00 62 70 6C 69  ........U...bpli
//        .....
//        # 最后面还跟了一个NSKeyedArchiver序列化后的数据，没有长度字段
//                          objectsY
//
//        ## 空数据Example, 仅用来应答收到的意思。其中的messageId需要跟请求的messageId保持一致
//        00000000: 79 5B 3D 1F 20 00 00 00  00 00 01 00 10 00 00 00  y[=. ...........
//        00000010: 03 00 00 00 01 00 00 00  00 00 00 00 00 00 00 00  ................
//        00000020: 00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  ................
