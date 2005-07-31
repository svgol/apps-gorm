/*
  GormTableViewAttributesInspector.m

   Copyright (C) 2001 Free Software Foundation, Inc.

   Author:  Laurent Julliard <laurent@julliard-online.org>
   Author:  Gregory John Casamento <greg_casamento@yahoo.com>
   Date: Aug 2001. 2003, 2004
   
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
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
*/
/*
  July 2005 : Spilt inspector in separate classes.
  Always use ok: revert: methods
  Clean up
  Author : Fabien Vallon <fabien@sonappart.net>
*/
#include "GormTableViewAttributesInspector.h"

#include "GormNSTableView.h"

#include <GormCore/NSColorWell+GormExtensions.h>
#include <GormCore/GormPrivate.h>

#include <Foundation/NSNotification.h>

#include <AppKit/NSButton.h>
#include <AppKit/NSColorWell.h>
#include <AppKit/NSForm.h>
#include <AppKit/NSMatrix.h>
#include <AppKit/NSNibLoading.h>



@implementation	NSTableView (IBObjectAdditions)
- (NSString*) inspectorClassName
{
  return @"GormTableViewAttributesInspector";
}
@end


@implementation GormTableViewAttributesInspector

- (id) init
{
  if ([super init] == nil)
    {
      return nil;
    }

  if ([NSBundle loadNibNamed: @"GormNSTableViewInspector" owner: self] == NO)
    {
      NSLog(@"Could not gorm GormTableViewInspector");
      return nil;
    }

  return self;
}

- (void) ok: (id)sender
{
  BOOL flag;
  BOOL isScrollView;
  id scrollView;

  scrollView = [[object superview] superview];
  isScrollView = [ scrollView isKindOfClass: [NSScrollView class]];

  if ( sender == multipleSelectionSwitch ) 
    {
      [object setGormAllowsMultipleSelection:[multipleSelectionSwitch state]];
    }
  else if ( sender == emptySelectionSwith ) 
    {
      [object setGormAllowsEmptySelection: [emptySelectionSwith state]];
    }
  else if ( sender == columnSelectionSwitch ) 
    {
      [object setGormAllowsColumnSelection: [columnSelectionSwitch state]];
    }
  else if ( (sender == verticalScrollerSwitch) && isScrollView)
    {
      flag = ([sender state] == NSOnState) ? YES : NO;
      [scrollView setHasVerticalScroller: flag];
    }
 
  else if ( (sender == horizontalScrollerSwitch) && isScrollView)
    {
      flag = ([sender state] == NSOnState) ? YES : NO;
      [scrollView setHasHorizontalScroller: flag];
    } 

  else if ( (sender == borderMatrix) && isScrollView)
    {
      [scrollView setBorderType: [[sender selectedCell] tag]];
    }
  
  else if (sender == rowsHeightForm)
    {
      int numCols = [object numberOfColumns];
      int newNumCols = [[sender cellAtIndex: 1] intValue];

      // add/delete columns based on number in #columns field...
      [object setRowHeight: [[sender cellAtIndex: 0] intValue] ];
      if(newNumCols > 0)
	{
	  if(numCols < newNumCols)
	    {
	      int colsToAdd = newNumCols - numCols;
	      int i = 0;
	      // Add columns from the last to the target number...
	      for(i = 0; i < colsToAdd; i++)
		{
		  NSString *identifier = [NSString stringWithFormat: @"column%d",(numCols + i + 1)];
		  NSTableColumn *tc = AUTORELEASE([(NSTableColumn *)[NSTableColumn alloc] initWithIdentifier: (id)identifier]);
		  [tc setWidth: 50];
		  [tc setMinWidth: 20];
		  [tc setResizable: YES];
		  [tc setEditable: YES];
		  [object addTableColumn: tc];
		}
	    }
	  else if(numCols > newNumCols)
	    {
	      int colsToDelete = numCols - newNumCols;
	      int i = 0;
	      NSArray *columns = [object tableColumns];
	      // remove columns...
	      for(i = 0; i < colsToDelete; i++)
		{
		  NSTableColumn *tc = [columns objectAtIndex: (i + newNumCols)];
		  [object removeTableColumn: tc];
		}
	    }
	}

      // recompute column sizes..
      [object sizeToFit];
      [object tile];
    } 
  /* Options */
  else if ( sender == drawgridSwitch ) 
    {
      [object setDrawsGrid:[drawgridSwitch state]];
    }
  else if ( sender == resizingSwitch ) 
    {
      [object setGormAllowsColumnResizing: [resizingSwitch state]];
    }
  else if ( sender == reorderingSwitch ) 
    {
      [object setGormAllowsColumnReordering:[reorderingSwitch state]];
    }
  else if( sender == tagForm )
    {
      [object setTag:[[tagForm cellAtIndex:0] intValue]];
    }
  else if( sender == backgroundColor )
    {
      [object setBackgroundColor: [backgroundColor color]];
    }

  [scrollView setNeedsDisplay: YES];

  [super ok:sender];
}


- (void) revert: (id) sender
{
  BOOL isScrollView;
  id scrollView;

  if ( object == nil ) 
    return;

  scrollView = [object enclosingScrollView];

  isScrollView = [ scrollView isKindOfClass: [NSScrollView class]];


  [multipleSelectionSwitch setState: [object gormAllowsMultipleSelection]];
  [emptySelectionSwith setState:[object gormAllowsEmptySelection]];
  [columnSelectionSwitch setState:[object gormAllowsColumnSelection]];

  if (isScrollView)
    {
      [verticalScrollerSwitch setEnabled: YES];
      [verticalScrollerSwitch setState: 
				([scrollView hasVerticalScroller]) ? NSOnState : NSOffState];

      [horizontalScrollerSwitch setEnabled: YES];   
      [horizontalScrollerSwitch setState: 
				  ([scrollView hasHorizontalScroller]) ? NSOnState : NSOffState];
      
      [borderMatrix setEnabled: YES];
      [borderMatrix selectCellWithTag: [scrollView borderType]];
    }
  else
    {
      [verticalScrollerSwitch setEnabled: NO];
      [horizontalScrollerSwitch setEnabled: NO];   
      [borderMatrix setEnabled: NO];   
    }

  [[rowsHeightForm cellAtIndex: 0] setIntValue: [object rowHeight] ];
  [[rowsHeightForm cellAtIndex: 1] setIntValue: [object numberOfColumns]];

  [drawgridSwitch setState:[object drawsGrid]];
  [resizingSwitch setState:[object gormAllowsColumnResizing]];
  [reorderingSwitch setState:[object gormAllowsColumnReordering]];

  [[tagForm cellAtIndex:0] setIntValue:[object tag]];

  // set the background color into the inspector...
  [backgroundColor setColorWithoutAction: [object backgroundColor]];
  
  [super revert:sender];
}

/* delegate for tag and Forms */
-(void) controlTextDidChange:(NSNotification *)aNotification
{
  [self ok:[aNotification object]];
}

@end