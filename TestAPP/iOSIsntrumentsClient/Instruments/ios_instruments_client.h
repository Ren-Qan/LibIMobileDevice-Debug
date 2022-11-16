#ifndef IOS_INSTRUMENTS_CLIENT
#define IOS_INSTRUMENTS_CLIENT

#include "cftypes.hpp"

int test(int argc, const char **argv);


//instruments连接建立之后，传输的消息为 DTXMessage
//DTXMessage = (DTXMessageHeader + DTXPayload)

//- DTXMessageHeader 主要用来对数据进行封包传输，以及说明是否需要应答
//DTXPayload = (DTXPayloadHeader + DTXPayloadBody)

//- DTXPayloadHeader 中的flags字段规定了 DTXPayloadBody 的数据类型
//- DTXPayloadBody 可以是任何数据类型 (None, (None, None), List) 都有可能


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
    void append_obj(CFTypeRef obj);
    
    void get_bytes(bytevec_t *out) const;
};



#endif // IOS_INSTRUMENTS_CLIENT
