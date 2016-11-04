//
//  TVUSignaling.cpp
//  TVUAnywhere
//
//  Created by zhangqi on 14/10/2016.
//
//

#include "TVUSignaling.h"
#import <Foundation/Foundation.h>
#include <iostream>
#import "NSJSONSerialization+TVU.h"
using namespace std;
using namespace sio;
#include <string.h>
#import "TVUConst.h"

TVUSignaling::TVUSignaling()
{
    m_messageQueue = (TVUVOIPMessageQueue*)malloc(sizeof(struct TVUVOIPMessageQueue));
    InitQueue(m_messageQueue);
    pthread_mutex_init(&queue_mutex, NULL);
}

TVUSignaling::~TVUSignaling()
{
}

TVUSignaling * TVUSignaling::m_instance = NULL;
TVUSignaling * TVUSignaling::getInstance()
{
    if (m_instance == NULL) {
        m_instance = new TVUSignaling();
    }
    return m_instance;
}

void TVUSignaling::setTvuusernumber(std::string tvuusernumber)
{
    this->tvuusernumber = tvuusernumber;
}

std::string TVUSignaling::getTvuusernumber()
{
    return this->tvuusernumber;
}

void TVUSignaling::InitQueue(TVUVOIPMessageQueue *Q)
{
    Q->size = 0;
    Q->front = NULL;
    Q->rear = NULL;
}

void TVUSignaling::EnQueue(TVUVOIPMessageQueue *Q,const char* data,int len ,KSignalingType type)
{
    VOIPQNode* node = (VOIPQNode *)malloc(sizeof(VOIPQNode));
    node->data = (char *)malloc(len+1);
    memcpy(node->data, data, len);
    node->data[len] = 0;
    node->type = type;
    node->next = NULL;
    
    pthread_mutex_lock(&queue_mutex);
    
    if (Q->front == NULL)
    {
        Q->front = node;
        Q->rear = node;
    }
    else
    {
        Q->rear->next = node;
        Q->rear = node;
    }
    Q->size += 1;
    pthread_mutex_unlock(&queue_mutex);
}


VOIPQNode* TVUSignaling::DeQueue(TVUVOIPMessageQueue *Q)
{
    VOIPQNode* element = NULL;
    
    pthread_mutex_lock(&queue_mutex);
    
    element = Q->front;
    if(element == NULL)
    {
        pthread_mutex_unlock(&queue_mutex);
        return NULL;
    }
    
    Q->front = Q->front->next;
    Q->size -= 1;
    pthread_mutex_unlock(&queue_mutex);
    
    return element;
}

void TVUSignaling::FreeNode(VOIPQNode* Node){
    if(Node != NULL){
        free(Node->data);
        free(Node);
    }
}

void TVUSignaling::onopen()
{
    printf("connect succ\n");
    NSString *usernumber = [NSString stringWithCString:this->getTvuusernumber().c_str() encoding:NSUTF8StringEncoding];
    NSDictionary *dict = @{@"username":usernumber};
    std::string requestparam_login([[NSJSONSerialization JSONStringWithJSONObject:dict] UTF8String]);
    sclient.socket()->emit("login",requestparam_login);
}

void TVUSignaling::postanswer(const char* sdp,const char* callfromnumber)
{
    if (sdp == NULL||strlen(sdp) <=0) {
        return;
    }
    std::string strsdp(sdp);
    NSDictionary *dict = @{@"to":[NSString stringWithUTF8String:callfromnumber],@"type":@"answer",@"sdp":[NSString stringWithUTF8String:sdp]};
    NSString *offer_json = [NSJSONSerialization JSONStringWithJSONObject:dict];
    if ([offer_json length] > 0) {
        string answerparam([offer_json UTF8String]);
        sclient.socket()->emit("answer",answerparam);
    }
}

void TVUSignaling::postice(const char* candidate,const char* sdpMid,const char* sdpMLineIndex,const char* callfromnumber)
{
    NSDictionary *dict = @{@"to":[NSString stringWithUTF8String:callfromnumber],@"candidate":[NSString stringWithUTF8String:candidate],@"sdpMid":[NSString stringWithUTF8String:sdpMid],@"sdpMLineIndex":[NSString stringWithUTF8String:sdpMLineIndex]};
    
    NSString *offer_json = [NSJSONSerialization JSONStringWithJSONObject:dict];
    if ([offer_json length] > 0) {
        string iceparam([offer_json UTF8String]);
        sclient.socket()->emit("ice",iceparam);
    }
}

void TVUSignaling::postResponse(bool isAccept,const char* callfromnumber)
{
    NSString *response_value = isAccept ? @"true" : @"false";
    NSDictionary *dict = @{@"to":[NSString stringWithUTF8String:callfromnumber],@"response":response_value};
    string responseParam([[NSJSONSerialization JSONStringWithJSONObject:dict] UTF8String]);
    sclient.socket()->emit("call_response",responseParam);
}

void TVUSignaling::postDisconnectpeer(const char* peername)
{
    NSString *peerName = [NSString stringWithUTF8String:peername];
    NSDictionary *dict = @{@"to":peerName};
    NSString *peerName_json = [NSJSONSerialization JSONStringWithJSONObject:dict];
    if ([peerName_json length] > 0) {
        string disconnparam([peerName_json UTF8String]);
        sclient.socket()->emit("disconnectpeer",disconnparam);
    }
}

int TVUSignaling::beginConnection()
{
    sclient.set_open_listener(std::bind(&TVUSignaling::onopen, this));
    sclient.socket()->on("login", sio::socket::event_listener_aux([&](string const&name,
                                                                      message::ptr const& data,bool isAck,message::list &ack_resp)
                                                                  {
                                                                      string loginResStr("0");
                                                                      if (data->get_map()["success"]->get_bool()) {
                                                                          loginResStr = "1";
                                                                      }
                                                                      const char* loginRes = loginResStr.c_str();
                                                                      int len = (int)loginResStr.length();
                                                                      
                                                                      this->EnQueue(m_messageQueue,loginRes,len,KSignalingTypeLogin);
                                                                  }));
    // bind other event
    sclient.socket()->on("call_request", sio::socket::event_listener_aux([&](string const&name,
                                                                             message::ptr const& data,bool isAck,message::list &ack_resp)
                                                                         {
                                                                             const char* callrequest = data->get_string().c_str();
                                                                             int len = (int)data->get_string().length();
                                                                             
                                                                             this->EnQueue(m_messageQueue,callrequest,len,KSignalingTypeCallRequest);
                                                                             
                                                                         }));
    
    sclient.socket()->on("call_response", sio::socket::event_listener_aux([&](string const&name,
                                                                              message::ptr const& data,bool isAck,message::list &ack_resp)
                                                                          {
                                                                              printf("---in call_response---%s\n",data->get_string().c_str());
                                                                          }));
    
    sclient.socket()->on("offer", sio::socket::event_listener_aux([&](string const&name,
                                                                      message::ptr const& data,bool isAck,message::list &ack_resp)
                                                                  {
                                                                      const char* sdpres = data->get_string().c_str();
                                                                      int len = (int)data->get_string().length();
                                                                      
                                                                      this->EnQueue(m_messageQueue,sdpres,len,KSignalingTypeOffer);
                                                                      
                                                                  }));
    sclient.socket()->on("ice", sio::socket::event_listener_aux([&](string const&name,
                                                                    message::ptr const& data,bool isAck,message::list &ack_resp)
                                                                {
                                                                    const char* iceDes = data->get_string().c_str();
                                                                    int len = (int)data->get_string().length();
                                                                    this->EnQueue(m_messageQueue, iceDes, len, KSignalingTypeIce);
                                                                }));
    
    sclient.socket()->on("answer", sio::socket::event_listener_aux([&](string const&name,
                                                                       message::ptr const& data,bool isAck,message::list &ack_resp)
                                                                   {
                                                                       printf("---in answer---%s\n",data->get_string().c_str());
                                                                   }));
    sclient.socket()->on("disconnectpeer", sio::socket::event_listener_aux([&](string const&name,
                                                                       message::ptr const& data,bool isAck,message::list &ack_resp)
                                                                   {
                                                                       printf("---in disconnectpeer---%s\n",data->get_string().c_str());
                                                                   }));
    
    
//     begin connect
    const char* json = "{\"xx\": \"yy\"}";
    rapidjson::Document d;
    d.Parse(json);
    
    sclient.connect(WebRTCServer);
    return 0;
}
