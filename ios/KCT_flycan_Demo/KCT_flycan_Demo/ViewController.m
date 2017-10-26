//
//  ViewController.m
//  KCT_flycan_Demo
//
//  Created by KCMac on 2017/8/24.
//  Copyright © 2017年 flypass. All rights reserved.
//

#import "ViewController.h"
#import "HttpRequestEngine.h"
#include <pthread.h>


#define kCallSdkId  @"callsdkid"
#define kCalledSdkId @"calledsdkid"

@interface ViewController ()
{
    flycan *flyEngin;
    int _sessionId;
    int _newSessionId;
    NSUserDefaults *userdefault;
    BOOL isServier;
    int count;
    NSMutableString *showString;
}

@property(nonatomic,weak)IBOutlet UITextField *call;
@property(nonatomic,weak)IBOutlet UITextField *called;
@property(nonatomic,weak)IBOutlet UITextView *statueLabel;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    showString = [[NSMutableString alloc] init];
    self.statueLabel.editable = NO;
    count = 0;
#ifdef kTestEnvironment
    NSString *accountSid = @"809d2c33e8ba713460083ee65de42a71";
    NSString *token = @"980e7daebdf7fc4aa6f55bda74b41d17";
    NSString *appid = @"47201f1d7bd043c18069375172f82572";
#else
    NSString *accountSid = @"b64e977c108810429b9056208059d362";
    NSString *token = @"cd1e4ce88775dcaf8bbf9236e9811c4a";
    NSString *appid = @"57993353d8724285904ba22a20d51ee9";
#endif
    
//    [[HttpRequestEngine engineInstance] applySDKID:accountSid appid:appid token:token successBlock:^(NSDictionary *responseDict) {
//        NSLog(@"resp %@",responseDict);
//    } failBlock:^(NSDictionary *responseDict) {
//        
//    }];
    
    userdefault = [NSUserDefaults standardUserDefaults];
    NSString *callid = [userdefault objectForKey:kCallSdkId];
    NSString *calledid = [userdefault objectForKey:kCalledSdkId];
    if (!callid) {
        callid = @"62395051197521";
    }
    if (!calledid) {
        calledid = @"62395051197520";
    }
    
#ifdef kTestEnvironment
    self.call.text = @"62395051197520";
    self.called.text = @"62395051197521";
    
#else
    self.call.text = @"62508051197251";
    self.called.text = @"62508051197250";
#endif
    
    
    flyEngin = [[flycan alloc] init];
    flyEngin.delegate = self;
    
    NSString *sdkid = self.call.text;
    NSString *peerid = self.called.text;
    
    [flyEngin flycanInit:accountSid token:token appid:appid sdkid:sdkid];
    [userdefault setObject:sdkid forKey:kCallSdkId];
    [userdefault setObject:peerid forKey:kCalledSdkId];
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)flycanEvent:(int)sessionId eventType:(FlycanEventType)eventType param:(void *)param
{
    NSString *showText;
    
    if (eventType == EVT_REGISTER_SUCCUSS) {
        _sessionId = [flyEngin flycanCreateSession:TransportProtocolUDP];
        [flyEngin flycanSessionListen:sessionId sessionNum:2];
        showText = [NSString stringWithFormat:@"注册成功 create sessionId: %d\n",_sessionId];
    }
    if (eventType == EVT_SESSION_INCOMING) {
        isServier = YES;
        _newSessionId = [flyEngin flycanAcceptSession:_sessionId];
        showText = [NSString stringWithFormat:@"收到 sessionId: %d 的请求连接\n",_newSessionId];
        int *ptr = param;
        NSLog(@"channel number is %d",*ptr);
        //[flyEngin flycan_reject_session:session];
    }
    if (eventType == EVT_SESSION_BIND_SUCCUSS) {
        showText = [NSString stringWithFormat:@"session bind success\n"];
    }
    if (eventType == EVT_SESSION_BIND_FAILURE) {
        showText = [NSString stringWithFormat:@"session bind fail\n"];
    }
    if (eventType == EVT_UNREGISTER) {
        showText = [NSString stringWithFormat:@"unRegister !!!\n"];
    }
    if (showText != NULL) {
        [self updateState:showText];
    }
}


- (void)flycanRecv:(int)sessionId buf:(void *)buf len:(int)len channelIndxe:(int)channelIndxe
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *showText = [NSString stringWithFormat:@"data recv :%s size :%d sessionId :%d channel: %d\n",buf,len,sessionId,channelIndxe];
        printf("recv %s\n",buf);
        [self updateState:showText];
    });
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)login:(id)sender {

    [flyEngin flycanRegister];
    NSString *showText = [NSString stringWithFormat:@"beed login...\n"];
    [self updateState:showText];
}


- (IBAction)connect:(id)sender {
    [flyEngin flycanConnectSession:_sessionId peerId:self.called.text];
#ifdef kTestEnvironment
    
    //[flyEngin flycanConnectServer:_sessionId ip:@"192.168.0.231" port:8800];
#else
    [flyEngin flycanConnectServer:_sessionId ip:@"114.112.83.110" port:5000];
    
#endif
    NSString *showText = [NSString stringWithFormat:@"beed connecting sessionId: %d\n",_sessionId];
    [self updateState:showText];
}

- (IBAction)disconnect:(id)sender {
    [flyEngin flycanReleaseSession:_sessionId];
    NSString *showText = [NSString stringWithFormat:@"disconnect sessionId: %d\n",_sessionId];
    [self updateState:showText];
}

- (IBAction)eixt:(id)sender {
    [flyEngin flycanUnRegister];
    //exit(0);
}

- (IBAction)sendData:(id)sender {
    NSString *str = @"flycan Sdk";
    NSData *data =  [str dataUsingEncoding:NSUTF8StringEncoding];
    int sendSessionId = _sessionId;
    if (isServier) {
        sendSessionId = _newSessionId;
    }

    [flyEngin flycanSend:sendSessionId data:data len:data.length channelIndex:0];
    NSString *showText = [NSString stringWithFormat:@"send buffer: %@ sessionId: %d\n",str,sendSessionId];
    [self updateState:showText];
    
    pthread_t g_cmdRecvDataThreadId;
    pthread_create(&g_cmdRecvDataThreadId, NULL, CmdRecvDataThread, (__bridge void *)self);
    
}

void *CmdRecvDataThread(void *param)
{
    ViewController *selfPtr = (__bridge ViewController *)param;
    int sendSessionId = selfPtr->_sessionId;
    if (selfPtr->isServier) {
        sendSessionId = selfPtr->_newSessionId;
    }
    
    for (int i = 0; i<1000000; i++) {
        sleep(1);
        
        NSString *str1 = [NSString stringWithFormat:@"send %d times",i];
        NSData *data1 =  [str1 dataUsingEncoding:NSUTF8StringEncoding];
        [selfPtr->flyEngin flycanSend:sendSessionId data:data1 len:data1.length channelIndex:0];
    }
    return NULL;
}

- (void)updateState:(NSString *)context {
    [showString appendString:context];
    self.statueLabel.text = showString;
}


- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

@end
