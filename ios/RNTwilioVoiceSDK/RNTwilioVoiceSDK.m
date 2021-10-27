//
//  RNTwilioVoiceSDK.m
//

#import "RNTwilioVoiceSDK.h"
#import <React/RCTLog.h>

@import AVFoundation;
@import TwilioVoice;

@interface RNTwilioVoiceSDK () <TVOCallDelegate>

@property (nonatomic, strong) TVOCall *call;
@property (nonatomic,strong)AVAudioPlayer *player;
@end

@implementation RNTwilioVoiceSDK {
}

NSString * const StateConnecting = @"CONNECTING";
NSString * const StateConnected = @"CONNECTED";
NSString * const StateDisconnected = @"DISCONNECTED";
NSString * const StateReconnecting = @"RECONNECTING";
NSString * const StateRinging = @"RINGING";

- (dispatch_queue_t)methodQueue
{
  return dispatch_get_main_queue();
}

RCT_EXPORT_MODULE()

- (NSArray<NSString *> *)supportedEvents
{
  return @[@"ringing", @"connect", @"connectFailure", @"reconnecting", @"reconnect", @"disconnect"];
}

@synthesize bridge = _bridge;

- (void)dealloc {
    if(self.call) {
        [self disconnect];
    }
}

RCT_REMAP_METHOD(connect,
                 accessToken:(NSString *)accessToken
                 options:(NSDictionary *)options
                 connectResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject) {
//  NSLog(@"Calling phone number %@", [params valueForKey:@"To"]);
//  [TwilioVoice setLogLevel:TVOLogLevelVerbose];

  if (self.call) {
//    [self.call disconnect];
    reject(@"already_connected",@"Calling connect while a call is connected",nil);
  } else {
      [self enableProximityMonitoring];

      NSUUID *uuid = [NSUUID UUID];
      TVOConnectOptions *connectOptions = [TVOConnectOptions optionsWithAccessToken:accessToken
                                                                              block:^(TVOConnectOptionsBuilder *builder) {
                                                                                  builder.params = options;
                                                                                  builder.uuid = uuid;
//                                                                                  builder.region = region;
//                                                                                  builder.iceOptions = ;
//                                                                                  builder.preferredAudioCodecs = ;
//                                                                                  builder.delegateQueue = ;

                                                                              }];

      self.call = [TwilioVoice connectWithOptions:connectOptions delegate:self];
      NSMutableDictionary *params = [self callParamsFor:self.call];
      @try {
        NSError *error;
        NSURL *fileNameUrl;
        AVAudioPlayer *player;
        
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSURL* ringSound = [bundle URLForResource:@"dial_2" withExtension:@"mp3"];
        self.player = [[AVAudioPlayer alloc]initWithContentsOfURL:ringSound error:NULL];
        self.player.numberOfLoops = -1; //Infinite
        [self.player play];
      }
      @catch (NSException *exception) {
          NSLog(@"%@", exception.reason);
      }
      resolve(params);
    // [self performStartCallActionWithUUID:uuid handle:handle];
  }
}

RCT_EXPORT_METHOD(disconnect) {
  NSLog(@"Disconnecting call");
    self.call.muted = false;
    [self toggleAudioRoute:false];
    [self disableProximityMonitoring];
    [self.player stop];
    [self.call disconnect];
}

RCT_EXPORT_METHOD(setMuted: (BOOL *)muted) {
  NSLog(@"Mute/UnMute call");
  self.call.muted = muted;
}

RCT_EXPORT_METHOD(setSpeakerPhone: (BOOL *)speaker) {
  [self toggleAudioRoute:speaker];
}

RCT_EXPORT_METHOD(sendDigits: (NSString *)digits){
  if (self.call && self.call.state == TVOCallStateConnected) {
    NSLog(@"SendDigits %@", digits);
    [self.call sendDigits:digits];
  }
}

RCT_REMAP_METHOD(getVersion,
                 getVersionResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject){
  resolve(TwilioVoice.sdkVersion);
}

RCT_REMAP_METHOD(getActiveCall,
                 activeCallResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject){

  if (self.call) {
    NSMutableDictionary *params = [self callParamsFor:self.call];
    resolve(params);
  } else{
    reject(@"no_call", @"There was no active call", nil);
  }
}

- (NSString *)callStateFor:(TVOCall *)call {
    if (call.state == TVOCallStateConnected) {
        return StateConnected;
    } else if (call.state == TVOCallStateConnecting) {
        return StateConnecting;
    } else if (call.state == TVOCallStateDisconnected) {
        return StateDisconnected;
    } else if (call.state == TVOCallStateReconnecting) {
        return StateReconnecting;
    } else if (call.state == TVOCallStateRinging) {
        return StateRinging;
    }
    return @"INVALID";
}

- (NSMutableDictionary *)callParamsFor:(TVOCall *)call {
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    if (call.sid) {
        [params setObject:call.sid forKey:@"sid"];
    }
    if (call.to){
        [params setObject:call.to forKey:@"to"];
    }
    if (call.from){
        [params setObject:call.from forKey:@"from"];
    }
    [params setObject:[self callStateFor:call] forKey:@"state"];
    return params;
}

- (NSMutableDictionary *)paramsForError:(NSError *)error {
    NSMutableDictionary *params = [self callParamsFor:self.call];

    if (error) {
        NSMutableDictionary *errorParams = [[NSMutableDictionary alloc] init];
        if (error.code) {
            [errorParams setObject:[@([error code]) stringValue] forKey:@"code"];
        }
        if (error.domain) {
            [errorParams setObject:[error domain] forKey:@"domain"];
        }
        if (error.localizedDescription) {
            [errorParams setObject:[error localizedDescription] forKey:@"message"];
        }
        if (error.localizedFailureReason) {
            [errorParams setObject:[error localizedFailureReason] forKey:@"reason"];
        }
        [params setObject:errorParams forKey:@"error"];
    }
    return params;
}

- (void)enableProximityMonitoring {
    // Enable Proximity monitoring
    UIDevice* device = [UIDevice currentDevice];
    device.proximityMonitoringEnabled = YES;
}

- (void)disableProximityMonitoring {
    // Enable Proximity monitoring
    UIDevice* device = [UIDevice currentDevice];
    device.proximityMonitoringEnabled = NO;
}

#pragma mark - TVOCallDelegate
//return @[@"ringing", @"connected", @"connectFailure", @"reconnecting", @"reconnected", @"disconnected"];

- (void)callDidConnect:(TVOCall *)call {
  self.call = call;
  [self.player stop];
  NSMutableDictionary *callParams = [self callParamsFor:call];
  [self sendEventWithName:@"connect" body:callParams];
}

- (void)call:(TVOCall *)call didFailToConnectWithError:(NSError *)error {
  NSLog(@"Call failed to connect: %@", error);

  self.call = call;
  NSMutableDictionary *callParams = [self paramsForError:error];
  [self sendEventWithName:@"connectFailure" body:callParams];
  [self.player stop];
  [self disconnect];
  self.call = nil;
}

- (void)call:(TVOCall *)call didDisconnectWithError:(NSError *)error {
  NSLog(@"Call disconnected with error: %@", error);

  self.call = call;
  NSMutableDictionary *callParams = [self paramsForError:error];
  [self sendEventWithName:@"disconnect" body:callParams];
  [self disconnect];
  self.call = nil;
}

- (void)callDidStartRinging:(TVOCall *)call {
  self.call = call;

  NSMutableDictionary *callParams = [self callParamsFor:call];
  [self sendEventWithName:@"ringing" body:callParams];
}

- (void)call:(TVOCall *)call isReconnectingWithError:(NSError *)error {
  NSLog(@"Call is reconnecting with error: %@", error);

  self.call = call;
  NSMutableDictionary *callParams = [self paramsForError:error];
  [self sendEventWithName:@"reconnecting" body:callParams];
}

- (void)callDidReconnect:(TVOCall *)call {
  self.call = call;

  NSMutableDictionary *callParams = [self callParamsFor:call];
  [self sendEventWithName:@"reconnect" body:callParams];
}

#pragma mark - AVAudioSession
- (void)toggleAudioRoute: (BOOL *)toSpeaker {
  // The mode set by the Voice SDK is "VoiceChat" so the default audio route is the built-in receiver.
  // Use port override to switch the route.
  NSError *error = nil;
  NSLog(@"toggleAudioRoute");

  if (toSpeaker) {
    [self disableProximityMonitoring];
    if (![[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker
                                                            error:&error]) {
      NSLog(@"Unable to reroute audio: %@", [error localizedDescription]);
      [self enableProximityMonitoring];
    }
  } else {
    [self enableProximityMonitoring];
    if (![[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone
                                                            error:&error]) {
      NSLog(@"Unable to reroute audio: %@", [error localizedDescription]);
      [self disableProximityMonitoring];
    }
  }
}

@end
