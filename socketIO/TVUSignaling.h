//
//  TVUSignaling.hpp
//  TVUAnywhere
//
//  Created by zhangqi on 14/10/2016.
//
//
#include <stdio.h>
#include <functional>
#include "sio_client.h"
#include "rapidjson/rapidjson.h"
#include "rapidjson/document.h"
#import "TVUConst.h"

//#define WebRTCServer "http://10.12.23.232:9000"
//#define WebRTCServer "https://10.12.23.232:9090"
#define WebRTCServer "http://rtc.tvutvu232tvutvu.com:9012" // 换成你们自己的地址

#define WebRTCServer_OC @"http://rtc.tv123utvutvu.com:9120" // 换成你们自己的地址

typedef  enum
{
    KSignalingTypeLogin = 0,
    KSignalingTypeCallRequest,
    KSignalingTypeCallResponse,
    KSignalingTypeOffer,
    KSignalingTypeIce,
    KSignalingTypeAnswer,
    KSignalingTypeDisconnectPeer
}KSignalingType;

typedef struct VOIPQNode
{
    KSignalingType type;
    char* data;
    struct VOIPQNode *next;
}VOIPQNode;

typedef struct TVUVOIPMessageQueue
{
    int size;
    VOIPQNode *front;
    VOIPQNode *rear;
}TVUVOIPMessageQueue;

class TVUSignaling
{
public:
    static TVUSignaling * getInstance();
    TVUSignaling();
    ~TVUSignaling();
    int beginConnection();
    void postanswer(const char* sdp,const char* callfromnumber);
    void postice(const char* candidate,const char* sdpMid,const char* sdpMLineIndex,const char* callfromnumber);
    void postResponse(bool isAccept,const char* callfromnumber);
    void postDisconnectpeer(const char* peername);
    
    void setTvuusernumber(std::string tvuusernumber);
    std::string getTvuusernumber();
    
    void InitQueue(TVUVOIPMessageQueue *Q);
    void EnQueue(TVUVOIPMessageQueue *Q, const char* data,int len,KSignalingType type);
    VOIPQNode *DeQueue(TVUVOIPMessageQueue *Q);
    VOIPQNode *GetNode(TVUVOIPMessageQueue *Q);
    void FreeNode(VOIPQNode* Node);
    TVUVOIPMessageQueue *m_messageQueue;
    
    
private:
    sio::client sclient;
    void onopen();
    static TVUSignaling * m_instance;
    std::string tvuusernumber;
    
    pthread_mutex_t queue_mutex;
};
