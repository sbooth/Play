//
//  RBSplitViewPlugin.h version 1.2
//  RBSplitView
//
//  Created by Rainer Brockerhoff on 24/09/2004.
//  Copyright 2004-2007 Rainer Brockerhoff.
//	Some Rights Reserved under the Creative Commons Attribution License, version 2.5, and/or the MIT License.
//

#import <InterfaceBuilderKit/InterfaceBuilderKit.h>
#import "RBSplitView.h"

// This is the main plugin class.

@interface RBSplitViewPlugin : IBPlugin {
	IBOutlet NSView* prefView;
	IBOutlet NSTextField* pluginPath;
}
@end

// This class implements the RBSplitSubview attribute inspector.

@interface RBSplitSubviewInspector : IBInspector {
 	RBSplitSubview* splitSubview;
//	IBOutlet NSButton* collapseButton;
//    IBOutlet NSButton* adjustButton;
//    IBOutlet NSTextField* identifierValue;
//    IBOutlet NSTextField* minimumValue;
//    IBOutlet NSTextField* maximumValue;
//    IBOutlet NSStepper* positionStepper;
//    IBOutlet NSTextField* positionValue;
//    IBOutlet NSTextField* tagValue;
//	IBOutlet NSButton* currentMinButton;
//	IBOutlet NSButton* currentMaxButton;
}
@end

// This class implements the RBSplitSubview size inspector.

@interface RBSplitSubviewSizeInspector : IBInspector {
//	RBSplitSubview* splitSubview;
//	IBOutlet NSForm* sizeValue;
//	IBOutlet NSTextField* sizeLimits;
//	IBOutlet NSButton* collapsedButton;
}
- (IBAction)setMinimumAction:(id)sender;
- (IBAction)setMaximumAction:(id)sender;
- (IBAction)adjustTheSubview:(id)sender;
@end

// This class implements the RBSplitView attribute inspector.

@interface RBSplitViewInspector : IBInspector {
//	RBSplitView* splitView;
//    IBOutlet NSTextField* autosaveName;
//    IBOutlet NSColorWell* backgroundWell;
//    IBOutlet NSPopUpButton* dividerImage;
//    IBOutlet NSTextField* dividerSize;
//	IBOutlet NSButton* coupledButton;
//	IBOutlet NSButton* useButton;
//	IBOutlet NSTextField* identifier;
//    IBOutlet NSMatrix* orientation;
//    IBOutlet NSTextField* subviewCount;
//    IBOutlet NSStepper* subviewStepper;
//    IBOutlet NSTextField* tagValue;
//	IBOutlet NSTabView* tabView;
//    IBOutlet NSButton* collapseButton;
//    IBOutlet NSTextField* identifierValue;
//    IBOutlet NSTextField* minimumValue;
//    IBOutlet NSTextField* maximumValue;
//    IBOutlet NSStepper* positionStepper;
//    IBOutlet NSTextField* positionValue;
//    IBOutlet NSTextField* thicknessValue;
    IBOutlet NSPopUpButton* dividerImage;
	IBOutlet NSTextField* imageText;
}
- (IBAction)dividerAction:(id)sender;
@end

// This category adds some functionality to RBSplitSubview to support Interface Builder stuff.

@interface RBSplitSubview (RBSS_IBAdditions)
- (void)setMinDimension:(NSString*)mind;
- (void)setMaxDimension:(NSString*)maxd;
@end

// This category adds some functionality to RBSplitView to support Interface Builder stuff.

@interface RBSplitView (RBSV_IBAdditions)
@end

// A simple number formatter.
@interface RBNumberFormatter : NSNumberFormatter {
}
@end

