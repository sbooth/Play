/*
 *  main.h
 *  RBSplitView
 *
 *  Created by Rainer Brockerhoff on 22/10/09.
 *  Copyright 2009 Rainer Brockerhoff. All rights reserved.
 *
 */

#import <Cocoa/Cocoa.h>
#import "RBSplitView.h"

@interface MyAppDelegate : NSObject {
	IBOutlet RBSplitSubview* firstSplit;
	IBOutlet RBSplitView* secondSplit;
	IBOutlet RBSplitView* thirdSplit;
	IBOutlet RBSplitView* lowerSplit;
	IBOutlet RBSplitView* mySplitView;
	IBOutlet NSButton* myButton;
	IBOutlet NSView* dragView;
	IBOutlet RBSplitSubview* nestedSplit;
}
@end

#define DIM(x) (((CGFloat*)&(x))[ishor])

