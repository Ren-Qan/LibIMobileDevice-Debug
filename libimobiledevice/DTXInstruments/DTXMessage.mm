#include <unistd.h>
#include "DTXMessage.hh"

#import "DTXMessageService.hh"

//-----------------------------------------------------------------------------
void message_aux_t::append_int(int32_t val) {
    append_d(buf, 10);  // empty dictionary key
    append_d(buf, 3);   // 32-bit int
    append_d(buf, val);
}

//-----------------------------------------------------------------------------
void message_aux_t::append_long(int64_t val) {
    append_d(buf, 10);  // empty dictionary key
    append_d(buf, 4);   // 64-bit int
    append_q(buf, val);
}

//-----------------------------------------------------------------------------
void message_aux_t::append_obj(CFTypeRef obj) {
    append_d(buf, 10);  // empty dictionary key
    append_d(buf, 2);   // archived object
    
    bytevec_t tmp;
    archive(&tmp, obj);
    
    append_d(buf, uint32_t(tmp.size()));
    append_b(buf, tmp);
}

//-----------------------------------------------------------------------------
void message_aux_t::get_bytes(bytevec_t *out) const {
    if (!buf.empty()) {
        append_q(*out, 0x1F0);
        append_q(*out, buf.size());
        append_b(*out, buf);
    }
}
