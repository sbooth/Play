// From CocoaDev

#import <Cocoa/Cocoa.h>

@interface NSBezierPath (RoundRectMethods)

+ (NSBezierPath *) bezierPathWithRoundRectInRect:(NSRect)aRect radius:(float)radius;
+ (void) fillRoundRectInRect:(NSRect)rect radius:(float)radius;
+ (void) strokeRoundRectInRect:(NSRect)rect radius:(float)radius;

@end
