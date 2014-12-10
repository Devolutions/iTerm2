//
//  TestViewController.m
//  iTerm
//
//  Created by Richard Markiewicz on 2014-12-10.
//
//

#import "TestViewController.h"

@interface TestViewController ()

@end

@implementation TestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

- (NSString *)echo:(NSString *)message
{
    return [NSString stringWithFormat:@"You said: %@", message];
}

@end
