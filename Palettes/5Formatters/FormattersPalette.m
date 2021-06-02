/* main.m

   Copyright (C) 1999 Free Software Foundation, Inc.

   Author:  Laurent Julliard <laurent@julliard-online.org>
   Date: Nov 2001
   
   This file is part of GNUstep.
   
   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.
   
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
   
   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
*/

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <Foundation/NSByteCountFormatter.h>

#import <InterfaceBuilder/InterfaceBuilder.h>
#import "FormattersPalette.h"

/* -----------------------------------------------------------
 * Some additions to the Formatters Classes specific to Gorm
 * -----------------------------------------------------------*/
NSArray *predefinedNumberFormats;
int defaultNumberFormatIndex = 0;

@implementation FormattersPalette

- (id) init
{
  if((self = [super init]) != nil)
    {
      // Make ourselves a delegate, so that when the formatter is dragged in, 
      // this code is called...
      [NSView registerViewResourceDraggingDelegate: self];

      // subscribe to the notification...      
      [[NSNotificationCenter defaultCenter]
	addObserver: self
	selector: @selector(willInspectObject:)
	name: IBWillInspectObjectNotification
	object: nil];      
    }
  
  return self;
}

- (void) dealloc
{
  [NSView unregisterViewResourceDraggingDelegate: self];
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  [super dealloc];
}

- (void) placeFormatter: (NSFormatter *)fm
         withImageNamed: (NSString *)imageName
                 atRect: (NSRect)frame
                 inView: (NSView *)contents
                toolTip: (NSString *)tooltip
{
  id		v;
  NSImage       *img;

  img = [NSImage imageNamed: imageName];
  NSLog(@"img = %@", img);
  v = [[NSImageView alloc] initWithFrame: frame]; 
  [v setImageFrameStyle: NSImageFramePhoto];
  [v setImageScaling: NSScaleProportionally];
  [v setImageAlignment: NSImageAlignCenter];
  [v setImage: img];
  [v setToolTip: tooltip];
  [contents addSubview: v];
  [self associateObject: fm type: IBFormatterPboardType with: v];
  RELEASE(v);
}

- (void) finishInstantiate
{ 
  NSView	*contents;

  originalWindow = [[NSWindow alloc] initWithContentRect: 
				       NSMakeRect(0, 0, 272, 192)
				       styleMask: NSBorderlessWindowMask 
					 backing: NSBackingStoreRetained
					   defer: NO];
  [originalWindow setTitle: @"Formatters"];
  contents = [originalWindow contentView];
  
  /* Formatters. */
  [self placeFormatter: [[NSByteCountFormatter alloc] init]
        withImageNamed: @"bytecount_formatter"
                atRect: NSMakeRect(192, 48, 43, 43)
                inView: contents
               toolTip: @"Byte Count"];
  
  [self placeFormatter: [[NSDateComponentsFormatter alloc] init]
        withImageNamed: @"date_comp_formatter"
                atRect: NSMakeRect(144, 48, 43, 43)
                inView: contents
               toolTip: @"Date Components"];

  [self placeFormatter: [[NSDateIntervalFormatter alloc] init]
        withImageNamed: @"date_comp_formatter"
                atRect: NSMakeRect(96, 48, 43, 43)
                inView: contents
               toolTip: @"Date Interval"];

  [self placeFormatter: [[NSPersonNameComponentsFormatter alloc] init]
        withImageNamed: @"date_comp_formatter"
                atRect: NSMakeRect(48, 48, 43, 43)
                inView: contents
               toolTip: @"Energy"];

  [self placeFormatter: [[NSMeasurementFormatter alloc] init]
        withImageNamed: @"date_comp_formatter"
                atRect: NSMakeRect(0, 48, 43, 43)
                inView: contents
               toolTip: @"Measurement"];

  [self placeFormatter: [[NSLengthFormatter alloc] init]
        withImageNamed: @"date_comp_formatter"
                atRect: NSMakeRect(0, 96, 43, 43)
                inView: contents
               toolTip: @"Length"];
}

- (void) willInspectObject: (NSNotification *)notification
{
  id o = [notification object];
  if([o respondsToSelector: @selector(cell)])
    {
      id cell = [o cell];
      if([cell respondsToSelector: @selector(formatter)])
	{
	  id formatter = [o formatter];
	  if([formatter isKindOfClass: [NSFormatter class]])
	    {
	      NSString *ident = NSStringFromClass([formatter class]);
	      [[IBInspectorManager sharedInspectorManager]
		addInspectorModeWithIdentifier: ident 
		forObject: o
		localizedLabel: _(@"Formatter")
		inspectorClassName: [formatter inspectorClassName]
		ordering: -1.0];      
	    }
	}
    }
}

// view resource dragging delegate...

/**
 * Ask if the view accepts the object.
 */
- (BOOL) acceptsViewResourceFromPasteboard: (NSPasteboard *)pb
                                 forObject: (id)obj
                                   atPoint: (NSPoint)p
{
  return ([obj respondsToSelector: @selector(setFormatter:)] && 
	  [[pb types] containsObject: IBFormatterPboardType]);
}

/**
 * Perform the action of depositing the object.
 */
- (void) depositViewResourceFromPasteboard: (NSPasteboard *)pb
                                  onObject: (id)obj
                                   atPoint: (NSPoint)p
{
  NSData *data = [pb dataForType: IBFormatterPboardType];
  id array = [NSUnarchiver unarchiveObjectWithData: data];
  
  if(array != nil)
    {
      if([array count] > 0)
	{
	  id formatter = [array objectAtIndex: 0];

	  // Add the formatter if the object accepts one...
	  if([obj respondsToSelector: @selector(setFormatter:)])
	    {
	      // Touch the document...
	      [[(id<IB>)NSApp activeDocument] touch];

	      [obj setFormatter: formatter];
	      RETAIN(formatter);
	      if ([formatter isMemberOfClass: [NSNumberFormatter class]])
		{
		  id fieldValue = [NSNumber numberWithFloat: 1.123456789];
		  [obj setStringValue: [fieldValue stringValue]];
		  [obj setObjectValue: fieldValue];
		}
	      else if ([formatter isMemberOfClass: [NSDateFormatter class]])
		{
		  id fieldValue = [NSDate date];
		  [obj setStringValue: [fieldValue description]];
		  [obj setObjectValue: fieldValue];
		}	      
	    }
	}
    }
}

/**
 * Should we draw the connection frame when the resource is
 * dragged in?
 */
- (BOOL) shouldDrawConnectionFrame
{
  return NO;
}

/**
 * Types of resources accepted by this view.
 */
- (NSArray *)viewResourcePasteboardTypes
{
  return [NSArray arrayWithObject: IBFormatterPboardType];
}

@end
