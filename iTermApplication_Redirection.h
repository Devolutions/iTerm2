//
//  iTermApplication_Redirection.h
//  iTerm
//
//  Created by Richard Markiewicz on 2014-12-12.
//
//

#import <Foundation/Foundation.h>

#import "iTermApplicationDelegate.h"

@interface iTermApplication_Redirection : NSObject
{
    iTermApplicationDelegate *appDelegate;
}

@property (nonatomic, readonly) id<NSApplicationDelegate> delegate;

+ (id)sharedApplication;

@end
