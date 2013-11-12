//
//  main.m
//  MediaKeyIntercept
//
//  Created by Dennis Munsie on 11/12/13.
//  Copyright (c) 2013 Dennis Munsie. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MKIAppDelegate.h"

int main(int argc, const char * argv[]) {
  MKIAppDelegate *delegate = [[MKIAppDelegate alloc] init];
  [[NSApplication sharedApplication] setDelegate:delegate];
  [[NSApplication sharedApplication] run];
}
