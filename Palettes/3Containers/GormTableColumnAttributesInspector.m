/*
  GormTableColumnAttributesInspector.m

   Copyright (C) 2001-2005 Free Software Foundation, Inc.

   Author:  Adam Fedor <fedor@gnu.org>
              Laurent Julliard <laurent@julliard-online.org>
   Date: Aug 2001
   
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


#include "GormTableColumnAttributesInspector.h"
#include <GormCore/GormPrivate.h>

#include <AppKit/NSButton.h>
#include <AppKit/NSMatrix.h>
#include <AppKit/NSNibLoading.h>
#include <AppKit/NSTextField.h>
#include <AppKit/NSTableView.h>
#include <AppKit/NSTableColumn.h>

/*
  IBObjectAdditions category
*/

@implementation NSTableColumn (IBObjectAdditions)
- (NSString *) inspectorClassName
{
  return @"GormTableColumnAttributesInspector";
}
@end

@implementation GormTableColumnAttributesInspector

- (id) init
{
  if ([super init] == nil)
    {
      return nil;
    }

  if ([NSBundle loadNibNamed: @"GormNSTableColumnInspector" owner: self] == NO)
    {
      NSLog(@"Could not gorm GormTableColumnInspector");
      return nil;
    }

  return self;
}

#warning check this ? 
- (void) awakeFromNib
{
  [cellTable setDoubleAction: @selector(ok:)];
}


- (void) revert:(id) sender
{
  NSArray *list;
  NSString *cellClassName;
  int index;

  if ( object == nil ) 
    return;

  list = [[(id<Gorm>)NSApp classManager] allSubclassesOf: @"NSCell"];
  cellClassName = [self _getCellClassName];
  index =  [list indexOfObject: cellClassName];

  if(index != NSNotFound && index != -1)
    {
      [cellTable selectRow: index byExtendingSelection: NO];
      [cellTable scrollRowToVisible: index];
    }
  
  switch ([[object headerCell] alignment])
    {
    case NSLeftTextAlignment:
      [titleAlignmentMatrix selectCellAtRow: 0 column: 0];
      break;
    case NSCenterTextAlignment:
      [titleAlignmentMatrix selectCellAtRow: 0 column: 1];
      break;
    case NSRightTextAlignment:
      [titleAlignmentMatrix selectCellAtRow: 0 column: 2];
      break;
    default:
      NSLog(@"Unhandled alignment value...");
      break;
    }

  switch ([[object dataCell] alignment])
    {
    case NSLeftTextAlignment:
      [contentsAlignmentMatrix selectCellAtRow: 0 column: 0];
      break;
    case NSCenterTextAlignment:
      [contentsAlignmentMatrix selectCellAtRow: 0 column: 1];
      break;
    case NSRightTextAlignment:
      [contentsAlignmentMatrix selectCellAtRow: 0 column: 2];
      break;
    default:
      NSLog(@"Unhandled alignment value...");
      break;
    }

  [identifierTextField setStringValue: [(NSTableColumn *)object identifier]];

  if ([object isResizable])
    [resizableSwitch setState: NSOnState];
  else
    [resizableSwitch setState: NSOffState];

  if ([object isEditable])
    [editableSwitch setState: NSOnState];
  else
    [editableSwitch setState: NSOffState];

  [super revert:sender];
}

- (void) ok: (id) sender
{
  if (sender == titleAlignmentMatrix)
    {
      if ([[sender cellAtRow: 0 column: 0] state] == NSOnState)
	{
	  [[object headerCell] setAlignment: NSLeftTextAlignment];
	}
      else if ([[sender cellAtRow: 0 column: 1] state] == NSOnState)
	{
	  [[object headerCell] setAlignment: NSCenterTextAlignment];
	}
      else if ([[sender cellAtRow: 0 column: 2] state] == NSOnState)
	{
	  [[object headerCell] setAlignment: NSRightTextAlignment];
	}

      if ([[object tableView] headerView] != nil)
	{
	  [[[object tableView] headerView] setNeedsDisplay: YES];
	}
    }
  else if (sender == contentsAlignmentMatrix)
    {
      if ([[sender cellAtRow: 0 column: 0] state] == NSOnState)
	{
	  [[object dataCell] setAlignment: NSLeftTextAlignment];
	}
      else if ([[sender cellAtRow: 0 column: 1] state] == NSOnState)
	{
	  [[object dataCell] setAlignment: NSCenterTextAlignment];
	}
      else if ([[sender cellAtRow: 0 column: 2] state] == NSOnState)
	{
	  [[object dataCell] setAlignment: NSRightTextAlignment];
	}
      [[object tableView] setNeedsDisplay: YES];
    }
  else if (sender == identifierTextField)
    {
      [object setIdentifier:
		[identifierTextField stringValue]];
    }
  else if (sender == editableSwitch)
    {
      [object setEditable:
		([editableSwitch state] == NSOnState)];
    }
  else if (sender == resizableSwitch)
    {
      [object setResizable:
		([resizableSwitch state] == NSOnState)];
    }
  else if (sender == setButton || sender == cellTable)
    {
      id classManager = [(id<Gorm>)NSApp classManager];
      id<IBDocuments> doc = [(id<IB>)NSApp activeDocument];
      id cell = nil;
      int i = [cellTable selectedRow];
      NSArray *list = [classManager allSubclassesOf: @"NSCell"];
      NSString *className = [list objectAtIndex: i];
      BOOL isCustom = [classManager isCustomClass: className];
      Class cls = nil;

      if(isCustom)
	{
	  NSString *superClass = [classManager nonCustomSuperClassOf: className];
	  cls = NSClassFromString(superClass);
	  NSLog(@"Setting custom cell..");
	}
      else
	{
	  cls = NSClassFromString(className);
	}

      // initialize
      cell = [[cls alloc] init];
      [object setDataCell: cell];
      [[object tableView] setNeedsDisplay: YES];

      // add it to the document, since it needs a custom class...
      if(isCustom)
	{
	  NSString *name = nil;

	  // An object needs to be a "named object" to have a custom class
	  // assigned to it.   Add it to the document and get the name.
	  [doc attachObject: cell toParent: object];
	  if((name = [doc nameForObject: cell]) != nil)
	    {
	      [classManager setCustomClass: className forName: name];
	    } 
	}

      RELEASE(cell);
    }
  else if (sender == defaultButton)
    {
      [object setDataCell: [[NSTextFieldCell alloc] init]];
      [[object tableView] setNeedsDisplay: YES];
      [self setObject: [self object]]; // reset...
    }
}


- (NSString *)_getCellClassName
{
  id cell = [[self object] dataCell];
  NSString *customClassName = [[(id<Gorm>)NSApp classManager] customClassForObject: cell];
  NSString *result = nil;

  if(customClassName == nil)
    {
      result = NSStringFromClass([cell class]);
    }
  else
    {
      result = customClassName;
    }
  
  return result;
}


// data source
- (int) numberOfRowsInTableView: (NSTableView *)tv
{
  NSArray *list = [[(id<Gorm>)NSApp classManager] allSubclassesOf: @"NSCell"];
  return [list count];
}

- (id)          tableView: (NSTableView *)tv
objectValueForTableColumn: (NSTableColumn *)tc
	              row: (int)rowIndex
{
  NSArray *list = [[(id<Gorm>)NSApp classManager] allSubclassesOf: @"NSCell"];
  id value = nil;
  if([list count] > 0)
    {
      value = [list objectAtIndex: rowIndex];
    }
  return value;
}

// delegate
- (BOOL)    tableView: (NSTableView *)tableView
shouldEditTableColumn: (NSTableColumn *)aTableColumn
		  row: (int)rowIndex
{
  return NO;
}

- (BOOL) tableView: (NSTableView *)tv
   shouldSelectRow: (int)rowIndex
{
  return YES;
}


/* delegate method for identifier */
-(void) controlTextDidChange:(NSNotification *)aNotification
{
  [self ok:[aNotification object]];
}

@end