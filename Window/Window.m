/* Window.m

   Copyright (C) 1999 Free Software Foundation, Inc.

   Author:  Richard frith-Macdonald (richard@brainstorm.co.uk>
   Date: 1999
   
   This file is part of GNUstep.
   
   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
   
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
   
   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/
#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <AppKit/GSHbox.h>
#include "../Gorm.h"

@interface GormWindowMaker : NSObject <NSCoding>
{
}
@end

@implementation	GormWindowMaker
- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [super encodeWithCoder: aCoder];
}
- (id) initWithCoder: (NSCoder*)aCoder
{
  id		w;
  unsigned	style = NSTitledWindowMask | NSClosableWindowMask
			| NSResizableWindowMask | NSMiniaturizableWindowMask;

  w = [[NSWindow alloc] initWithContentRect: NSMakeRect(0, 0, 400, 200)
				  styleMask: style 
				    backing: NSBackingStoreRetained
				      defer: NO];
  [w setTitle: @"Window"];
  RELEASE(self);
  return w;
}
@end

@interface GormPanelMaker : NSObject <NSCoding>
{
}
@end

@implementation	GormPanelMaker
- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [super encodeWithCoder: aCoder];
}
- (id) initWithCoder: (NSCoder*)aCoder
{
  id		w;
  unsigned	style = NSTitledWindowMask | NSClosableWindowMask
			| NSResizableWindowMask | NSMiniaturizableWindowMask;

  w = [[NSPanel alloc] initWithContentRect: NSMakeRect(0, 0, 400, 200)
				 styleMask: style 
				   backing: NSBackingStoreRetained
				     defer: NO];
  [w setTitle: @"Panel"];
  RELEASE(self);
  return w;
}
@end

@interface WindowPalette: IBPalette
{
}
@end

@implementation WindowPalette
- (void) finishInstantiate
{
  NSView	*contents;
  id		w;
  id		v;
  NSBundle	*bundle = [NSBundle bundleForClass: [self class]];
  NSString	*path = [bundle pathForImageResource: @"WindowDrag"];
  NSImage	*dragImage = [[NSImage alloc] initWithContentsOfFile: path];

  window = [[NSWindow alloc] initWithContentRect: NSMakeRect(0, 0, 272, 192)
				       styleMask: NSBorderlessWindowMask 
					 backing: NSBackingStoreRetained
					   defer: NO];
  contents = [window contentView];

  w = [GormWindowMaker new];
  v = [[NSButton alloc] initWithFrame: NSMakeRect(35, 60, 80, 64)];
  [v setBordered: NO];
  [v setImage: dragImage];
  [v setImagePosition: NSImageOverlaps];
  [v setTitle: @"Window"];
  [contents addSubview: v];
  [self associateObject: w
		   type: IBWindowPboardType
		   with: v];
  RELEASE(v);
  RELEASE(w);

  w = [GormPanelMaker new];
  v = [[NSButton alloc] initWithFrame: NSMakeRect(155, 60, 80, 64)];
  [v setBordered: NO];
  [v setImage: dragImage];
  [v setImagePosition: NSImageOverlaps];
  [v setTitle: @"Panel"];
  [contents addSubview: v];
  [self associateObject: w
		   type: IBWindowPboardType
		   with: v];
  RELEASE(v);
  RELEASE(w);

  RELEASE(dragImage);
}
@end

@implementation	NSWindow (IBInspectorClassNames)
- (NSString*) inspectorClassName
{
  return @"GormWindowAttributesInspector";
}
- (NSString*) connectInspectorClassName
{
  return @"GormWindowConnectionsInspector";
}
- (NSString*) sizeInspectorClassName
{
  return @"GormWindowSizeInspector";
}
- (NSString*) helpInspectorClassName
{
  return @"GormWindowHelpInspector";
}
- (NSString*) classInspectorClassName
{
  return @"GormWindowClassInspector";
}
@end



@interface GormWindowAttributesInspector : IBInspector
@end

@implementation GormWindowAttributesInspector
- (void) dealloc
{
  RELEASE(window);
  [super dealloc];
}

- (id) init
{
  self = [super init];
  if (self != nil)
    {
      NSView	*contents;
      NSBox	*box;

      window = [[NSWindow alloc] initWithContentRect: NSMakeRect(0, 0, 272, 360)
					   styleMask: NSBorderlessWindowMask 
					     backing: NSBackingStoreRetained
					       defer: NO];
      contents = [window contentView];
      box = [[NSBox alloc] initWithFrame: NSMakeRect(10, 300, 100, 50)];
      [box setTitle: @"Backing"];
      [box setBorderType: NSGrooveBorder];
      [contents addSubview: box];
      RELEASE(box);
    }
  return self;
}
@end



@interface GormWindowConnectionsInspector : IBInspector
@end

@implementation GormWindowConnectionsInspector
@end



@interface GormWindowSizeInspector : IBInspector
@end

@implementation GormWindowSizeInspector
@end



@interface GormWindowHelpInspector : IBInspector
@end

@implementation GormWindowHelpInspector
@end



@interface GormWindowClassInspector : IBInspector
@end

@implementation GormWindowClassInspector
@end

