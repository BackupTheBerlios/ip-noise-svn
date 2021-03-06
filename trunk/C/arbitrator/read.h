#ifndef __IP_NOISE_READ_H
#define __IP_NOISE_READ_H

#ifdef __cplusplus
extern "C" {
#endif

enum IP_NOISE_READ_ERROR_CODES
{
    IP_NOISE_READ_OK = 0,
    IP_NOISE_READ_CONN_TERM = -1,
    IP_NOISE_READ_NOT_FULLY = -2,
};

#ifdef USE_TEXT_QUEUE_IN
#define ip_noise_read_commit() (ip_noise_read_commit_proto(self))
#define ip_noise_read_rollback() (ip_noise_read_rollback_proto(self)) 
#define ip_noise_read(buf, len) (ip_noise_read_proto(self, (buf), (len)))

#else

#define ip_noise_read_commit()  
#define ip_noise_read_rollback() 
#define ip_noise_read(buf, len) (ip_noise_conn_read(self->conn, (buf), (len)))

#endif

#ifdef USE_TEXT_QUEUE_OUT
#define ip_noise_write(buf, len) (ip_noise_write_proto(self, (buf), (len)))
#else
#define ip_noise_write(buf, len) (ip_noise_conn_write(self->conn, (buf), (len)))
#endif
            
#ifdef __cplusplus
};
#endif

#endif
