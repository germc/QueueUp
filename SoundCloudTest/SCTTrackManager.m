//
//  SCTSoundCloudData.m
//  SoundCloudTest
//
//  Created by Raunak Roy on 10/28/13.
//  Copyright (c) 2013 Raunak Roy. All rights reserved.
//

#import "SCTTrackManager.h"
#import <SCUI.h>
#import "BeamAVMusicPlayerProvider.h"
#import "BeamMusicPlayerViewController.h"
#import "SCTTrackDataObject.h"
#import <SDWebImage/SDWebImageManager.h>

#define FAVORITES_URL @"https://api.soundcloud.com/me/favorites.json"
#define BACKUP_URL @"https://api.soundcloud.com/users/13932803/favorites.json"

@interface SCTTrackManager()
@property (nonatomic,strong) NSArray* favorites;
@property (nonatomic, strong) NSDictionary* userData;
@property (nonatomic, strong) NSMutableArray* playQueue;
@property (nonatomic, strong) UIViewController* fromVC;
@property (nonatomic, strong) NSMutableDictionary* musicCache; //this is a bad bad thing but ok for demoing
@end

static SCTTrackManager* singleton;

@implementation SCTTrackManager

+ (SCTTrackManager*) sharedSingleton
{
    if(singleton == nil)
    {
        singleton = [[SCTTrackManager alloc] init];
    }
    
    return singleton;
}

- (id) init {
    
    if (self=[super init])
    {
        self.playQueue = [NSMutableArray array];
        self.musicCache = [NSMutableDictionary dictionary];
    }
    
    return self;
}

# pragma mark - Life Cycle

- (BOOL)isAvailable
{
    return ([SCSoundCloud account] != nil);
}

- (BOOL) canPlayMusic
{
    if( [self isAvailable] && self.playQueue && [self.playQueue count] > 0)
    {
        return YES;
    }
    
    return NO;
}

- (void) loginFrom:(UIViewController*)fromVC
{
    SCLoginViewControllerCompletionHandler handler = ^(NSError *error) {
        if (SC_CANCELED(error)) {
            NSLog(@"Canceled!");
            [[NSNotificationCenter defaultCenter] postNotificationName:LOGIN_CANCEL object:nil];
        } else if (error) {
            NSLog(@"Error: %@", [error localizedDescription]);
            [[NSNotificationCenter defaultCenter] postNotificationName:LOGIN_FAIL object:nil];
        } else {
            NSLog(@"Done!");
            [[NSNotificationCenter defaultCenter] postNotificationName:LOGIN_SUCCESS object:nil];
        }
    };
    
    [SCSoundCloud requestAccessWithPreparedAuthorizationURLHandler:^(NSURL *preparedURL) {
        SCLoginViewController *loginViewController;
        
        loginViewController = [SCLoginViewController
                               loginViewControllerWithPreparedURL:preparedURL
                               completionHandler:handler];
        
        [fromVC presentViewController:loginViewController animated:YES completion:nil];
    }];
}

- (void) logout
{
    [SCSoundCloud removeAccess];
}

# pragma mark - Data Handlers

- (void) setFavorites:(NSArray *)favorites
{
    NSMutableArray* newArr = [NSMutableArray array];
    for(NSDictionary* trackData in favorites)
    {
        if ([trackData objectForKey:@"stream_url"])
        {
            [newArr addObject:trackData];
        }
    }
    
    NSArray *sortedArray;
    sortedArray = [newArr sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        CGFloat firstDuration = [[(NSDictionary*)a objectForKey:@"duration"] floatValue];
        CGFloat secondDuration = [[(NSDictionary*)b objectForKey:@"duration"] floatValue];
        return [[NSNumber numberWithFloat:firstDuration] compare:[NSNumber numberWithFloat:secondDuration]];
    }];
    
    _favorites = sortedArray;
}

- (void) loadData
{
    if (![self isAvailable])
    {
        return;
    }
    self.favorites = nil;
    self.userData = nil;
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    
    [SCRequest  performMethod:SCRequestMethodGET
                   onResource:[NSURL URLWithString:@"https://api.soundcloud.com/me.json"]
              usingParameters:nil
                  withAccount:[SCSoundCloud account]
       sendingProgressHandler:nil
              responseHandler:^(NSURLResponse *response, NSData *data, NSError *error){
                  // Handle the response
                  if (error) {
                      NSLog(@"Ooops, something went wrong: %@", [error localizedDescription]);
                  } else {
                      // Check the statuscode and parse the data
                      NSError *jsonError = nil;
                      NSJSONSerialization *jsonResponse = [NSJSONSerialization
                                                           JSONObjectWithData:data
                                                           options:0
                                                           error:&jsonError];
                      if (!jsonError && [jsonResponse isKindOfClass:[NSDictionary class]]) {
                          self.userData = (NSDictionary*)jsonResponse;
                          NSLog(@"%@",jsonResponse);
                          [[NSNotificationCenter defaultCenter] postNotificationName:LOADED_USER object:self.userData];
                      }
                  }
              }];
    
    SCRequestResponseHandler handler;
    handler = ^(NSURLResponse *response, NSData *data, NSError *error) {
        NSError *jsonError = nil;
        NSJSONSerialization *jsonResponse = [NSJSONSerialization
                                             JSONObjectWithData:data
                                             options:0
                                             error:&jsonError];
        if (!jsonError && [jsonResponse isKindOfClass:[NSArray class]]) {
            
            self.favorites = (NSArray*)jsonResponse;
            if([self.favorites count] > 0)
            {
                [[NSNotificationCenter defaultCenter] postNotificationName:LOADED_FAVORITES object:self.favorites];
                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
            }
            else{
                [self loadBackupFavorites];
            }
        }
    };
    
    NSString *resourceURL = FAVORITES_URL;
    [SCRequest performMethod:SCRequestMethodGET
                  onResource:[NSURL URLWithString:resourceURL]
             usingParameters:nil
                 withAccount:[SCSoundCloud account]
      sendingProgressHandler:nil
             responseHandler:handler];
}

- (void) loadBackupFavorites
{
    SCRequestResponseHandler handler;
    handler = ^(NSURLResponse *response, NSData *data, NSError *error) {
        NSError *jsonError = nil;
        NSJSONSerialization *jsonResponse = [NSJSONSerialization
                                             JSONObjectWithData:data
                                             options:0
                                             error:&jsonError];
        if (!jsonError && [jsonResponse isKindOfClass:[NSArray class]]) {
            
            self.favorites = (NSArray*)jsonResponse;
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
            if([self.favorites count] > 0)
            {
                [[NSNotificationCenter defaultCenter] postNotificationName:LOADED_FAVORITES object:self.favorites];
            }
        }
    };
    
    NSString *resourceURL = BACKUP_URL;
    [SCRequest performMethod:SCRequestMethodGET
                  onResource:[NSURL URLWithString:resourceURL]
             usingParameters:nil
                 withAccount:[SCSoundCloud account]
      sendingProgressHandler:nil
             responseHandler:handler];
}

- (NSArray*) getFavorites
{
    return self.favorites;
}

- (NSDictionary*) getUserData
{
    return self.userData;
}

# pragma mark - Audio Handlers

- (void) showPlayerFromView: (UIViewController*) view
{
    self.fromVC = view;
    SCTTrackManager* weakSelf = self;
    self.controller.backBlock = ^{
        [weakSelf.controller dismissViewControllerAnimated:YES completion:nil];
    };
    
    [self.fromVC presentViewController:self.controller
                             animated:YES
                            completion:^(void){
                                [self.controller reloadData];
                            }];
}

- ( void) playTrack:(NSDictionary*) trackData
{
    [self playTrack:trackData immediately:NO];
}

- ( void) playTrack:(NSDictionary*) trackData immediately:(BOOL)playImmediately
{
    
    if(!playImmediately && (self.trackDescription == trackData || [self.playQueue containsObject:trackData]))
    {
        return;
    }
    
    [self.playQueue addObject:trackData];
    
    if(playImmediately || (!self.audioPlayer.playing && self.trackDescription == nil))
    {
        [self loadAndPlayTrack:trackData];
        self.controller.currentTrack = [self.playQueue indexOfObject:trackData];
    }
}

- (void) loadAndPlayTrack: (NSDictionary*) trackData
{
    self.trackDescription = trackData;
    
    if([self.controller playing])
    {
        [self.controller pause];
    }
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    
    NSString *streamURL = [trackData objectForKey:@"stream_url"];
    
    NSData* existing = [self.musicCache objectForKey:streamURL];
    
    void (^playBlock)(NSData*) = ^void(NSData* data){
        NSError* error;
        if(self.controller == nil)
        {
            self.controller = [BeamMusicPlayerViewController new];
            self.controller.dataSource = self;
            self.controller.delegate = self;
        }else{
            [self.controller stop];
            
        }
        [self.controller reloadData];
        
        self.audioPlayer = [[AVAudioPlayer alloc] initWithData:data error:&error];
        [self.audioPlayer prepareToPlay];
        [[NSNotificationCenter defaultCenter] postNotificationName:STARTED_PLAYING object:nil];
        [self.controller play];
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    };
    
    if(existing != nil)
    {
        playBlock(existing);
        return;
    }
    
    [SCRequest performMethod:SCRequestMethodGET
                  onResource:[NSURL URLWithString:streamURL]
             usingParameters:nil
                 withAccount:[SCSoundCloud account]
      sendingProgressHandler:nil
             responseHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                 if(![self.musicCache objectForKey:streamURL])
                 {
                     [self.musicCache setValue:data forKey:streamURL];
                 }
                 playBlock(data);
             }];
}

# pragma mark - Audio Player lifecycle/delegate/datasource

-(void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    
    if([self.playQueue count] > 0)
    {
        [self.controller next];
        return;
    }
    
    [self.controller stop];
    self.trackDescription = nil;
    self.audioPlayer = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:FINISHED_PLAYING object:nil];
}

-(NSString *)musicPlayer:(BeamMusicPlayerViewController *)player artistForTrack:(NSUInteger)trackNumber {
    
    return [self.playQueue objectAtIndex:trackNumber][@"artist"];
}

-(NSString *)musicPlayer:(BeamMusicPlayerViewController *)player titleForTrack:(NSUInteger)trackNumber {
    
    SCTTrackDataObject* trackData = [[SCTTrackDataObject alloc] initWithData:[self.playQueue objectAtIndex:trackNumber]];
    
    return [trackData getTitle];
}

-(NSString *)musicPlayer:(BeamMusicPlayerViewController *)player albumForTrack:(NSUInteger)trackNumber {

    return [self.playQueue objectAtIndex:trackNumber][@"album"];
}

-(CGFloat)musicPlayer:(BeamMusicPlayerViewController *)player lengthForTrack:(NSUInteger)trackNumber {

    return [[self.playQueue objectAtIndex:trackNumber][@"duration"] floatValue] / 1000.0f;
}

-(void)musicPlayerDidStartPlaying:(BeamMusicPlayerViewController *)player {
    [self.audioPlayer play];
}

-(void)musicPlayerDidStopPlaying:(BeamMusicPlayerViewController *)player {
    [self.audioPlayer pause];
}

-(void)musicPlayer:(BeamMusicPlayerViewController *)player didSeekToPosition:(CGFloat)position {
    self.audioPlayer.currentTime = position;
}

-(void)musicPlayer:(BeamMusicPlayerViewController *)player artworkForTrack:(NSUInteger)trackNumber receivingBlock:(BeamMusicPlayerReceivingBlock)receivingBlock {
    
    SCTTrackDataObject* trackData = [[SCTTrackDataObject alloc] initWithData:[self.playQueue objectAtIndex:trackNumber]];

    
    id urlValue = [trackData getArtworkUrl];
    if(urlValue) {
        SDWebImageManager *manager = [SDWebImageManager sharedManager];
        [manager downloadWithURL:[NSURL URLWithString:urlValue]
                         options:0
                        progress:nil
                       completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished) {
                                 if (image)
                                 {
                                     // do something with image
                                     receivingBlock(image,nil);
                                 }
         }];
    }
}

-(CGFloat)musicPlayer:(BeamMusicPlayerViewController*)player currentPositionForTrack:(NSUInteger)trackNumber
{
    return [self.audioPlayer currentTime];
}

-(NSInteger)numberOfTracksInPlayer:(BeamMusicPlayerViewController *)player {
    NSInteger count = 0;
    
    if(self.playQueue)
    {
        count += [self.playQueue count];
    }
    return count;
}

-(NSInteger)musicPlayer:(BeamMusicPlayerViewController*)player didChangeTrack:(NSUInteger)track
{
    if(self.playQueue && track < [self.playQueue count])
    {
        NSDictionary* nextTrack = [self.playQueue objectAtIndex:track];
        [self loadAndPlayTrack:nextTrack];
    }
    return track;
}


@end