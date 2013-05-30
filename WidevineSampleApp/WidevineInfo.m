//
//  WidevineInfo.m
//  WidevinePlugin
//
//  Created by David McGaffin on 9/26/12.
//
//

#import "WViPhoneAPI.h"
#import "BCVideo.h"
#import "BCEvent.h"
#import "BCWidevinePlugin.h"
#import "UIScrollView+SVPullToRefresh.h"
#import "Constants.h"
#import "WidevineInfo.h"
@interface WidevineInfo()
@property (nonatomic, strong) AFHTTPClient * httpClient;
@end

@implementation WidevineInfo

@synthesize widevinePlugin;
@synthesize widevineInfoView;
@synthesize videoCell = _videoCell;
@synthesize tableView = _tableView;

- (id)init
{
    return nil;
}

- (id)initWithEventEmitter:(BCEventEmitter *)eventEmitter
                    plugin:(BCWidevinePlugin *)plugin
{
    if (self = [super initWithEventEmitter:eventEmitter]) {
        [[NSBundle mainBundle] loadNibNamed:@"WidevineInfo_iphone" owner:self options:nil];
        
        self.widevinePlugin = plugin;
        
        __block WidevineInfo * weakSelf = self;
        [self.tableView addPullToRefreshWithActionHandler:^{
            [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:BCWidevinePluginRefreshPlaylist
                                                                                                 object:weakSelf]];
            weakSelf.widevinePlugin.autoPlay = NO;
            [weakSelf.tableView.pullToRefreshView stopAnimating];
        }];
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(reloadPlaylist) name:BCWidevinePluginDidRefreshPlaylist object:nil];
        [nc addObserver:self selector:@selector(selectVideo:) name:BCWidevinePluginDidSetVideo object:nil];
    }
    
    return self;
}

- (void)dealloc
{
    self.widevineInfoView = nil;
    self.widevinePlugin = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)reloadPlaylist
{
    [self.tableView reloadData];
    [self.tableView.pullToRefreshView stopAnimating];
    
    [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
                                animated:YES
                          scrollPosition:UITableViewScrollPositionTop];
}

- (void)selectVideo:(NSNotification *)notification
{
    BCVideo *video = [notification.userInfo objectForKey:@"video"];
    NSUInteger row = [self.widevinePlugin.playlist.videos indexOfObject:video];
    [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]
                                animated:YES
                          scrollPosition:UITableViewScrollPositionMiddle];
}


#pragma mark - UITableView Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.widevinePlugin.playlist.videos count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 80;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	// Try to retrieve from the table view a now-unused cell with the given identifier.
	VideoViewCell *cell = (VideoViewCell *)[tableView dequeueReusableCellWithIdentifier:[VideoViewCell reuseIdentifier]];
	
	// If no cell is available, create a new one using the given identifier.
	if (cell == nil) {
        [[NSBundle mainBundle] loadNibNamed:@"VideoViewCell" owner:self options:nil];
        cell = _videoCell;
        _videoCell = nil;
	}
	
	// Set up the cell.
	BCVideo *video = [self.widevinePlugin.playlist.videos objectAtIndex:indexPath.row];
    NSURL *stillUrl = [video.properties objectForKey:@"videoStillURL"];
    NSData *imageData = [NSData dataWithContentsOfURL:stillUrl];
    cell.videoStill.image = [UIImage imageWithData:imageData];
	cell.videoNameLabel.text = [video.properties objectForKey:@"name"];
    cell.durationLabel.text = [self hmsForDuration:[video.properties objectForKey:@"duration"]];
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    BCVideo *video = [self.widevinePlugin.playlist.videos objectAtIndex:indexPath.row];
    NSDictionary *renditionSet = [self renditionDictionaryFromBCVideo:video];
    if (renditionSet == nil)
        return;
    
    NSNumber *videoDuration = [renditionSet objectForKey:@"videoDuration"];
    NSString *durationString = [self hmsForDuration:videoDuration];
    
    NSString *fullSizeBytes = [renditionSet objectForKey:@"size"];
    NSString *sizeString = [NSString stringWithFormat:@"%dMB", [fullSizeBytes integerValue] / 1024 / 1024];
    
    NSString *videoContainer = [renditionSet objectForKey:@"videoContainer"];
    NSString *videoCodec = [renditionSet objectForKey:@"videoCodec"];
    NSString *videoInfo = [NSString stringWithFormat:@"Duration: %@\nSize: %@\nContainer: %@\nCodec: %@", durationString, sizeString, videoContainer, videoCodec];
    
    [WCAlertView showAlertWithTitle:@"Play video"
                            message:videoInfo
                 customizationBlock:nil
                    completionBlock:^(NSUInteger buttonIndex, WCAlertView *alertView) {
                        
                        NSString * buttonTitle = [[alertView buttonTitleAtIndex:buttonIndex] lowercaseString];
                        if ([buttonTitle isEqualToString:@"play online"])    [self playVideoOnline:video];
                        if ([buttonTitle isEqualToString:@"play offline"])   [self playVideoOffline:video];
                        if ([buttonTitle isEqualToString:@"download"])       [self downloadVideo:video];
                        
                    } cancelButtonTitle:nil
                  otherButtonTitles:@"Download", @"Play online", @"Play offline", nil];
}




#pragma mark - Helpers

- (NSString *)hmsForDuration:(NSNumber *)duration
{
    unsigned long seconds = duration.unsignedLongValue / 1000;
    NSUInteger h = seconds / 3600;
    NSUInteger m = (seconds / 60) % 60;
    NSUInteger s = (seconds % 60);
    
    return [NSString stringWithFormat:@"%u:%02u:%02u", h, m, s];
}

- (NSDictionary*)renditionDictionaryFromBCVideo:(BCVideo *)video
{
    if ([video.properties objectForKey:@"WVMRenditions"] == nil)
        return nil;
    NSArray *WVMRenditions = [video.properties objectForKey:@"WVMRenditions"];
    if ([WVMRenditions count] <= 0)
        return nil;
    NSDictionary *renditionSet = [WVMRenditions objectAtIndex:0];
    return renditionSet;
}

- (BCVideo *)constructBCVideoWithNewUrl:(NSString *)url fromVideo:(BCVideo *)video
{
    NSMutableDictionary *renditionSet = [[self renditionDictionaryFromBCVideo:video] mutableCopy];
    if (renditionSet == nil)
        return nil;
    
    [renditionSet setObject:url forKey:@"url"];
    
    NSArray *WVMRenditions = @[renditionSet];
    NSMutableDictionary *properties = [video.properties mutableCopy];
    [properties setObject:WVMRenditions forKey:@"WVMRenditions"];
    
    BCVideo *newVideo = [BCVideo videoWithURL:[NSURL URLWithString:url] properties:properties];
    return newVideo;
}



#pragma mark - Offline

- (void)playVideoOnline:(BCVideo *)video
{
    self.widevinePlugin.autoPlay = YES;
    [self.widevinePlugin queueVideo:video];
}

- (void)playVideoOffline:(BCVideo *)video
{
    NSDictionary *renditionSet = [self renditionDictionaryFromBCVideo:video];
    if (renditionSet == nil)
        return;

    NSString *fullVideoUrl = [renditionSet objectForKey:@"url"];
    if ([fullVideoUrl length] <= 0) {
        [SVProgressHUD showErrorWithStatus:@"Invalid video URL"];
        return;
    }
    
    //Download large file
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *localPath = [[paths objectAtIndex:0] stringByAppendingPathComponent:[fullVideoUrl md5]];
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:localPath];
    
    if (fileExists == NO) {
        [SVProgressHUD showErrorWithStatus:@"This file has not been downloaded yet"];
        return;
    }
    
    BCVideo *localVideo = [self constructBCVideoWithNewUrl:localPath fromVideo:video];
    self.widevinePlugin.autoPlay = YES;
    [self.widevinePlugin queueVideo:localVideo];
}

- (void)downloadVideo:(BCVideo *)video
{
    NSDictionary *renditionSet = [self renditionDictionaryFromBCVideo:video];
    if (renditionSet == nil)
        return;
    
    NSString *fullVideoUrl = [renditionSet objectForKey:@"url"];
    if ([fullVideoUrl length] <= 0) {
        [SVProgressHUD showErrorWithStatus:@"Invalid video URL"];
        return;
    }
    
    //Download large file
    [self downloadRemoteFile:fullVideoUrl progress:^(CGFloat percent, long long totalBytesExpected, long long totalBytesReadForFile) {
        
        NSString *statusString = [NSString stringWithFormat:@"%.0f%%\n %lldMB/%lldMB", percent, totalBytesReadForFile/1024/1024, totalBytesExpected/1024/1024];
        [SVProgressHUD showProgress:percent status:statusString];
        
    } success:^(NSString *localPath) {
        [SVProgressHUD showSuccessWithStatus:@"Done!"];
    } failure:^(NSError *error) {
        [SVProgressHUD showErrorWithStatus:@"Failed to download"];
    }];
}

//Download large file
- (void)downloadRemoteFile:(NSString *)url
                  progress:(void (^)(CGFloat percent, long long totalBytesExpected, long long totalBytesReadForFile))progress
                   success:(void (^)(NSString *localPath))success
                   failure:(void (^)(NSError *error))failure
{
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *localPath = [[paths objectAtIndex:0] stringByAppendingPathComponent:[url md5]];
    
    AFDownloadRequestOperation *operation = [[AFDownloadRequestOperation alloc] initWithRequest:request targetPath:localPath shouldResume:YES];
    operation.shouldOverwrite = YES;
    
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        [[AFNetworkActivityIndicatorManager sharedManager] decrementActivityCount];
        NSLog(@"Successfully downloaded file to %@", localPath);
        if (success)
            success(localPath);
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [[AFNetworkActivityIndicatorManager sharedManager] decrementActivityCount];
        NSLog(@"Error: %@", error);
        if (failure)
            failure(error);
    }];
    
    //Progress indicator
    [operation setProgressiveDownloadProgressBlock:^(AFDownloadRequestOperation *operation, NSInteger bytesRead, long long totalBytesRead, long long totalBytesExpected, long long totalBytesReadForFile, long long totalBytesExpectedToReadForFile)
     {
         CGFloat progressNumber = (CGFloat)totalBytesRead / (CGFloat)totalBytesExpected;
         if (progressNumber > 1)
             progressNumber = 1;
         
         //Convert to 100% and callback
         CGFloat percentage = progressNumber * 100.0f;
         if (progress)
             progress(percentage, totalBytesExpected, totalBytesReadForFile);
         
         [SVProgressHUD showProgress:progressNumber];
     }];
    
    [SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeGradient];
    [[AFNetworkActivityIndicatorManager sharedManager] incrementActivityCount];
    
    if (self.httpClient == nil)
        self.httpClient = [[AFHTTPClient alloc] init];
    [self.httpClient enqueueHTTPRequestOperation:operation];
}

@end
