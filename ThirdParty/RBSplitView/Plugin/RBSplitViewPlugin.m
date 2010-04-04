//
//  RBSplitViewPlugin.m version 1.2
//  RBSplitView
//
//  Created by Rainer Brockerhoff on 24/09/2004.
//  Copyright 2004-2009 Rainer Brockerhoff.
//	Some Rights Reserved under the Creative Commons Attribution License, version 2.5, and/or the MIT License.
//

#import "RBSplitViewPlugin.h"
#import "RBSplitViewPrivateDefines.h"
#import <objc/objc-class.h>

// Please don't remove this copyright notice!
static const unsigned char RBSplitViewPlugin_Copyright[] __attribute__ ((used)) =
	"RBSplitViewPlugin 1.2 Copyright(c)2004-2009 by Rainer Brockerhoff <rainer@brockerhoff.net>.";

// This is the plugin class itself.

@implementation RBSplitViewPlugin

- (NSImage*)thumb8 {
	static NSImage* thumb8 = nil;
	if (!thumb8) {
		thumb8 = [[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForImageResource:@"Thumb8"]];
		[thumb8 setFlipped:YES];
	}
	return thumb8;
}

- (NSImage*)thumb9 {
	static NSImage* thumb9 = nil;
	if (!thumb9) {
		thumb9 = [[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForImageResource:@"Thumb9"]];
		[thumb9 setFlipped:YES];
	}
	return thumb9;
}

- (NSArray *)libraryNibNames {
    return [NSArray arrayWithObject:@"RBSplitViewPlugin"];
}

- (NSString *)label {
	return @"RBSplitView Plugin";
}

- (NSArray *)pasteboardObjectsForDraggedLibraryView:(NSView *)view {
	RBSplitView* splitView = [[[RBSplitView alloc] initWithFrame:[view frame] andSubviews:2] autorelease];
	[splitView setDivider:[self thumb8]];
	[splitView adjustSubviews];
	return [NSArray arrayWithObject:splitView];
}

- (NSView*)preferencesView {
	if (!prefView) {
		[NSBundle loadNibNamed:@"RBSplitViewPreferences" owner:self];
		[pluginPath setStringValue:[[NSBundle bundleForClass:[self class]] bundlePath]]; 
	}
	return prefView;
}

- (NSArray *)requiredFrameworks {
	NSBundle* bundle = [NSBundle bundleForClass:[self class]];
	NSArray* paths = [bundle pathsForResourcesOfType:@"framework" inDirectory:@"../Frameworks"];
	NSMutableArray* frmwks = [NSMutableArray arrayWithObject:[NSBundle bundleWithIdentifier:@"com.apple.Cocoa"]];
	for (NSString* fp in paths) {
		NSBundle* frmw = [NSBundle bundleWithPath:fp];
		NSError* error = nil;
		if ([frmw loadAndReturnError:&error]) {
			[frmwks addObject:frmw];
		} else {
			NSLog(@"RBSplitView Plugin: Error loading framework %@:\n%@",fp,error);
		}
	}
	return frmwks;
}

@end

// This category adds some functionality to RBSplitSubview to support Interface Builder stuff.

@implementation RBSplitSubview (RBSS_IBAdditions)

- (NSString *)ibDefaultLabel {
	return @"RBSplitSubview";
}

- (void)ibPopulateAttributeInspectorClasses:(NSMutableArray *)classes {
    [super ibPopulateAttributeInspectorClasses:classes];
	[classes addObject:[RBSplitSubviewInspector class]];
}

- (void)ibPopulateSizeInspectorClasses:(NSMutableArray *)classes {
	if ([self splitView]) {
		[classes addObject:[RBSplitSubviewSizeInspector class]];
	} else {
		[super ibPopulateSizeInspectorClasses:classes];
	}
}

- (void)ibPopulateKeyPaths:(NSMutableDictionary *)keyPaths {
    [super ibPopulateKeyPaths:keyPaths];
    [[keyPaths objectForKey:IBAttributeKeyPaths] addObjectsFromArray:
		[NSArray arrayWithObjects:@"tag",@"identifier",@"position",@"canCollapse",@"hasSplitView",@"canAdjust",@"collapsed",@"minDimension",@"maxDimension",@"dimension",nil]];
}

// This overrides RBSplitSubview's drawRect: method, to draw the nice brown background for
// empty subviews. As a convenience, the subview's dimension is also shown.
- (void)drawRect:(NSRect)rect {
	// Draw only if a normal subview.
	if ([self numberOfSubviews]>0) {
		// Don't draw brown background if there are any subviews; draw the set background, if any.
		NSColor* bg = [[self splitView] background];
		if (bg) {
			[bg set];
			NSRectFillUsingOperation(rect,NSCompositeSourceOver);
		}
		return;
	}
	if (![self asSplitView]) {
		rect = [self bounds];
		// Draws the bezel around the subview.
		static NSRectEdge mySides[] = {NSMinXEdge,NSMaxYEdge,NSMinXEdge,NSMinYEdge,NSMaxXEdge,NSMaxYEdge,NSMaxXEdge,NSMinYEdge};
		static CGFloat myGrays[] = {0.5,0.5,1.0,1.0,1.0,1.0,0.5,0.5};
		rect = NSDrawTiledRects(rect,rect,mySides,myGrays,8);
		static NSColor* brown = nil;
		if (!brown) {
			brown = [[[NSColor alternateSelectedControlColor] colorWithAlphaComponent:0.5] retain];
		}
		[brown set];
		NSRectFillUsingOperation(rect,NSCompositeSourceOver);
		// Sets up the text attributes for the dimension text.
		static NSDictionary* attributes = nil;
		if (!attributes) {
			attributes = [[NSDictionary alloc] initWithObjectsAndKeys:[NSColor whiteColor],NSForegroundColorAttributeName,[NSFont systemFontOfSize:12.0],NSFontAttributeName,nil];
		}
		// Sets up the "nnnpx" string and draws it centered into the subview.
		NSMutableAttributedString* label = [[[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%gpx",[self dimension]] attributes:attributes] autorelease];
		NSSize labelSize = [label size];
		if (rect.size.width<labelSize.width) {
			[label replaceCharactersInRange:NSMakeRange([label length]-2,0) withString:@"\n"];
			labelSize = [label size];
		}
		rect.origin.y += floor((rect.size.height-labelSize.height)/2.0);
		rect.origin.x += floor((rect.size.width-labelSize.width)/2.0);
		rect.size = labelSize;
		[label drawInRect:rect];
	}
}

- (BOOL)ibIsChildViewUserMovable:(NSView *)view {
	return YES;
}

- (BOOL)ibIsChildViewUserSizable:(NSView *)child {
	return YES;
}

- (BOOL)ibIsChildInitiallySelectable:(id)child {
	return NO;
}

- (NSView *)ibDesignableContentView {
	return self;
}

- (NSRect)ibRectForChild:(id)child inWindowController:(NSWindowController *)controller {
	return [super ibRectForChild:child inWindowController:controller];
}

- (void)ibDelayedAdd:(RBSplitView*)added {
	RBSplitView* suv = [self splitView];
	[added setTag:[self tag]];
	[added setIdentifier:[self identifier]];
	[added setCanCollapse:[self canCollapse]];
	[added setMinDimension:[self minDimension] andMaxDimension:[self maxDimension]];
	[added RB___setFrameSize:[self frame].size withFraction:[self RB___fraction]];
	[suv replaceSubview:self with:added];
	IBDocument* document = [IBDocument documentForObject:suv];
	[document moveObject:added toParent:suv];
	[document removeObject:self];
}

- (void)addSubview:(NSView*)aView {
	if (([self numberOfSubviews]==0)&&[aView isKindOfClass:[RBSplitView class]]) {
		[self performSelector:@selector(ibDelayedAdd:) withObject:(RBSplitView*)aView afterDelay:0];
	}
	[super addSubview:aView];
}

- (BOOL)hasSplitView {
	return [self splitView]!=nil;
}

- (BOOL)canAdjust {
	return [self numberOfSubviews]==1;
}

- (void)setIsCollapsed:(BOOL)flag {
	if (flag) {
		[self RB___collapse];
	} else {
		[self RB___expandAndSetToMinimum:NO];
	}
	[[self splitView] adjustSubviews];
}

- (void)setMaxDimension:(NSString*)maxd {
	[self willChangeValueForKey:@"maxDimension"];
	[self willChangeValueForKey:@"dimension"];
	[self setMinDimension:[self minDimension] andMaxDimension:[maxd floatValue]];
	[[self splitView] adjustSubviews];
	[self didChangeValueForKey:@"maxDimension"];
	[self didChangeValueForKey:@"dimension"];
}

- (void)setMinDimension:(NSString*)mind {
	[self willChangeValueForKey:@"minDimension"];
	[self willChangeValueForKey:@"dimension"];
	[self setMinDimension:[mind floatValue] andMaxDimension:[self maxDimension]];
	[[self splitView] adjustSubviews];
	[self didChangeValueForKey:@"minDimension"];
	[self didChangeValueForKey:@"dimension"];
}

@end

@implementation RBSplitView (RBSV_IBAdditions)

- (void)setActionName:(NSString*)aString {
	[[[IBDocument documentForObject:self] undoManager] setActionName:aString];
}

- (void)setAutosaveName:(NSString*)aString {
	[self setAutosaveName:aString recursively:NO];
}

- (BOOL)canAdjust {
	return NO;
}

- (void)setNumberOfSubviews:(unsigned int)count {
	[self willChangeValueForKey:@"numberOfSubviews"];
	IBDocument* doc = [IBDocument documentForObject:self];
	unsigned now = [self numberOfSubviews];
	NSRect frame = NSZeroRect;
	if (now<count) {
		frame = [[[self subviews] lastObject] frame];
	}
	while (now!=count) {
		if (now<count) {
			RBSplitSubview* sub = [[[RBSplitSubview alloc] initWithFrame:frame] autorelease];
			[self addSubview:sub positioned:NSWindowAbove relativeTo:nil];
			[doc addObject:sub toParent:self];
		} else {
			RBSplitSubview* sub = [[self subviews] lastObject];
			[sub retain];
			[sub removeFromSuperviewWithoutNeedingDisplay];
			[doc performSelector:@selector(removeObject:) withObject:sub afterDelay:0.0];
			[sub release];
		}
		now = [self numberOfSubviews];
	}
	[self RB___setMustClearFractions];
	[self adjustSubviews];
	[self didChangeValueForKey:@"numberOfSubviews"];
}

- (void)setBackgroundColor:(NSColor*)color {
	[self setBackground:color];
}

- (NSColor*)backgroundColor {
	NSColor* bkg = [self background];
	return bkg?bkg:[NSColor clearColor];
}

- (BOOL)enableThickness {
	return ([self RB___dividerThickness]<1.0)||![self divider];
}

- (BOOL)fromImage {
	return [self RB___dividerThickness]<1.0;
}

- (void)setIsCoupled:(BOOL)flag {
	[self willChangeValueForKey:@"enableThickness"];
	[self willChangeValueForKey:@"isCoupled"];
	[self willChangeValueForKey:@"notCoupled"];
	[self setCoupled:flag];
	[self didChangeValueForKey:@"enableThickness"];
	[self didChangeValueForKey:@"isCoupled"];
	[self didChangeValueForKey:@"notCoupled"];
}

- (void)setFromImage:(BOOL)flag {
	[self willChangeValueForKey:@"enableThickness"];
	[self willChangeValueForKey:@"dividerThickness"];
	[self willChangeValueForKey:@"fromImage"];
	if (flag) {
		[self setDividerThickness:0.0];
	} else {
		[self setDividerThickness:[self dividerThickness]];
	}
	[self didChangeValueForKey:@"enableThickness"];
	[self didChangeValueForKey:@"dividerThickness"];
	[self didChangeValueForKey:@"fromImage"];
}

- (BOOL)notCoupled {
	return ![self isCoupled];
}

- (BOOL)hasNoSplitView {
	return [self splitView]==nil;
}

- (NSString *)ibDefaultLabel {
	return @"RBSplitView";
}

- (void)ibPopulateAttributeInspectorClasses:(NSMutableArray *)classes {
    [super ibPopulateAttributeInspectorClasses:classes];
    [classes addObject:[RBSplitViewInspector class]];
}

- (void)ibPopulateKeyPaths:(NSMutableDictionary *)keyPaths {
    [super ibPopulateKeyPaths:keyPaths];
    [[keyPaths objectForKey:IBAttributeKeyPaths] addObjectsFromArray:
	 [NSArray arrayWithObjects:@"vertical",@"backgroundColor",@"autosaveName",@"fromImage",@"isCoupled",@"notCoupled",@"dividerThickness",@"numberOfSubviews",@"dividerPositions",nil]];
}

static NSString* positionsString = nil;

- (NSString*)dividerPositions {
	return positionsString;
}

- (void)setDividerPositions:(NSString*)aLayout {
	[positionsString autorelease];
	positionsString = [aLayout retain];
	[self setStateFromString:positionsString];
}

- (void)ibDidAddToDesignableDocument:(IBDocument *)document {
	[super ibDidAddToDesignableDocument:document];
	[self setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
	[[RBSplitViewInspector sharedInstance] performSelector:@selector(refresh) withObject:nil afterDelay:0];
}

- (NSImage *)ibDefaultImage {
	static NSImage* split = nil;
	if (!split) {
		split = [[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForImageResource:@"RBSplitViewPlugin"]];
	}
	return split;
}

- (NSArray *)ibDefaultChildren {
	return [self subviews];
}

- (BOOL)ibCanRemoveChildren:(NSSet *)children {
	if ([self numberOfSubviews]<2) {
		return NO;
	}
	return [super ibCanRemoveChildren:children];
}

- (void)ibRemoveChildren:(NSSet *)objects {
	[self willChangeValueForKey:@"numberOfSubviews"];
	for (RBSplitSubview* suv in objects)  {
		[suv removeFromSuperviewWithoutNeedingDisplay];
	}
	[super ibRemoveChildren:objects];
	[self RB___setMustClearFractions];
	[self adjustSubviews];
	[self didChangeValueForKey:@"numberOfSubviews"];
}

- (BOOL)ibIsChildViewUserMovable:(NSView *)view {
	return NO;
}

- (BOOL)ibIsChildViewUserSizable:(NSView *)child {
	return NO;
}

- (BOOL)ibIsChildInitiallySelectable:(id)child {
	return NO;
}

- (NSView *)ibDesignableContentView {
	return nil;
}

@end

// This number formatter is used for the subview max dimension
@implementation RBNumberFormatter

- (NSString *)stringForObjectValue:(id)anObject {
	if ([anObject isKindOfClass:[NSNumber class]]&&([anObject floatValue]>=WAYOUT)) {
		return @"";
	}
	return [super stringForObjectValue:anObject];
}

- (BOOL)getObjectValue:(id *)anObject forString:(NSString *)string errorDescription:(NSString **)error {
	if (([string length]==0)||([string floatValue]<1.0)) {
		*anObject = @"";
		return YES;
	}
	return [super getObjectValue:anObject forString:string errorDescription:error];
}

@end

@implementation RBSplitSubviewInspector

- (NSString *)viewNibName {
	return @"RBSplitSubviewInspector";
}

+ (BOOL)supportsMultipleObjectInspection {
	return NO;
}

@end

@implementation RBSplitSubviewSizeInspector

- (NSString *)viewNibName {
	return @"RBSplitSubviewSizeInspector";
}

+ (BOOL)supportsMultipleObjectInspection {
	return NO;
}

- (RBSplitSubview*)subView {
	NSArray* objs = [[self inspectedObjectsController] selectedObjects];
	if ([objs count]==1) {
		return [objs objectAtIndex:0];
	}
	return nil;
}

- (IBAction)setMinimumAction:(id)sender {
	RBSplitSubview* subv = [self subView];
	[self willChangeValueForKey:@"minDimension"];
	[self willChangeValueForKey:@"dimension"];
	[subv setMinDimension:[subv dimension] andMaxDimension:[subv maxDimension]];
	[self didChangeValueForKey:@"minDimension"];
	[self didChangeValueForKey:@"dimension"];
	[self refresh];
}

- (IBAction)setMaximumAction:(id)sender {
	RBSplitSubview* subv = [self subView];
	[self willChangeValueForKey:@"maxDimension"];
	[self willChangeValueForKey:@"dimension"];
	[subv setMinDimension:[subv minDimension] andMaxDimension:[subv dimension]];
	[self didChangeValueForKey:@"maxDimension"];
	[self didChangeValueForKey:@"dimension"];
	[self refresh];
}

- (IBAction)adjustTheSubview:(id)sender {
	RBSplitSubview* subv = [self subView];
	NSArray* subs = [subv subviews];
	if ([subs count]==1) {
		NSView* sub = [subs objectAtIndex:0];
		[sub setFrame:[subv bounds]];
		[sub setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
	}
}

@end


@implementation RBSplitViewInspector

- (NSString *)viewNibName {
	return @"RBSplitViewInspector";
}

+ (BOOL)supportsMultipleObjectInspection {
	return NO;
}

- (RBSplitView*)splitView {
	NSArray* objs = [[self inspectedObjectsController] selectedObjects];
	if ([objs count]==1) {
		return [objs objectAtIndex:0];
	}
	return nil;
}

- (IBAction)dividerAction:(id)sender {
	NSImage* thi = nil;
	switch ([[dividerImage selectedItem] tag]) {
//	case 1:	// None
//		thi = nil;
//		break;
	case 2: // Empty
		thi = [[[NSImage alloc] initWithSize:NSMakeSize(1.0,1.0)] autorelease];
		[thi lockFocus];
		[[NSColor clearColor] set];
		NSRectFill(NSMakeRect(0.0,0.0,1.0,1.0));
		[thi unlockFocus];
		[thi setFlipped:YES];
		break;
	case 3:	// Default 8x8
		thi = [[RBSplitViewPlugin sharedInstance] thumb8];
		break;
	case 4:	// NSSplitView's 9x9
		thi = [[RBSplitViewPlugin sharedInstance] thumb9];
		break;
	case 5:	// Paste Image
		thi = [[[NSImage alloc] initWithPasteboard:[NSPasteboard generalPasteboard]] autorelease];
		[thi setFlipped:YES];
		break;
	}
	[[self splitView] setDivider:thi];
	[self refresh];
}

- (void)refresh {
	RBSplitView* sv = [self splitView];
	if (sv) {
		NSImage* divider = [[[sv divider] copy] autorelease];
		[divider setFlipped:NO];
		[[[dividerImage menu] itemAtIndex:0] setImage:divider];
		NSSize size = divider?[divider size]:NSZeroSize;
		[imageText setStringValue:[NSString stringWithFormat:@"(%g x %g)",size.width,size.height]];
	}
	[super refresh];
}

@end


