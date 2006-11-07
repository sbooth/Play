#import "AIPlasticInfoButton.h"

@implementation AIPlasticInfoButton

- (id)initWithFrame:(NSRect)frameRect
{
	if((self = [super initWithFrame:frameRect])) {
		[self setImage:[NSImage imageNamed:@"i"]];
	}
	return self;    
}

@end
