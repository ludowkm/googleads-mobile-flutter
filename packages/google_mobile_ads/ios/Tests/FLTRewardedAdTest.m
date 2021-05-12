// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "../Classes/FLTAdInstanceManager_Internal.h"
#import "../Classes/FLTAd_Internal.h"

@interface FLTRewardedAdTest : XCTestCase
@end

@implementation FLTRewardedAdTest {
  FLTAdInstanceManager *mockManager;
}

- (void)setUp {
  mockManager = (OCMClassMock([FLTAdInstanceManager class]));
}

- (void)testLoadShowRewardedAdGADRequest {
  FLTAdRequest *request = OCMClassMock([FLTAdRequest class]);
  OCMStub([request keywords]).andReturn(@[ @"apple" ]);
  GADRequest *gadRequest = OCMClassMock([GADRequest class]);
  OCMStub([request asGADRequest]).andReturn(gadRequest);
  FLTServerSideVerificationOptions *serverSideVerificationOptions =
    OCMClassMock([FLTServerSideVerificationOptions class]);
  GADServerSideVerificationOptions *gadOptions =
    OCMClassMock([GADServerSideVerificationOptions class]);
  OCMStub([serverSideVerificationOptions asGADServerSideVerificationOptions])
    .andReturn(gadOptions);
  
  [self testLoadShowRewardedAd:request
               gadOrGAMRequest:gadRequest
   serverSideVerificationOptions:serverSideVerificationOptions];
}

- (void)testLoadShowRewardedAdGAMRequest {
  FLTGAMAdRequest *request = OCMClassMock([FLTGAMAdRequest class]);
  OCMStub([request keywords]).andReturn(@[ @"apple" ]);
  GAMRequest *gamRequest = OCMClassMock([GAMRequest class]);
  OCMStub([request asGAMRequest]).andReturn(gamRequest);
  FLTServerSideVerificationOptions *serverSideVerificationOptions =
    OCMClassMock([FLTServerSideVerificationOptions class]);
  GADServerSideVerificationOptions *gadOptions =
    OCMClassMock([GADServerSideVerificationOptions class]);
  OCMStub([serverSideVerificationOptions asGADServerSideVerificationOptions])
    .andReturn(gadOptions);

  [self testLoadShowRewardedAd:request
               gadOrGAMRequest:gamRequest
   serverSideVerificationOptions:serverSideVerificationOptions];
}

// Helper method for testing with FLTAdRequest and FLTGAMAdRequest.
- (void)testLoadShowRewardedAd:(FLTAdRequest *)request
               gadOrGAMRequest:(GADRequest *)gadOrGAMRequest
 serverSideVerificationOptions:(FLTServerSideVerificationOptions *)options {
  UIViewController *mockRootViewController = OCMClassMock([UIViewController class]);
  FLTRewardedAd *ad =
      [[FLTRewardedAd alloc] initWithAdUnitId:@"testId"
                                          request:request
                               rootViewController:mockRootViewController
       serverSideVerificationOptions:options];
  ad.manager = mockManager;
  
  // Stub the load call to invoke successful load callback.
  id rewardedClassMock = OCMClassMock([GADRewardedAd class]);
  OCMStub(ClassMethod([rewardedClassMock loadWithAdUnitID:[OCMArg any]
                                                      request:[OCMArg any]
                                            completionHandler:[OCMArg any]]))
    .andDo(^(NSInvocation *invocation) {
      void (^completionHandler)(GADRewardedAd *ad, NSError *error);
      [invocation getArgument:&completionHandler atIndex:4];
      completionHandler(rewardedClassMock, nil);
    });
  // Stub setting of FullScreenContentDelegate to invoke delegate callbacks.
  NSError *error = OCMClassMock([NSError class]);
  OCMStub([rewardedClassMock setFullScreenContentDelegate:[OCMArg any]])
  .andDo(^(NSInvocation *invocation) {
    id<GADFullScreenContentDelegate> delegate;
    [invocation getArgument:&delegate atIndex:2];
    XCTAssertEqual(delegate, ad);
    [delegate adDidRecordImpression:rewardedClassMock];
    [delegate adDidDismissFullScreenContent:rewardedClassMock];
    [delegate adDidPresentFullScreenContent:rewardedClassMock];
    [delegate adWillDismissFullScreenContent:rewardedClassMock];
    [delegate ad:rewardedClassMock didFailToPresentFullScreenContentWithError:error];
  });
  GADResponseInfo *responseInfo = OCMClassMock([GADResponseInfo class]);
  OCMStub([rewardedClassMock responseInfo]).andReturn(responseInfo);
  // Stub presentFromRootViewController to invoke reward callback.
  GADAdReward *mockReward = OCMClassMock([GADAdReward class]);
  OCMStub([mockReward amount]).andReturn(@1.0);
  OCMStub([mockReward type]).andReturn(@"type");
  OCMStub([rewardedClassMock adReward]).andReturn(mockReward);
  OCMStub([rewardedClassMock presentFromRootViewController:[OCMArg any]
                                  userDidEarnRewardHandler:[OCMArg any]])
  .andDo(^(NSInvocation *invocation) {
    GADUserDidEarnRewardHandler rewardHandler;
    [invocation getArgument:&rewardHandler atIndex:3];
    rewardHandler();
  });
  // Prevent calls to setServerSideVerificationOptions if options is nil.
  if (options == nil) {
    OCMReject([rewardedClassMock setServerSideVerificationOptions:[OCMArg any]]);
  }
  [ad load];

  OCMVerify(ClassMethod([rewardedClassMock loadWithAdUnitID:[OCMArg isEqual:@"testId"]
                                                    request:[OCMArg isEqual:gadOrGAMRequest]
                                          completionHandler:[OCMArg any]]));
  OCMVerify([mockManager onAdLoaded:[OCMArg isEqual:ad] responseInfo:[OCMArg isEqual:responseInfo]]);
  OCMVerify([rewardedClassMock setFullScreenContentDelegate:[OCMArg isEqual:ad]]);
  XCTAssertEqual(ad.rewardedAd, rewardedClassMock);
  if (options != nil) {
    GADServerSideVerificationOptions *gadOptions = [options asGADServerSideVerificationOptions];
    OCMVerify([rewardedClassMock setServerSideVerificationOptions:
               [OCMArg isEqual:gadOptions]]);
  }
  
  [ad show];
  
  OCMVerify([rewardedClassMock
             presentFromRootViewController:[OCMArg isEqual:mockRootViewController]
             userDidEarnRewardHandler:[OCMArg any]]);
  
  // Verify full screen callbacks.
  OCMVerify([mockManager onAdDidPresentFullScreenContent:[OCMArg isEqual:ad]]);
  OCMVerify([mockManager adDidDismissFullScreenContent:[OCMArg isEqual:ad]]);
  OCMVerify([mockManager adWillDismissFullScreenContent:[OCMArg isEqual:ad]]);
  OCMVerify([mockManager adDidRecordImpression:[OCMArg isEqual:ad]]);
  OCMVerify([mockManager
             didFailToPresentFullScreenContentWithError:[OCMArg isEqual:ad]
             error: [OCMArg isEqual:error]]);
  
  // Verify reward callback.
  OCMVerify([mockManager
             onRewardedAdUserEarnedReward:[OCMArg isEqual:ad]
             reward:[OCMArg checkWithBlock: ^BOOL(id obj) {
    FLTRewardItem *reward = (FLTRewardItem *)obj;
    XCTAssertEqual(reward.amount, @1.0);
    XCTAssertEqual(reward.type, @"type");
    return true;
  }]]);
}

- (void)testFailedToLoadGADRequest {
  FLTAdRequest *request = OCMClassMock([FLTAdRequest class]);
  OCMStub([request keywords]).andReturn(@[ @"apple" ]);
  GADRequest *gadRequest = OCMClassMock([GADRequest class]);
  OCMStub([request asGADRequest]).andReturn(gadRequest);
  [self testFailedToLoad:request];
}

- (void)testFailedToLoadGAMRequest {
  FLTGAMAdRequest *request = OCMClassMock([FLTGAMAdRequest class]);
  OCMStub([request keywords]).andReturn(@[ @"apple" ]);
  GAMRequest *gamRequest = OCMClassMock([GAMRequest class]);
  OCMStub([request asGAMRequest]).andReturn(gamRequest);
  [self testFailedToLoad:request];
}

// Helper for testing failed to load.
- (void)testFailedToLoad:(FLTAdRequest *)request {
  UIViewController *mockRootViewController = OCMClassMock([UIViewController class]);
  FLTRewardedAd *ad =
      [[FLTRewardedAd alloc] initWithAdUnitId:@"testId"
                                          request:request
                               rootViewController:mockRootViewController
                    serverSideVerificationOptions:nil];
  ad.manager = mockManager;
  
  id rewardedClassMock = OCMClassMock([GADRewardedAd class]);
  NSError *error = OCMClassMock([NSError class]);
  OCMStub(ClassMethod([rewardedClassMock loadWithAdUnitID:[OCMArg any]
                                                  request:[OCMArg any]
                                        completionHandler:[OCMArg any]]))
    .andDo(^(NSInvocation *invocation) {
      void (^completionHandler)(GADRewardedAd *ad, NSError *error);
      [invocation getArgument:&completionHandler atIndex:4];
      completionHandler(nil, error);
    });

  [ad load];

  OCMVerify(ClassMethod([rewardedClassMock loadWithAdUnitID:[OCMArg any]
                                                    request:[OCMArg any]
                                          completionHandler:[OCMArg any]]));
  OCMVerify([mockManager onAdFailedToLoad:[OCMArg isEqual:ad]
                                    error:[OCMArg isEqual:error]]);
}

- (void)testServerSideVerificationOptionsNil {
  FLTAdRequest *request = OCMClassMock([FLTAdRequest class]);
  OCMStub([request keywords]).andReturn(@[ @"apple" ]);
  GADRequest *gadRequest = OCMClassMock([GADRequest class]);
  OCMStub([request asGADRequest]).andReturn(gadRequest);
  [self testLoadShowRewardedAd:request
               gadOrGAMRequest:gadRequest
   serverSideVerificationOptions:nil];
}

@end

