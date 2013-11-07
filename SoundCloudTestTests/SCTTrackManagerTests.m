//
//  SCTTrackManagerTests.m
//  SoundCloudTest
//
//  Created by Raunak Roy on 11/1/13.
//  Copyright (c) 2013 Raunak Roy. All rights reserved.
//
#import <XCTest/XCTest.h>
#import "SCTTrackManager.h"

@interface SCTTrackManagerTests : XCTestCase
@end


@implementation SCTTrackManagerTests

- (void) setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void) testLogin
{
    XCTAssertTrue([[SCTTrackManager sharedSingleton] isAvailable], @"Need a SC auth token to run tests!");
    //this test fails some times randomly.. looks like hitting the login api repeatedly might not work out
    
    //hmmm some weird issues with the oathaccountstore and setting a token to persistent..
}

- (void) testLoadUserData
{
    __block bool finished = false;
    
    [[SCTTrackManager sharedSingleton] loadUserDataWithHandler:^(NSURLResponse *response, NSData *data, NSError *error){
        // Handle the response
        XCTAssertNil(error, @"There should be no error");
        // Check the statuscode and parse the data
        NSError *jsonError = nil;
        NSJSONSerialization *jsonResponse = [NSJSONSerialization
                                             JSONObjectWithData:data
                                             options:0
                                             error:&jsonError];
        XCTAssertNil(jsonError, @"There should be no error");
        
        XCTAssertTrue([jsonResponse isKindOfClass:[NSDictionary class]],@"jsonResponse should be dict");

        NSLog(@"%@",jsonResponse);
        finished = true;
    }];

    // loop until the flag is set from inside the task
    while (!finished) {
        // spend 1 second processing events on each loop
        NSDate *oneSecond = [NSDate dateWithTimeIntervalSinceNow:1];
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:oneSecond];
    }
}

- (void) testLoadFavorites
{
    __block bool finished = false;
    
    [[SCTTrackManager sharedSingleton] loadFavoritesWithHandler:^(NSURLResponse *response, NSData *data, NSError *error){
        // Handle the response
        XCTAssertNil(error, @"There should be no error");
        // Check the statuscode and parse the data
        NSError *jsonError = nil;
        NSJSONSerialization *jsonResponse = [NSJSONSerialization
                                             JSONObjectWithData:data
                                             options:0
                                             error:&jsonError];
        XCTAssertNil(jsonError, @"There should be no error");
        
        XCTAssertTrue([jsonResponse isKindOfClass:[NSArray class]],@"jsonResponse should be array");

        NSLog(@"%@",jsonResponse);
        finished = true;
    }];
    
    // loop until the flag is set from inside the task
    while (!finished) {
        // spend 1 second processing events on each loop
        NSDate *oneSecond = [NSDate dateWithTimeIntervalSinceNow:1];
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:oneSecond];
    }
}

- (void) testQueuing
{
    NSArray* favorites = [[SCTTrackManager sharedSingleton] getFavorites];
    
    XCTAssertTrue(favorites != nil, @"Favorites should have been loaded in previous test");
    
    NSDictionary* trackOne = [favorites objectAtIndex:0];
    NSDictionary* trackTwo = [favorites objectAtIndex:1];
    
    [[SCTTrackManager sharedSingleton] playTrack:trackOne];
    
    XCTAssertTrue([[[SCTTrackManager sharedSingleton] playQueue] count] > 0, @"Player should have queued: %@", [trackOne objectForKey:@"title"]);
    
    [[SCTTrackManager sharedSingleton] playTrack:trackTwo immediately:YES]; //will launch safari/sc app
    
    XCTAssertTrue([[[SCTTrackManager sharedSingleton] playQueue] count] == 1, @"Player should only have queued: %@", [trackOne objectForKey:@"title"]);
    
    NSArray* playQueue = [[SCTTrackManager sharedSingleton] playQueue];
    
    NSDictionary* queuedTrack = [playQueue objectAtIndex:0];
    NSString* queuedTitle = [queuedTrack objectForKey:@"title"];
    
    XCTAssertTrue([queuedTitle isEqualToString:[trackOne objectForKey:@"title"]], @"Only trackone should be in queue");
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

@end
