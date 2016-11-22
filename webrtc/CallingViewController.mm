//
//  CallingViewController.m
//  TVUAnywhere
//
//  Created by zhangqi on 17/10/2016.
//
//

#import "CallingViewController.h"
#import "TVUSignaling.h"
#import <WebRTC/WebRTC.h>
#import "RTCIceCandidate+JSON.h"
#import <AVFoundation/AVFoundation.h>
#import "NSJSONSerialization+TVU.h"
#import "TVUConst.h"
#import "AudioPlayer.h"

extern std::string remoteSDP;
extern std::string remoteIceDes;


typedef void (^SetSdpCompletionHander)(NSError * _Nullable);

// 把下面这些参数换成你们自己的
#define kStunserver1 @""
#define kStunserver2 @""
#define kStunserver3 @""
#define  kStunserver4 @""

@interface CallingViewController () <RTCPeerConnectionDelegate>
{
    TVUSignaling *_tvuSignal;
}

@property (nonatomic,strong)RTCPeerConnectionFactory *pcFactory;
@property (nonatomic,strong)RTCPeerConnection *peerConnection;
@property (nonatomic,strong) RTCMediaStream *localStream;
@property (nonatomic,strong) RTCAudioTrack *audioTrack;

@property (nonatomic,strong) RTCSessionDescription *m_sdp;
@property (nonatomic,strong) NSString *m_stricecandidate;

@property (nonatomic,strong) NSString *mypeerid;
@property (nonatomic,strong) NSString *callfromnumber;
@end

@implementation CallingViewController

- (void)loginWebRTCServer:(NSString *)peerid
{
    self.mypeerid = peerid;
    _tvuSignal->setTvuusernumber(std::string([peerid UTF8String]));
    dispatch_async(TVUGlobalQueue, ^{
        _tvuSignal->beginConnection();
    });
}

- (BOOL)isHavePhoneCall
{
    return [self.callfromnumber length] > 0 ? YES : NO;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _tvuSignal = new TVUSignaling();
        [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(processingMessageQueue) userInfo:nil repeats:YES];
    }
    return self;
}

- (RTCPeerConnectionFactory *)pcFactory
{
    if (!_pcFactory) {
        _pcFactory = [[RTCPeerConnectionFactory alloc] init];
        RTCSetMinDebugLogLevel(RTCLoggingSeverityVerbose);
    }
    return _pcFactory;
}

- (RTCPeerConnection *)peerConnection
{
    if (!_peerConnection) {
        RTCConfiguration *config = [[RTCConfiguration alloc] init];
        [config setIceServers:[self defaultICEServers]];
        _peerConnection = [self.pcFactory peerConnectionWithConfiguration:config constraints:nil delegate:self];
       
        [_peerConnection addStream:self.localStream];
    }
    return _peerConnection;
}

- (NSArray *)defaultICEServers
{
    RTCIceServer *iceserver1 = [[RTCIceServer alloc] initWithURLStrings:@[kStunserver1] username:@"tvu" credential:@"tvu"];
    RTCIceServer *icerserver3 = [[RTCIceServer alloc] initWithURLStrings:@[kStunserver3]];
    RTCIceServer *icerserver4 = [[RTCIceServer alloc] initWithURLStrings:@[kStunserver4]];

    return @[iceserver1,icerserver3,icerserver4];
}

#pragma mark - Defaults
- (RTCMediaConstraints *)defaultMediaStreamConstraints {
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc]
     initWithMandatoryConstraints:nil
     optionalConstraints:nil];
    return constraints;
}

- (RTCMediaStream *)localStream
{
    if (!_localStream) {
        _localStream = [self.pcFactory mediaStreamWithStreamId:@"ARDAMS"];
        _audioTrack = [self.pcFactory audioTrackWithTrackId:@"ARDAMSa0"];
        [_localStream addAudioTrack:_audioTrack];
    }
    return _localStream;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self peerConnection];
}

- (RTCMediaConstraints *)defaultMediaAudioConstraints {
    NSDictionary *mandatoryConstraints = @{kRTCMediaConstraintsLevelControl : kRTCMediaConstraintsValueTrue};
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc]  initWithMandatoryConstraints:mandatoryConstraints
                                           optionalConstraints:nil];
    return constraints;
}

SetSdpCompletionHander setRemoteSdpCompletionHander = ^(NSError * _Nullable error)
{
    NSLog(@"handle set remote sdp");
    
    
};

SetSdpCompletionHander setLocalSdpCompletionHander = ^(NSError * _Nullable error)
{
    NSLog(@"handle set local sdp");
};

- (void)beginAcceptCall
{
        [self.peerConnection answerForConstraints:nil completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
            self.m_sdp = sdp;
            if (error != NULL) {

            }else{
                dispatch_async(TVUMainQueue, ^{
                    [self.peerConnection setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
                        error != NULL ? NSLog(@"set local sdp failed") : NSLog(@"set local sdp succ");
                    }];
                });
            }
        }];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    if (self.callfromnumber != NULL) {
        _tvuSignal->postResponse(true,[self.callfromnumber UTF8String]);  // accept call
    }
    
    
    
}

- (void)processingMessageQueue
{
    TVUVOIPMessageQueue *messageQueue = _tvuSignal->m_messageQueue;
    
    VOIPQNode *node = _tvuSignal->DeQueue(messageQueue);
    if (node == NULL) {
        return;
    }
    KSignalingType messtype = node->type;
    char* message = node->data;
    NSString *messageStr = [NSString stringWithUTF8String:message];
    NSLog(@"qizhang---enennene---2222-----%@---%d",messageStr,messtype);
    switch (messtype) {
        case KSignalingTypeOffer:
        {
            [self processOfferInfoUseMessageData:messageStr];
        }
            break;
        case KSignalingTypeIce:
        {
            [self processIceCandidateUseMessageData:messageStr];
        }
            break;
        case KSignalingTypeLogin:
        {
            [self processLoginInfoUseMessageData:messageStr];
        }
            break;
        case KSignalingTypeCallRequest:
        {
            [self processCallRequestUseMessageData:messageStr];
        }
            break;
            
        default:
            break;
    }
    _tvuSignal->FreeNode(node);
    
}

- (void)processCallRequestUseMessageData:(NSString *)message
{
    self.callfromnumber = [NSJSONSerialization getJsonValueWithKey:@"from" jsonString:message];
    NSLog(@"WebRTC----callfromnumber:%@",self.callfromnumber);
}

- (void)processLoginInfoUseMessageData:(NSString *)message
{
    if ([message isEqualToString:@"1" ]) {
        NSLog(@"WebRTC----login success");
    }
    
}

- (void)processOfferInfoUseMessageData:(NSString *)message
{
    
    if ([message length] <= 0) {
        return;
    }
    NSData *jsonData = [message dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:NULL];
    NSString *sdpstr = [dic objectForKey:@"sdp"];

    RTCSessionDescription *remoteSDP = [[RTCSessionDescription alloc] initWithType:RTCSdpTypeOffer sdp:sdpstr];
    if (remoteSDP != NULL) {
        [self.peerConnection setRemoteDescription:remoteSDP completionHandler:^(NSError * _Nullable error) {
            if (error != NULL) {
                NSLog(@"set remote sdp failed");
            }else{
                NSLog(@"set remote sdp succ");
            }
        }];
    }
}

- (void)processIceCandidateUseMessageData:(NSString *)message
{
    if ([message length] <= 0) {
        return;
    }
    NSString *candidate = [NSJSONSerialization getJsonValueWithKey:@"candidate" jsonString:message];
    NSString *sdpMLineIndexStr = [NSJSONSerialization getJsonValueWithKey:@"sdpMLineIndex" jsonString:message];
    NSString *sdpMid = [NSJSONSerialization getJsonValueWithKey:@"sdpMid" jsonString:message];
    RTCIceCandidate *iceCandidate = [[RTCIceCandidate alloc] initWithSdp:candidate sdpMLineIndex:[sdpMLineIndexStr intValue] sdpMid:sdpMid];
    
    [self.peerConnection addIceCandidate:iceCandidate];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    // set remote sdp
}

- (IBAction)onpressedbuttonAcceptCall:(id)sender {
    [self beginAcceptCall];
}

- (IBAction)onpressedbuttonRejectCall:(id)sender {
    dispatch_async(TVUGlobalQueue, ^{
        _tvuSignal->postResponse(false,[self.callfromnumber UTF8String]);
        
        dispatch_async(TVUMainQueue, ^{
           [self dismissViewControllerAnimated:YES completion:^{
               self.callfromnumber = NULL;
           }];
        });
        
    });
}

- (IBAction)onpressedbuttonEndCall:(id)sender {
    dispatch_async(TVUGlobalQueue, ^{
        _tvuSignal->postDisconnectpeer([self.mypeerid UTF8String]);
        RTCCleanupSSL();
        [self.peerConnection close ];
    });
}

- (IBAction)onpressedbuttonDismissController:(id)sender
{
    
}

#pragma mark -RTCPeerConnectionDelegate
/** Called when the SignalingState changed. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeSignalingState:(RTCSignalingState)stateChanged
{
    NSLog(@"%s",__func__);
}

/** Called when media is received on a new stream from remote peer. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
          didAddStream:(RTCMediaStream *)stream
{
    NSLog(@"%s",__func__);
}

/** Called when a remote peer closes a stream. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
       didRemoveStream:(RTCMediaStream *)stream
{
    NSLog(@"%s",__func__);
}

/** Called when negotiation is needed, for example ICE has restarted. */
- (void)peerConnectionShouldNegotiate:(RTCPeerConnection *)peerConnection
{
    NSLog(@"%s",__func__);
}

/** Called any time the IceConnectionState changes. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeIceConnectionState:(RTCIceConnectionState)newState
{
    NSLog(@"%s---------peerConnection:------%@-------newState:-----%ld---end",__func__,[peerConnection description],(long)newState);
}

/** Called any time the IceGatheringState changes. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeIceGatheringState:(RTCIceGatheringState)newState
{
    NSLog(@"%s---------peerConnection:------%@-------newState:-----%ld---end",__func__,[peerConnection description],(long)newState);
    
    if (newState == RTCIceGatheringStateComplete) {
        _tvuSignal->postanswer([self.peerConnection.localDescription.sdp UTF8String],[self.callfromnumber UTF8String]);
    }
    
}



/** New ice candidate has been found. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didGenerateIceCandidate:(RTCIceCandidate *)candidate
{
    self.m_stricecandidate = [candidate description];
    NSData *data = [candidate JSONData];
    
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:NULL];
    NSString *candidateStr = (NSString *)[dict objectForKey:@"candidate"];
    NSLog(@"%@-----------%ld-----------%@",candidate.sdpMid,(long)candidate.sdpMLineIndex,candidateStr);
    _tvuSignal->postice([candidateStr UTF8String], [candidate.sdpMid UTF8String], [[NSString stringWithFormat:@"%ld",(long)candidate.sdpMLineIndex] UTF8String],[self.callfromnumber UTF8String]);
}

/** Called when a group of local Ice candidates have been removed. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didRemoveIceCandidates:(NSArray<RTCIceCandidate *> *)candidates
{
    NSLog(@"%s",__func__);
}

/** New data channel has been opened. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
    didOpenDataChannel:(RTCDataChannel *)dataChannel
{
    NSLog(@"%s",__func__);
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
