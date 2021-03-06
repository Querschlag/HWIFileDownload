/*
 * Project: HWIFileDownload (Demo App)
 
 * Created by Heiko Wichmann (20141004)
 * File: DownloadStore.m
 *
 */

/***************************************************************************
 
 Copyright (c) 2014 Heiko Wichmann
 
 https://github.com/Heikowi/HWIFileDownload
 
 This software is provided 'as-is', without any expressed or implied warranty.
 In no event will the authors be held liable for any damages
 arising from the use of this software.
 
 Permission is granted to anyone to use this software for any purpose,
 including commercial applications, and to alter it and redistribute it
 freely, subject to the following restrictions:
 
 1. The origin of this software must not be misrepresented;
 you must not claim that you wrote the original software.
 If you use this software in a product, an acknowledgment
 in the product documentation would be appreciated
 but is not required.
 
 2. Altered source versions must be plainly marked as such,
 and must not be misrepresented as being the original software.
 
 3. This notice may not be removed or altered from any source distribution.
 
 ***************************************************************************/


#import "DownloadStore.h"
#import "AppDelegate.h"
#import "HWIFileDownloadDelegate.h"
#import "HWIFileDownloader.h"

#import <UIKit/UIKit.h>


@interface DownloadStore()
@property (nonatomic, assign) NSUInteger networkActivityIndicatorCount;
@end



@implementation DownloadStore


- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.networkActivityIndicatorCount = 0;
        
        // restore downloaded items
        self.downloadItemsDict = [[[NSUserDefaults standardUserDefaults] objectForKey:@"downloadItems"] mutableCopy];
        if (self.downloadItemsDict == nil)
        {
            self.downloadItemsDict = [NSMutableDictionary dictionary];
        }
        
        // setup items to download
        for (NSUInteger num = 1; num < 11; num++)
        {
            NSString *aDownloadIdentifier = [NSString stringWithFormat:@"%@", @(num)];
            NSDictionary *aDownloadItemDict = [self.downloadItemsDict objectForKey:aDownloadIdentifier];
            if (aDownloadItemDict == nil)
            {
                NSURL *aRemoteURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://www.imagomat.de/testimages/%@.tiff", @(num)]];
                aDownloadItemDict = @{@"URL" : aRemoteURL.absoluteString};
                [self.downloadItemsDict setObject:aDownloadItemDict forKey:aDownloadIdentifier];
            }
        };
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(restartDownload) name:@"restartDownload" object:nil];
        
    }
    return self;
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"restartDownload" object:nil];
}


#pragma mark - HWIFileDownloadDelegate


- (void)downloadDidCompleteWithIdentifier:(NSString *)aDownloadIdentifier
                             localFileURL:(NSURL *)aLocalFileURL
{
    NSLog(@"Download completed (id: %@)", aDownloadIdentifier);
    
    // store download item
    NSDictionary *aDownloadItemDict = @{@"URL" : aLocalFileURL.absoluteString};
    [self.downloadItemsDict setObject:aDownloadItemDict forKey:aDownloadIdentifier];
    [[NSUserDefaults standardUserDefaults] setObject:self.downloadItemsDict forKey:@"downloadItems"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"downloadDidComplete" object:aDownloadIdentifier userInfo:nil];
}


- (void)downloadFailedWithIdentifier:(NSString *)aDownloadIdentifier
                               error:(NSError *)anError
                          resumeData:(NSData *)aResumeData
{
    if (aResumeData)
    {
        NSMutableDictionary *aDownloadItemDict = [[self.downloadItemsDict objectForKey:aDownloadIdentifier] mutableCopy];
        [aDownloadItemDict setObject:aResumeData forKey:@"ResumeData"];
        [self.downloadItemsDict setObject:aDownloadItemDict forKey:aDownloadIdentifier];
        [[NSUserDefaults standardUserDefaults] setObject:self.downloadItemsDict forKey:@"downloadItems"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    if ([anError.domain isEqualToString:NSURLErrorDomain] && (anError.code == NSURLErrorCancelled))
    {
        NSLog(@"Download cancelled - id: %@", aDownloadIdentifier);
    }
    else
    {
        NSLog(@"ERR: %@ (%s)", anError, __PRETTY_FUNCTION__);
    }
}


- (void)downloadProgressChangedForIdentifier:(NSString *)aDownloadIdentifier
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"downloadProgressChanged" object:aDownloadIdentifier userInfo:nil];
}


- (void)incrementNetworkActivityIndicatorActivityCount
{
    [self toggleNetworkActivityIndicatorVisible:YES];
}


- (void)decrementNetworkActivityIndicatorActivityCount
{
    [self toggleNetworkActivityIndicatorVisible:NO];
}


- (void)restartDownload
{
    NSArray *aDownloadIdentifiersArray = [self.downloadItemsDict allKeys];
    NSSortDescriptor *aDownloadIdentifiersSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:nil
                                                                                         ascending:YES
                                                                                        comparator:^(id obj1, id obj2)
                                                            {
                                                                return [obj1 compare:obj2 options:NSNumericSearch];
                                                            }];
    aDownloadIdentifiersArray = [aDownloadIdentifiersArray sortedArrayUsingDescriptors:@[aDownloadIdentifiersSortDescriptor]];
    for (NSString *aDownloadIdentifierString in aDownloadIdentifiersArray)
    {
        NSDictionary *aDownloadItemDict = [self.downloadItemsDict objectForKey:aDownloadIdentifierString];
        NSString *aURLString = [aDownloadItemDict objectForKey:@"URL"];
        if (aURLString.length > 0)
        {
            NSURL *aURL = [NSURL URLWithString:aURLString];
            if ([aURL.scheme isEqualToString:@"http"])
            {
                AppDelegate *theAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
                BOOL isDownloading = [theAppDelegate.fileDownloader isDownloadingIdentifier:aDownloadIdentifierString];
                if (isDownloading == NO)
                {
                    // kick off individual download
                    NSData *aResumeData = [aDownloadItemDict objectForKey:@"ResumeData"];
                    if (aResumeData)
                    {
                        [theAppDelegate.fileDownloader startDownloadWithDownloadIdentifier:aDownloadIdentifierString usingResumeData:aResumeData];
                    }
                    else
                    {
                        [theAppDelegate.fileDownloader startDownloadWithDownloadIdentifier:aDownloadIdentifierString fromRemoteURL:aURL];
                    }
                }
            }
        }
        else
        {
            NSLog(@"ERR: No URL (%s)", __PRETTY_FUNCTION__);
        }
    }
}


#pragma mark - networkActivityIndicatorVisible


- (void)toggleNetworkActivityIndicatorVisible:(BOOL)visible
{
    visible ? self.networkActivityIndicatorCount++ : self.networkActivityIndicatorCount--;
    NSLog(@"NetworkActivityIndicatorCount: %@", @(self.networkActivityIndicatorCount));
    [UIApplication sharedApplication].networkActivityIndicatorVisible = (self.networkActivityIndicatorCount > 0);
}


@end
