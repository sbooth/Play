//
//  AIPlasticButton.m
//  Adium
//
//  Created by Adam Iser on Thu Jun 26 2003.
//

#import "AIPlasticButton.h"
//#import "ESImageAdditions.h"

#define LABEL_OFFSET_X	1
#define LABEL_OFFSET_Y	0

#define IMAGE_OFFSET_X	0
#define IMAGE_OFFSET_Y	0

#define PLASTIC_ARROW_WIDTH		8
#define PLASTIC_ARROW_HEIGHT	(PLASTIC_ARROW_WIDTH/2.0)
#define PLASTIC_ARROW_XOFFSET	12
#define PLASTIC_ARROW_YOFFSET	12
#define PLASTIC_ARROW_PADDING	8

@interface AIPlasticButton (PRIVATE)
- (NSBezierPath *)popUpArrowPath;
@end

@implementation AIPlasticButton

//
- (id)copyWithZone:(NSZone *)zone
{
	AIPlasticButton	*newButton = [[[self class] allocWithZone:zone] initWithFrame:[self frame]];
	
	[newButton setMenu:[[[self menu] copy] autorelease]];
	[newButton->plasticCaps retain];
	[newButton->plasticMiddle retain];
	[newButton->plasticPressedCaps retain];
	[newButton->plasticPressedMiddle retain];
	[newButton->plasticDefaultCaps retain];
	[newButton->plasticDefaultMiddle retain];

	return(newButton);
}

- (id)initWithFrame:(NSRect)frameRect
{
	if((self = [super initWithFrame:frameRect])) {
		//Default title and image
		[self setTitle:@""];
		[self setImage:nil];

//		Class myClass = [self class];
    
		//Load images
		plasticCaps          = [[NSImage imageNamed:@"PlasticButtonNormal_Caps"/*    forClass:myClass*/] retain];
		plasticMiddle        = [[NSImage imageNamed:@"PlasticButtonNormal_Middle"/*  forClass:myClass*/] retain];
		plasticPressedCaps   = [[NSImage imageNamed:@"PlasticButtonPressed_Caps"/*   forClass:myClass*/] retain];
		plasticPressedMiddle = [[NSImage imageNamed:@"PlasticButtonPressed_Middle"/* forClass:myClass*/] retain];
		plasticDefaultCaps   = [[NSImage imageNamed:@"PlasticButtonDefault_Caps"/*   forClass:myClass*/] retain];
		plasticDefaultMiddle = [[NSImage imageNamed:@"PlasticButtonDefault_Middle"/* forClass:myClass*/] retain];
		
		[plasticCaps setFlipped:YES];
		[plasticMiddle setFlipped:YES];
		[plasticPressedCaps setFlipped:YES];
		[plasticPressedMiddle setFlipped:YES];
		[plasticDefaultCaps setFlipped:YES];
		[plasticDefaultMiddle setFlipped:YES];
	}

	return self;    
}

- (void)drawRect:(NSRect)rect
{
    NSRect	sourceRect, destRect, frame;
    int		capWidth;
    int		capHeight;
    int		middleRight;
    NSImage	*caps;
    NSImage	*middle;
    
    //Get the correct images
    if(![[self cell] isHighlighted]){
        if([[self keyEquivalent] isEqualToString:@"\r"]){
            caps = plasticDefaultCaps;
            middle = plasticDefaultMiddle;
        }else{
            caps = plasticCaps;
            middle = plasticMiddle;
        }
    }else{
        caps = plasticPressedCaps;
        middle = plasticPressedMiddle;
    }

    //Precalc some sizes
    NSSize capsSize = [caps size];
    frame = [self bounds];
    capWidth = capsSize.width / 2.0;
    capHeight = capsSize.height;
    middleRight = ((frame.origin.x + frame.size.width) - capWidth);

    //Draw the left cap
	destRect = NSMakeRect(frame.origin.x/* + capWidth*/, frame.origin.y/* + frame.size.height*/, capWidth, frame.size.height);
    [caps drawInRect:destRect
			fromRect:NSMakeRect(0, 0, capWidth, capHeight)
		   operation:NSCompositeSourceOver
			fraction:1.0];

    //Draw the middle, which tiles across the button (excepting the areas drawn by the left and right caps)
    NSSize middleSize = [middle size];
    sourceRect = NSMakeRect(0, 0, middleSize.width, middleSize.height);
    destRect = NSMakeRect(frame.origin.x + capWidth, frame.origin.y/* + frame.size.height*/, sourceRect.size.width,  frame.size.height);
	
    while(destRect.origin.x < middleRight && (int)destRect.size.width > 0){
        //Crop
        if((destRect.origin.x + destRect.size.width) > middleRight){
            sourceRect.size.width -= (destRect.origin.x + destRect.size.width) - middleRight;
        }
		
        [middle drawInRect:destRect
				  fromRect:sourceRect
				 operation:NSCompositeSourceOver
				  fraction:1.0];
        destRect.origin.x += destRect.size.width;
    }
	
    //Draw right mask
	destRect = NSMakeRect(middleRight, frame.origin.y/* + frame.size.height*/, capWidth, frame.size.height);
	[caps drawInRect:destRect
			fromRect:NSMakeRect(capWidth, 0, capWidth, capHeight)
		   operation:NSCompositeSourceOver
			fraction:1.0];
	
    //Draw Label
    NSString *title = [self title];
    if(title) {
        NSColor		*color;
        NSDictionary 	*attributes;
        NSSize		size;
        NSPoint		centeredPoint;

        //Prep attributes
        if([self isEnabled]) {
            color = [NSColor blackColor];
        } else {
            color = [NSColor colorWithCalibratedWhite:0.0 alpha:0.5];
        }
        attributes = [NSDictionary dictionaryWithObjectsAndKeys:[self font], NSFontAttributeName, color, NSForegroundColorAttributeName, nil];

        //Calculate center
        size = [title sizeWithAttributes:attributes];
        centeredPoint = NSMakePoint(frame.origin.x + round((frame.size.width - size.width) / 2.0) + LABEL_OFFSET_X,
                                    frame.origin.y + round((frame.size.height - size.height) / 2.0) + LABEL_OFFSET_Y);

        //Draw
        [title drawAtPoint:centeredPoint withAttributes:attributes];
    }

    //Draw image
    NSImage *image = [self image];
    if(image) {
        NSSize	size = [image size];
        NSRect	centeredRect;

		if([self menu]) frame.size.width -= PLASTIC_ARROW_PADDING;
		
        centeredRect = NSMakeRect(frame.origin.x + (int)((frame.size.width - size.width) / 2.0) + IMAGE_OFFSET_X,
                                  frame.origin.y + (int)((frame.size.height - size.height) / 2.0) + IMAGE_OFFSET_Y,
                                  size.width,
                                  size.height);
		
        [image setFlipped:YES];
        [image drawInRect:centeredRect
				 fromRect:NSMakeRect(0,0,size.width,size.height) 
				operation:NSCompositeSourceOver 
				 fraction:([self isEnabled] ? 1.0 : 0.5)];
    }
    
	//Draw the arrow, if needed
	if([self menu]){
		[[[NSColor blackColor] colorWithAlphaComponent:0.70] set];
		[[self popUpArrowPath] fill];
	}
}

//Path for the little popup arrow (Cached, dependent upon our current frame)
- (NSBezierPath *)popUpArrowPath
{
	if(!arrowPath){
		NSRect frame = [self frame];
		
		arrowPath = [[NSBezierPath bezierPath] retain];
		[arrowPath moveToPoint:NSMakePoint(NSWidth(frame)-PLASTIC_ARROW_XOFFSET, NSHeight(frame)-PLASTIC_ARROW_YOFFSET)];
		[arrowPath relativeLineToPoint:NSMakePoint( PLASTIC_ARROW_WIDTH, 0)];
		[arrowPath relativeLineToPoint:NSMakePoint(-(PLASTIC_ARROW_WIDTH/2.0), (PLASTIC_ARROW_WIDTH/2.0))];
		[arrowPath closePath];
	}
	
	return arrowPath;
}

//If our frame changes, release and clear the arrowPath cache so it will be recalculated when we next draw.
- (void)setFrame:(NSRect)inFrame
{
	[arrowPath release]; arrowPath = nil;
	
	[super setFrame:inFrame];
}


//Mouse Tracking -------------------------------------------------------------------------------------------------------
#pragma mark Mouse Tracking
//Custom mouse down tracking to display our menu and highlight
- (void)mouseDown:(NSEvent *)theEvent
{
	if(![self menu]){
		[super mouseDown:theEvent];
	}else{
		if([self isEnabled]){
			[self highlight:YES];
			
			NSPoint point = [self convertPoint:[self bounds].origin toView:nil];
			point.y -= NSHeight([self frame]) + 2;
			point.x -= 1;
			
			NSEvent *event = [NSEvent mouseEventWithType:[theEvent type]
												location:point
										   modifierFlags:[theEvent modifierFlags]
											   timestamp:[theEvent timestamp]
											windowNumber:[[theEvent window] windowNumber]
												 context:[theEvent context]
											 eventNumber:[theEvent eventNumber]
											  clickCount:[theEvent clickCount]
												pressure:[theEvent pressure]];
			[NSMenu popUpContextMenu:[self menu] withEvent:event forView:self];
			
			[self mouseUp:[[NSApplication sharedApplication] currentEvent]];
		}
	}
}

//Remove highlight on mouse up
- (void)mouseUp:(NSEvent *)theEvent
{
	[self highlight:NO];
	[super mouseUp:theEvent];
}

//Ignore dragging
- (void)mouseDragged:(NSEvent *)theEvent
{
	//Empty
}

- (BOOL)isOpaque
{
    return NO;
}

- (void)dealloc
{
    [plasticCaps release];
    [plasticMiddle release];
    [plasticPressedCaps release];
    [plasticPressedMiddle release];
    [plasticDefaultCaps release];
    [plasticDefaultMiddle release];    
	[arrowPath release];
	
    [super dealloc];
}

@end
