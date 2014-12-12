//
//  iTermApplication_Redirection.m
//  iTerm
//
//  Created by Richard Markiewicz on 2014-12-12.
//
//

#import "iTermApplication_Redirection.h"

@implementation iTermApplication_Redirection

+ (id)sharedApplication
{
    static iTermApplication_Redirection *sharedMyApplication = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyApplication = [[self alloc] init];
    });
    
    return sharedMyApplication;
}

- (id)init
{
    if(self = [super init])
    {
        appDelegate = [[iTermApplicationDelegate alloc] init];
        
        return self;
    }
    
    return nil;
}

- (id<NSApplicationDelegate>)delegate
{
    return (id<NSApplicationDelegate>)appDelegate;
}

@end
