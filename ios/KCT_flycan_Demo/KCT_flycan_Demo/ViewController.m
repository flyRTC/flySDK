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
#include <sys/time.h>

struct UdpPackHeader {
    int seq;
    int check;
    double timeSp;
    int bodyLen;
};


#define kCallSdkId  @"callsdkid"
#define kCalledSdkId @"calledsdkid"
#define kMaxSessionNum  1


@interface ViewController ()
{
    flycan *flyEngin;
    BOOL isSend;
    int _newSessionId;
    BOOL isServier;
    
    NSMutableString *showString;
    NSMutableArray *sessionArray;
    
    int sendNum;
    int timerNum;
}

@property(nonatomic,weak)IBOutlet UITextField *call;
@property(nonatomic,weak)IBOutlet UITextField *called;
@property(nonatomic,weak)IBOutlet UITextView *statueLabel;
@property(nonatomic,weak)IBOutlet UITextField *bufferLabel;
@property(nonatomic,weak)IBOutlet UILabel *conStateLabel;
@property(atomic,assign) BOOL running;
@property(nonatomic,strong) NSMutableArray *packArray;

@end

@implementation ViewController



- (void)viewDidLoad {
    [super viewDidLoad];
    
    showString = [[NSMutableString alloc] init];
    sessionArray = [[NSMutableArray alloc] init];
    self.packArray = [NSMutableArray arrayWithCapacity:1000];
    [self initArray];
    
    self.statueLabel.editable = NO;
    sendNum = 0;
    timerNum = 0;
    
#ifdef kTestEnvironment
    NSString *accountSid = @"809d2c33e8ba713460083ee65de42a71";
    NSString *token = @"980e7daebdf7fc4aa6f55bda74b41d17";
    NSString *appid = @"47201f1d7bd043c18069375172f82572";
    
    self.call.text = @"62395051197521";
    self.called.text = @"62395051197520";
#else
    NSString *accountSid = @"b64e977c108810429b9056208059d362";
    NSString *token = @"cd1e4ce88775dcaf8bbf9236e9811c4a";
    NSString *appid = @"57993353d8724285904ba22a20d51ee9";
    
    self.call.text = @"62508051197251";//62395051197525
    self.called.text = @"62508051197250";
#endif
    
    
    flyEngin = [[flycan alloc] init];
    flyEngin.delegate = self;
    
    NSString *sdkid = self.call.text;
    
    [flyEngin flycanInit:accountSid token:token appid:appid sdkid:sdkid];
    
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSNumber *bufMax = [defaults objectForKey:@"maxBuffer"];
    self.bufferLabel.text = [bufMax stringValue];
    
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(sendTimer) userInfo:nil repeats:YES];
    [timer fire];
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)flycanEvent:(int)sessionId eventType:(FlycanEventType)eventType param:(void *)param
{
    NSString *showText;
    
    if (eventType == EVT_REGISTER_SUCCUSS) {
        //_sessionId = [flyEngin flycanCreateSession:TransportProtocolTCP];
        
        for (int i = 0; i < kMaxSessionNum; i++)
        {
            int sid = [flyEngin flycanCreateSession:TransportProtocolUDP];
            [flyEngin flycanSessionListen:sid sessionNum:2];
            NSNumber *num = [NSNumber numberWithInt:sid];
            [sessionArray addObject:num];
        }
        showText = [NSString stringWithFormat:@"注册成功\n"];
    }
    if (eventType == EVT_REGISTER_FAILURE) {
        showText = [NSString stringWithFormat:@"注册失败\n"];
    }
    if (eventType == EVT_SESSION_INCOMING) {
        isServier = YES;
        _newSessionId = [flyEngin flycanAcceptSession:sessionId];
        showText = [NSString stringWithFormat:@"收到 sessionId: %d 的请求连接\n",sessionId];
        int *ptr = param;
        NSLog(@"channel number is %d",*ptr);
        //[flyEngin flycan_reject_session:session];
    }
    if (eventType == EVT_SESSION_BIND_SUCCUSS) {
        showText = [NSString stringWithFormat:@"会话绑定成功\n"];
    }
    if (eventType == EVT_SESSION_BIND_FAILURE) {
        showText = [NSString stringWithFormat:@"会话绑定失败\n"];
    }
    if (eventType == EVT_SESSION_CONNECTED_SUCCESS) {
        showText = [NSString stringWithFormat:@"会话连接成功\n"];
    }
    if (eventType == EVT_SESSION_CONNECTED_FAILUER) {
        showText = [NSString stringWithFormat:@"会话连接失败\n"];
    }
    if (eventType == EVT_SESSION_DISCONNED) {
        showText = [NSString stringWithFormat:@"会话已经断开\n"];
    }
    if (eventType == EVT_UNREGISTER) {
        showText = [NSString stringWithFormat:@"反注册 !!!\n"];
        [flyEngin flycanUnInit];
    }
    
    
    if (showText != NULL) {
        [self updateState:showText];
    }
}

- (void)flyTran:(int)sessionId direct:(int)direct
{
    if (direct == 1)
    {
        self.conStateLabel.text = @"直连";
    }
    else
    {
        self.conStateLabel.text = @"中转";
    }
}


- (void)flycanRecv:(int)sessionId buf:(void *)buf len:(int)len channelIndxe:(int)channelIndxe
{
    struct UdpPackHeader *header = (struct UdpPackHeader *)buf;
    double timeSp = getTickCount();
    double times = timeSp - header->timeSp;
    if (times >= 2000)
    {
        NSLog(@"超时了 %f",times);
    }
    else
    {
        if (header->check == 1010)
        {
            UdpPackItem *item = [_packArray objectAtIndex:header->seq];
            item.recvTimeSp = getTickCount();
            item.isRecv = YES;
            //printf("------seq  %d\n",header->seq);
        }
    }
    
    //printf("----------%d  \n",header->seq);
    //recvNum++;
    //NSLog(@"------recv times :%d---- ",recvNum);
    //NSLog(@"sessionId :%d recv data len:%d channelIndex:%d",sessionId,len,channelIndxe);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *showText = [NSString stringWithFormat:@"recv pack len:%d\n",len];
        //printf("recv %s\n",buf);
        //[self updateState:showText];
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
    
    for (int i = 0; i < kMaxSessionNum; i++) {
        NSNumber *num = [sessionArray objectAtIndex:i];
        int sid = [num intValue];
        //[flyEngin flycanConnectServer:sid ip:@"192.168.0.247" port:8800];
        [flyEngin flycanConnectSession:sid peerId:self.called.text];
        //[flyEngin flycanConnectServer:sid ip:@"114.112.83.110" port:29099];
        //[flyEngin flycanConnectServer:sid ip:@"192.168.0.196" port:29099];
        
    }
    //[flyEngin flycanConnectSession:_sessionId peerId:self.called.text];
#ifdef kTestEnvironment
    
    //[flyEngin flycanConnectServer:_sessionId ip:@"192.168.0.145" port:8800];
#else
    //[flyEngin flycanConnectServer:_sessionId ip:@"114.112.83.110" port:9099];
    
#endif
    
    //[flyEngin flycanConnectServer:_sessionId ip:@"114.112.83.110" port:29099];
    
    NSString *showText = [NSString stringWithFormat:@"连接成功\n"];
    [self updateState:showText];
}

- (IBAction)disconnect:(id)sender {
    isSend = NO;
    //[flyEngin flycanReleaseSession:_sessionId];
    for (int i = 0; i < kMaxSessionNum; i++) {
        NSNumber *num = [sessionArray objectAtIndex:i];
        int sid = [num intValue];
        [flyEngin flycanReleaseSession:sid];
    }
    NSString *showText = [NSString stringWithFormat:@"断开连接\n"];
    [self updateState:showText];
    
    [self performSelector:@selector(printLost) withObject:nil afterDelay:0.5];
}

- (IBAction)unRegister:(id)sender {
    [flyEngin flycanUnRegister];
}

- (IBAction)eixt:(id)sender {
    exit(0);
}



- (IBAction)sendData:(id)sender {
#if 0
    NSString *str = @"flycan Sdk";
    NSData *data =  [str dataUsingEncoding:NSUTF8StringEncoding];
    int sendSessionId = _sessionId;
    if (isServier) {
        sendSessionId = _newSessionId;
    }

    [flyEngin flycanSend:sendSessionId data:data len:data.length channelIndex:0];
    NSString *showText = [NSString stringWithFormat:@"send buffer: %@ sessionId: %d\n",str,sendSessionId];
    [self updateState:showText];
#endif
    isSend = YES;
    sendNum = 0;
    self.running = YES;
    pthread_t udpSendDataThreadId;
    pthread_create(&udpSendDataThreadId, NULL, UdpSendDataThread, (__bridge void *)self);
    
}

-(void)sendTimer
{
    if (!self.running && isSend)
    {
        if (timerNum == 0)
        {
            [self performSelector:@selector(printLost) withObject:nil afterDelay:2.0];
        }
        
        timerNum++;
        if (timerNum >= 15)
        {
            self.running = YES;
            timerNum = 0;
        }
    }
}

static NSTimeInterval getTickCount() {
    
    struct timeval tv;
    
    if (gettimeofday(&tv, NULL) != 0)
        return 0;
    
    return (tv.tv_sec * 1000 + tv.tv_usec / 1000);
}

void *UdpSendDataThread(void *param)
{
    ViewController *selfPtr = (__bridge ViewController *)param;
    NSString *strBuf = selfPtr.bufferLabel.text;
    int max = [strBuf intValue];
    
    while (selfPtr->isSend)
    {
        if (selfPtr.running)
        {
            for (int k = 0; k < 10; k++)
            {
                for (int i = 0; i < kMaxSessionNum; i++)
                {
                    NSNumber *num = [selfPtr->sessionArray objectAtIndex:i];
                    int sid = [num intValue];
                    @autoreleasepool
                    {
                        char *buffer = (char*)malloc(max);
                        memset(buffer, 0, max);
                        struct UdpPackHeader *packHeader = (struct UdpPackHeader *)buffer;
                        packHeader->seq = selfPtr->sendNum;
                        packHeader->check = 1010;
                        packHeader->timeSp = getTickCount();
                        packHeader->bodyLen = 1024 - sizeof(packHeader);
                        UdpPackItem *packItem = [selfPtr.packArray objectAtIndex:selfPtr->sendNum];
                        packItem.isRecv = NO;
                        packItem.sendTimeSp = getTickCount();
                        packItem.seq = selfPtr->sendNum;
                        //printf("------seq  %d\n",selfPtr->sendNum);
                        
                        NSData *data1 =  [NSData dataWithBytes:buffer length:max];
                        free(buffer);
                        [selfPtr->flyEngin flycanSend:sid data:data1 len:data1.length channelIndex:0];
                        selfPtr->sendNum++;
                        if (selfPtr->sendNum == 1000)
                        {
                            selfPtr.running = NO;
                            selfPtr->sendNum = 0;
                        }
                        //NSLog(@"------send times :%d---- ",selfPtr->sendNum);
                    }
                }
                
            }
        }
        
        usleep(50*1000);
    }
    
    return NULL;
}

- (void)updateState:(NSString *)context {
    [showString appendString:context];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statueLabel.text = showString;
    });
}

-(void)initArray
{
    for (int i = 0; i< 1000; i++) {
        UdpPackItem *packItem = [[UdpPackItem alloc] init];
        packItem.isRecv = NO;
        packItem.sendTimeSp = 0;
        packItem.seq = -1;
        [self.packArray addObject:packItem];
    }
}

- (void)printLost
{
    int packNum = 0;
    double delayTotal = 0;
    int sendPackNum = (int)_packArray.count;
    
    for (UdpPackItem *item in _packArray)
    {
        if (item.isRecv)
        {
            packNum++;
            double delay = item.recvTimeSp-item.sendTimeSp;
            //printf("--%f\n",delay);
            delayTotal+=delay;
        }
        else
        {
            //printf("有丢包 seq:%d\n",item.seq);
        }
        
        //reset
        item.isRecv = NO;
        item.sendTimeSp = 0;
        item.seq = -1;
        item.recvTimeSp = 0;
    }
    
    
    float diu = (float)(sendPackNum-packNum)/sendPackNum;
    NSString *showText = [NSString stringWithFormat:@"\n发%d包，收%d包 ,丢包%d ,丢包率%f 平均延时%f\n",sendPackNum,packNum,sendPackNum-packNum,diu,delayTotal/packNum];
    NSLog(@"%@",showText);
    [self updateState:showText];
    
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    if (textField.tag == 1000)
    {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if (textField.text.length > 0)
        {
            NSString *strNum = textField.text;
            int iNum = [strNum intValue];
            NSNumber *defaultNum = [NSNumber numberWithInt:iNum];
            [defaults setObject:defaultNum forKey:@"maxBuffer"];
            [defaults synchronize];
        }
        
    }
    return YES;
}

@end
