/* GormDocument.m
 *
 * This class contains Gorm specific implementation of the IBDocuments
 * protocol plus additional methods which are useful for managing the
 * contents of the document.
 *
 * Copyright (C) 1999,2002,2003,2004,2005 Free Software Foundation, Inc.
 *
 * Author:      Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:        2002,2003,2004,2005
 * Author:	Richard Frith-Macdonald <richard@brainstrom.co.uk>
 * Date:	1999
 *
 * This file is part of GNUstep.
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include "GormPrivate.h"
#include "GormClassManager.h"
#include "GormCustomView.h"
#include "GormOutlineView.h"
#include "GormFunctions.h"
#include "GormFilePrefsManager.h"
#include "GormViewWindow.h"
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSException.h>
#include <AppKit/NSImage.h>
#include <AppKit/NSSound.h>
#include <AppKit/NSNibConnector.h>
#include <AppKit/NSNibLoading.h>
#include <GNUstepGUI/GSNibTemplates.h>
#include "NSView+GormExtensions.h"
#include "GormSound.h"
#include "GormImage.h"
#include "GormResourceManager.h"
#include "GormClassEditor.h"
#include "GormSoundEditor.h"
#include "GormImageEditor.h"
#include "GormObjectEditor.h"

@interface GormDisplayCell : NSButtonCell
@end

@implementation	GormDisplayCell
- (void) setShowsFirstResponder: (BOOL)flag
{
  [super setShowsFirstResponder: NO];	// Never show ugly frame round button
}
@end

@interface NSNibConnector (GormExtension)
- (BOOL) isEqual: (id)object;
@end

@implementation NSNibConnector (GormExtension)
- (BOOL) isEqual: (id)object
{
  BOOL result = NO;

  if(self == object)
    {
      result = YES;
    }
  else if([[self source] isEqual: [object source]] &&
     [[self destination] isEqual: [object destination]] &&
     [[self label] isEqual: [object label]] &&
     ([self class] == [object class]))
    {
      result = YES;
    }
  return result;
}
@end

// Internal only
NSString *GSCustomClassMap = @"GSCustomClassMap";

@interface GormDocument (GModel)
- (id) openGModel: (NSString *)path;
@end

@implementation	GormFirstResponder
- (NSImage*) imageForViewer
{
  static NSImage	*image = nil;

  if (image == nil)
    {
      NSBundle	*bundle = [NSBundle mainBundle];
      NSString	*path = [bundle pathForImageResource: @"GormFirstResponder"];

      image = [[NSImage alloc] initWithContentsOfFile: path];
    }
  return image;
}
- (NSString*) inspectorClassName
{
  return @"GormNotApplicableInspector";
}
- (NSString*) connectInspectorClassName
{
  return @"GormNotApplicableInspector";
}
- (NSString*) sizeInspectorClassName
{
  return @"GormNotApplicableInspector";
}
- (NSString*) classInspectorClassName
{
  return @"GormNotApplicableInspector";
}
- (NSString*) className
{
  return @"FirstResponder";
}
@end



/*
 * Trivial classes for connections from objects to their editors, and from
 * child editors to their parents.  This does nothing special, but we can
 * use the fact that it's a different class to search for it in the connections
 * array.
 */
@interface	GormObjectToEditor : NSNibConnector
@end

@implementation	GormObjectToEditor
@end

@interface	GormEditorToParent : NSNibConnector
@end

@implementation	GormEditorToParent
@end

@implementation GormDocument

static NSImage	*objectsImage = nil;
static NSImage	*imagesImage = nil;
static NSImage	*soundsImage = nil;
static NSImage	*classesImage = nil;
static NSImage  *fileImage = nil;

/**
 * Initialize the class.
 */ 
+ (void) initialize
{
  if (self == [GormDocument class])
    {
      NSBundle	*bundle;
      NSString	*path;

      bundle = [NSBundle mainBundle];
      path = [bundle pathForImageResource: @"GormObject"];
      if (path != nil)
	{
	  objectsImage = [[NSImage alloc] initWithContentsOfFile: path];
	}
      path = [bundle pathForImageResource: @"GormImage"];
      if (path != nil)
	{
	  imagesImage = [[NSImage alloc] initWithContentsOfFile: path];
	}
      path = [bundle pathForImageResource: @"GormSound"];
      if (path != nil)
	{
	  soundsImage = [[NSImage alloc] initWithContentsOfFile: path];
	}
      path = [bundle pathForImageResource: @"GormClass"];
      if (path != nil)
	{
	  classesImage = [[NSImage alloc] initWithContentsOfFile: path];
	}
      path = [bundle pathForImageResource: @"Gorm"];
      if (path != nil)
	{
	  fileImage = [[NSImage alloc] initWithContentsOfFile: path];
	}

      // register the resource managers...
      [IBResourceManager registerResourceManagerClass: 
			   [IBResourceManager class]];
      [IBResourceManager registerResourceManagerClass: 
			   [GormResourceManager class]];
      [self setVersion: GNUSTEP_NIB_VERSION];
    }
}

/**
 * Initialize the new GormDocument object.
 */
- (id) init 
{
  self = [super init];
  if (self != nil)
    {
      if([NSBundle loadNibNamed: @"GormDocument" owner: self])
	{      
	  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
	  NSRect			scrollRect = {{0, 0}, {340, 188}};
	  NSRect			mainRect = {{20, 0}, {320, 188}};
	  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	  
	  // initialize...
	  openEditors = [[NSMutableArray alloc] init];
	  classManager = [(GormClassManager *)[GormClassManager alloc] initWithDocument: self]; 
	  
	  /*
	   * NB. We must retain the map values (object names) as the nameTable
	   * may not hold identical name objects, but merely equal strings.
	   */
	  objToName = NSCreateMapTableWithZone(NSObjectMapKeyCallBacks,
					       NSObjectMapValueCallBacks, 128, [self zone]);
	  
	  // for saving the editors when the gorm file is persisted.
	  savedEditors = [[NSMutableArray alloc] init];	  
	  [window setMinSize: [window frame].size];
	  [window setTitle: _(@"UNTITLED")];
	  
	  // observe certain notifications...
	  [nc addObserver: self
	      selector: @selector(handleNotification:)
	      name: NSWindowWillCloseNotification
	      object: window];
	  [nc addObserver: self
	      selector: @selector(handleNotification:)
	      name: NSWindowDidBecomeKeyNotification
	      object: window];
	  [nc addObserver: self
	      selector: @selector(handleNotification:)
	      name: NSWindowWillMiniaturizeNotification
	      object: window];
	  [nc addObserver: self
	      selector: @selector(handleNotification:)
	      name: NSWindowDidDeminiaturizeNotification
	      object: window];
	  [nc addObserver: self
	      selector: @selector(handleNotification:)
	      name: IBClassNameChangedNotification
	      object: classManager];
	  [nc addObserver: self
	      selector: @selector(handleNotification:)
	      name: IBInspectorDidModifyObjectNotification
	      object: classManager];
	  [nc addObserver: self
	      selector: @selector(handleNotification:)
	      name: GormDidModifyClassNotification
	      object: classManager];
	  [nc addObserver: self
	      selector: @selector(handleNotification:)
	      name: GormDidAddClassNotification
	      object: classManager];
	  [nc addObserver: self
	      selector: @selector(handleNotification:)
	      name: IBWillBeginTestingInterfaceNotification
	      object: nil];
	  [nc addObserver: self
	      selector: @selector(handleNotification:)
	      name: IBWillEndTestingInterfaceNotification
	      object: nil];
	  [nc addObserver: self
	      selector: @selector(handleNotification:)
	      name: IBResourceManagerRegistryDidChangeNotification
	      object: nil];

	  // load resource managers
	  [self createResourceManagers];

	  // objects...
	  mainRect.origin = NSMakePoint(0,0);
	  scrollView = [[NSScrollView alloc] initWithFrame: scrollRect];
	  [scrollView setHasVerticalScroller: YES];
	  [scrollView setHasHorizontalScroller: YES];
	  [scrollView setAutoresizingMask:
			NSViewHeightSizable|NSViewWidthSizable];
	  [scrollView setBorderType: NSBezelBorder];
	  
	  objectsView = [[GormObjectEditor alloc] initWithObject: nil
						  inDocument: self];
	  [objectsView setFrame: mainRect];
	  [objectsView setAutoresizingMask:
			 NSViewHeightSizable|NSViewWidthSizable];
	  [scrollView setDocumentView: objectsView];
	  RELEASE(objectsView); 

	  // images...
	  mainRect.origin = NSMakePoint(0,0);
	  imagesScrollView = [[NSScrollView alloc] initWithFrame: scrollRect];
	  [imagesScrollView setHasVerticalScroller: YES];
	  [imagesScrollView setHasHorizontalScroller: YES];
	  [imagesScrollView setAutoresizingMask:
			      NSViewHeightSizable|NSViewWidthSizable];
	  [imagesScrollView setBorderType: NSBezelBorder];
	  
	  imagesView = [[GormImageEditor alloc] initWithObject: nil
						inDocument: self];
	  [imagesView setFrame: mainRect];
	  [imagesView setAutoresizingMask: NSViewHeightSizable|NSViewWidthSizable];
	  [imagesScrollView setDocumentView: imagesView];
	  RELEASE(imagesView);

	  // sounds...
	  mainRect.origin = NSMakePoint(0,0);
	  soundsScrollView = [[NSScrollView alloc] initWithFrame: scrollRect];
	  [soundsScrollView setHasVerticalScroller: YES];
	  [soundsScrollView setHasHorizontalScroller: YES];
	  [soundsScrollView setAutoresizingMask:
			      NSViewHeightSizable|NSViewWidthSizable];
	  [soundsScrollView setBorderType: NSBezelBorder];
	  
	  soundsView = [[GormSoundEditor alloc] initWithObject: nil
						inDocument: self];
	  [soundsView setFrame: mainRect];
	  [soundsView setAutoresizingMask: NSViewHeightSizable|NSViewWidthSizable];
	  [soundsScrollView setDocumentView: soundsView];
	  RELEASE(soundsView);

	  /* classes view */
	  mainRect.origin = NSMakePoint(0,0);
	  classesView = [(GormClassEditor *)[GormClassEditor alloc] initWithDocument: self];
	  [classesView setFrame: mainRect];
	  
	  /*
	   * Set the objects view as the initial view the user's see on startup.
	   */
	  // [selectionBox setContentViewMargins: NSZeroSize];
	  [selectionBox setContentView: scrollView];
	  
	  /*
	   * Set up special-case dummy objects and add them to the objects view.
	   */
	  filesOwner = [[GormFilesOwner alloc] init];
	  [self setName: @"NSOwner" forObject: filesOwner];
	  [objectsView addObject: filesOwner];
	  firstResponder = [[GormFirstResponder alloc] init];
	  [self setName: @"NSFirst" forObject: firstResponder];
	  [objectsView addObject: firstResponder];
	  
	  /*
	   * Set image for this miniwindow.
	   */
	  [window setMiniwindowImage: [(id)filesOwner imageForViewer]];	  
	  hidden = [[NSMutableArray alloc] init];
	  
	  // retain the file prefs view...
	  RETAIN(filePrefsView);

	  // preload headers...
	  if ([defaults boolForKey: @"PreloadHeaders"])
	    {
	      NSArray *headerList = [defaults arrayForKey: @"HeaderList"];
	      NSEnumerator *en = [headerList objectEnumerator];
	      id obj = nil;
	      
	      while ((obj = [en nextObject]) != nil)
		{
		  NSString *header = (NSString *)obj;

		  NSDebugLog(@"Preloading %@", header);
		  NS_DURING
		    {
		      if(![classManager parseHeader: header])
			{
			  NSString *file = [header lastPathComponent];
			  NSString *message = [NSString stringWithFormat: 
							  _(@"Unable to parse class in %@"),file];
			  NSRunAlertPanel(_(@"Problem parsing class"), 
					  message,
					  nil, nil, nil);
			}
		    }
		  NS_HANDLER
		    {
		      NSString *message = [localException reason];
		      NSRunAlertPanel(_(@"Problem parsing class"), 
				      message,
				      nil, nil, nil);
		    }
		  NS_ENDHANDLER;
		}
	    }

	  // are we upgrading an archive?
	  isOlderArchive = NO;

	  // document is open...
	  isDocumentOpen = YES;
	}
      else
	{
	  NSLog(@"Couldn't load GormDocument interface.");
	  [NSApp terminate: self];
	}
    }
  return self;
}

/**
 * Perform any additional setup which needs to happen.
 */
- (void) awakeFromNib
{
  // set up the toolbar...
  toolbar = [(NSToolbar *)[NSToolbar alloc] initWithIdentifier: @"GormToolbar"];
  [toolbar setAllowsUserCustomization: NO];
  [toolbar setDelegate: self];
  [window setToolbar: toolbar];
  RELEASE(toolbar);
  [toolbar setUsesStandardBackgroundColor: YES];
  [toolbar setSelectedItemIdentifier: @"ObjectsItem"]; // set initial selection.
}

/**
 * Add aConnector to the set of connectors in this document.
 */
- (void) addConnector: (id<IBConnectors>)aConnector
{
  if ([connections indexOfObjectIdenticalTo: aConnector] == NSNotFound)
    {
      NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
      [nc postNotificationName: IBWillAddConnectorNotification
			object: aConnector];
      [connections addObject: aConnector];
      [nc postNotificationName: IBDidAddConnectorNotification
			object: aConnector];
    }
}

/**
 * Returns all connectors.
 */
- (NSArray*) allConnectors
{
  return [NSArray arrayWithArray: connections];
}

/**
 * Creates the proxy font manager.
 */
- (void) _instantiateFontManager
{
  GSNibItem *item = nil;
  
  item = [[GormObjectProxy alloc] initWithClassName: @"NSFontManager"
				  frame: NSMakeRect(0,0,0,0)];
  
  [self setName: @"NSFont" forObject: item];
  [self attachObject: item toParent: nil];
  RELEASE(item);

  // set the holder in the document.
  fontManager = (GormObjectProxy *)item;
  
  // [selectionView selectCellWithTag: 0];
  [selectionBox setContentView: scrollView];
}



/**
 * Attach anObject to the document with aParent.
 */
- (void) attachObject: (id)anObject toParent: (id)aParent
{
  NSArray	*old;
  BOOL           newObject = NO;

  /*
   * Create a connector that links this object to its parent.
   * A nil parent is the root of the hierarchy so we use a dummy object for it.
   */
  if (aParent == nil)
    {
      aParent = filesOwner;
    }

  old = [self connectorsForSource: anObject ofClass: [NSNibConnector class]];
  if ([old count] > 0)
    {
      [[old objectAtIndex: 0] setDestination: aParent];
    }
  else
    {
      NSNibConnector	*con = [[NSNibConnector alloc] init];

      [con setSource: anObject];
      [con setDestination: aParent];
      [self addConnector: (id<IBConnectors>)con];
      RELEASE(con);
    }

  /*
   * Make sure that there is a name for this object.
   */
  if ([self nameForObject: anObject] == nil)
    {
      newObject = YES;
      [self setName: nil forObject: anObject];
    }

  /*
   * Add top-level objects to objectsView and open their editors.
   */
  if ([anObject isKindOfClass: [NSWindow class]] ||
      [anObject isKindOfClass: [GSNibItem class]])
    {
      [objectsView addObject: anObject];
      [topLevelObjects addObject: anObject];
      [[self openEditorForObject: anObject] activate];
      if ([anObject isKindOfClass: [NSWindow class]] == YES)
	{
	  [anObject setReleasedWhenClosed: NO];
	}
    }
  else if((aParent == filesOwner || aParent == nil) &&
	  [anObject isKindOfClass: [NSMenu class]] == NO)
    {
      if([anObject isKindOfClass: [NSObject class]] &&
	 [anObject isKindOfClass: [NSView class]] == NO)
	{
	  [objectsView addObject: anObject];
	  [topLevelObjects addObject: anObject];
	}
      else if([anObject isKindOfClass: [NSView class]] && [anObject superview] == nil)
	{
	  [objectsView addObject: anObject];
	  [topLevelObjects addObject: anObject];
	}
    }

  /*
   * Check if it's a font manager.
   */
  else if([anObject isKindOfClass: [NSFontManager class]])
    {
      // if someone tries to attach a font manager, we must attach
      // the proxy instead.
      [self _instantiateFontManager];
    }

  /*
   * Add the current menu and any submenus.
   */
  else if ([anObject isKindOfClass: [NSMenu class]] == YES)
    {
      BOOL isMainMenu = NO;

      // if there is no main menu and a menu gets added, it
      // will become the main menu.
      if([self objectForName: @"NSMenu"] == nil)
	{
	  [self setName: @"NSMenu" forObject: anObject];
	  [objectsView addObject: anObject];
	  [topLevelObjects addObject: anObject];
	  isMainMenu = YES;
	}
      else
	{
	  if([[anObject title] isEqual: @"Services"] && [self servicesMenu] == nil)
	    {
	      [self setServicesMenu: anObject];
	    }
	  else if([[anObject title] isEqual: @"Windows"] && [self windowsMenu] == nil)
	    {
	      [self setWindowsMenu: anObject];
	    }
	}

      [[self openEditorForObject: anObject] activate];

      // if it's the main menu... locate it appropriately...
      if(isMainMenu)
	{
	  NSRect frame = [window frame];
	  NSPoint origin = frame.origin;

	  origin.y += (frame.size.height + 150);

	  // place the main menu appropriately...
	  [[anObject window] setFrameTopLeftPoint: origin];
	}
    }
  /*
   * if this a scrollview, it is interesting to add its contentview
   * if it is a tableview or a textview
   */
  else if (([anObject isKindOfClass: [NSScrollView class]] == YES)
	   && ([(NSScrollView *)anObject documentView] != nil))
    {
      if ([[anObject documentView] isKindOfClass: 
				    [NSTableView class]] == YES)
	{
	  int i;
	  int count;
	  NSArray *tc;
	  id tv = [anObject documentView];
	  tc = [tv tableColumns];
	  count = [tc count];
	  [self attachObject: tv toParent: anObject];
	  
	  for (i = 0; i < count; i++)
	    {
	      [self attachObject: [tc objectAtIndex: i]
			toParent: tv];
	    }
	}
      else if ([[anObject documentView] isKindOfClass: [NSTextView class]] == YES)
	{
	  [self attachObject: [anObject documentView] toParent: anObject];
	}
    }
  /*
   * If it's a tab view, then we want the tab items.
   */
  else if ([anObject isKindOfClass: [NSTabView class]] == YES)
    {
      NSEnumerator *tie = [[anObject tabViewItems] objectEnumerator];
      NSTabViewItem *ti = nil;
      while((ti = [tie nextObject]) != nil)
	{
	  [self attachObject: ti toParent: anObject];
	}
    }
  /*
   * If it's a tab view item, then we attach the view.
   */
  else if ([anObject isKindOfClass: [NSTabViewItem class]] == YES)
    {
      NSTabViewItem *ti = (NSTabViewItem *)anObject; 
      id v = [ti view];
      [self attachObject: v toParent: ti];
    }

  // Detect and add any connection the object might have.
  // This is done so that any palette items which have predefined connections will be
  // shown in the connections list.
  if([anObject respondsToSelector: @selector(action)] == YES &&
     [anObject respondsToSelector: @selector(target)] == YES &&
     newObject == YES)
    {
      SEL sel = [anObject action];

      if(sel != NULL)
	{
	  NSString *label = NSStringFromSelector(sel);
	  id source = anObject;
	  NSNibControlConnector *con = [[NSNibControlConnector alloc] init];
	  id destination = [(NSControl *)anObject target];
	  NSArray *sourceConnections = [self connectorsForSource: source];

	  // if it's a menu item we want to connect it to it's parent...
	  if([anObject isKindOfClass: [NSMenuItem class]] && 
	     [label isEqual: @"submenuAction:"])
	    {
	      destination = aParent;
	    }
	  
	  // if the connection needs to be made with the font manager, replace
	  // it with our proxy object and proceed with creating the connection.
	  if((destination == nil || destination == [NSFontManager sharedFontManager]) && 
	     [classManager isAction: label ofClass: @"NSFontManager"])
	    {
	      if(!fontManager)
		{
		  // initialize font manager...
		  [self _instantiateFontManager];
		}
	      
	      // set the destination...
	      destination = fontManager;
	    }

	  // if the destination is still nil, back off to the first responder.
	  if(destination == nil)
	    {
	      destination = firstResponder;
	    }

	  // build the connection
	  [con setSource: source];
	  [con setDestination: destination];
	  [con setLabel: label];
	  
	  // don't duplicate the connection if it already exists.
	  // if([sourceConnections indexOfObjectIdenticalTo: con] == NSNotFound)
	  if([sourceConnections containsObject: con] == NO)
	    {
	      // add it to our connections set.
	      [self addConnector: (id<IBConnectors>)con];
	    }

	  // destroy the connection in the object to
	  // prevent any conflict.   The connections are restored when the 
	  // .gorm is loaded, so there's no need for it anymore.
	  [anObject setTarget: nil];
	  [anObject setAction: NULL];

	  // release the connection.
	  RELEASE(con);
	}
    }
}

/**
 * Attach all objects in anArray to the document with aParent.
 */
- (void) attachObjects: (NSArray*)anArray toParent: (id)aParent
{
  NSEnumerator	*enumerator = [anArray objectEnumerator];
  NSObject	*obj;

  while ((obj = [enumerator nextObject]) != nil)
    {
      [self attachObject: obj toParent: aParent];
    }
}

/**
 * Start the process of archiving.
 */
- (void) beginArchiving
{
  NSEnumerator		*enumerator;
  id<IBConnectors>	con;
  id			obj;

  /*
   * Map all connector sources and destinations to their name strings.
   * Deactivate editors so they won't be archived.
   */

  enumerator = [connections objectEnumerator];
  while ((con = [enumerator nextObject]) != nil)
    {
      if ([con isKindOfClass: [GormObjectToEditor class]] == YES)
	{
	  [savedEditors addObject: con];
	  [[con destination] deactivate];
	}
      else if ([con isKindOfClass: [GormEditorToParent class]] == YES)
	{
	  [savedEditors addObject: con];
	}
      else
	{
	  NSString	*name;
	  obj = [con source];
	  name = [self nameForObject: obj];
	  [con setSource: name];
	  obj = [con destination];
	  name = [self nameForObject: obj];
	  [con setDestination: name];
	}
    }
  [connections removeObjectsInArray: savedEditors];

  NSDebugLog(@"*** customClassMap = %@",[classManager customClassMap]);
  [nameTable setObject: [classManager customClassMap] forKey: GSCustomClassMap];

  /*
   * Remove objects and connections that shouldn't be archived.
   */
  NSMapRemove(objToName, (void*)[nameTable objectForKey: @"NSOwner"]);
  [nameTable removeObjectForKey: @"NSOwner"];
  NSMapRemove(objToName, (void*)[nameTable objectForKey: @"NSFirst"]);
  [nameTable removeObjectForKey: @"NSFirst"];

  /* Add information about the NSOwner to the archive */
  NSMapInsert(objToName, (void*)[filesOwner className], (void*)@"NSOwner");
  [nameTable setObject: [filesOwner className] forKey: @"NSOwner"];

  /*
   * Set the appropriate profile so that we save the right versions of 
   * the classes for older GNUstep releases.
   */
  [filePrefsManager setClassVersions];
}

- (void) changeToViewWithTag: (int)tag
{
  switch (tag)
    {
    case 0: // objects
      {
	[selectionBox setContentView: scrollView];
	[toolbar setSelectedItemIdentifier: @"ObjectsItem"];
	[self setSelectionFromEditor: objectsView];
      }
      break;
    case 1: // images
      {
	[selectionBox setContentView: imagesScrollView];
	[toolbar setSelectedItemIdentifier: @"ImagesItem"];
	[self setSelectionFromEditor: imagesView];
      }
      break;
    case 2: // sounds
      {
	[selectionBox setContentView: soundsScrollView];
	[toolbar setSelectedItemIdentifier: @"SoundsItem"];
	[self setSelectionFromEditor: soundsView];
      }
      break;
    case 3: // classes
      {
	NSArray *selection =  [[(id<IB>)NSApp selectionOwner] selection];
	[selectionBox setContentView: classesView];
	
	// if something is selected, in the object view.
	// show the equivalent class in the classes view.
	if ([selection count] > 0)
	  {
	    id obj = [selection objectAtIndex: 0];
	    [classesView selectClassWithObject: obj];
	  }
	[toolbar setSelectedItemIdentifier: @"ClassesItem"];
	[self setSelectionFromEditor: classesView];
      }
      break;
    case 4: // file prefs
      {
	[toolbar setSelectedItemIdentifier: @"FileItem"];
	[selectionBox setContentView: filePrefsView];
      }
      break;
    }
}

- (void) changeToTopLevelEditorAcceptingTypes: (NSArray *)types
				  andFileType: (NSString *)fileType
{
  // NSToolbar *toolbar = [window toolbar];
  if([objectsView acceptsTypeFromArray: types] &&
     fileType == nil)
    {
      [self changeToViewWithTag: 0];
    }
  else if([imagesView acceptsTypeFromArray: types] &&
	  [[imagesView fileTypes] containsObject: fileType])
    {
      [self changeToViewWithTag: 1];
    }
  else if([soundsView acceptsTypeFromArray: types] &&
	  [[soundsView fileTypes] containsObject: fileType])
    {
      [self changeToViewWithTag: 2];
    }
  else if([classesView acceptsTypeFromArray: types] &&
	  [[classesView fileTypes] containsObject: fileType])
    {
      [self changeToViewWithTag: 3];
    }
}

/**
 * Change the view in the document window.
 */
- (void) changeView: (id)sender
{
  [self changeToViewWithTag: [sender tag]];
}

/**
 * The class manager.
 */ 
- (GormClassManager*) classManager
{
  return classManager;
}

/**
 * A Gorm document is encoded in the archive as a GSNibContainer.
 * A class that the gnustep gui library knows about and can unarchive.
 */
- (Class) classForCoder
{
  return [GSNibContainer class];
}

/**
 * Returns all connectors to destination.
 */
- (NSArray*) connectorsForDestination: (id)destination
{
  return [self connectorsForDestination: destination ofClass: 0];
}

/**
 * Returns all connectors to destination of class aConnectorClass.
 */
- (NSArray*) connectorsForDestination: (id)destination
                              ofClass: (Class)aConnectorClass
{
  NSMutableArray	*array = [NSMutableArray arrayWithCapacity: 16];
  NSEnumerator		*enumerator = [connections objectEnumerator];
  id<IBConnectors>	c;

  while ((c = [enumerator nextObject]) != nil)
    {
      if ([c destination] == destination
	&& (aConnectorClass == 0 || aConnectorClass == [c class]))
	{
	  [array addObject: c];
	}
    }
  return array;
}

/**
 * Returns all connectors to source.
 */
- (NSArray*) connectorsForSource: (id)source
{
  return [self connectorsForSource: source ofClass: 0];
}

/**
 * Returns all connectors to a given source where the 
 * connectors are of aConnectorClass.
 */
- (NSArray*) connectorsForSource: (id)source
			 ofClass: (Class)aConnectorClass
{
  NSMutableArray	*array = [NSMutableArray arrayWithCapacity: 16];
  NSEnumerator		*enumerator = [connections objectEnumerator];
  id<IBConnectors>	c;

  while ((c = [enumerator nextObject]) != nil)
    {
      if ([c source] == source
	&& (aConnectorClass == 0 || aConnectorClass == [c class]))
	{
	  [array addObject: c];
	}
    }
  return array;
}

/**
 * Returns YES, if the document contains anObject.
 */
- (BOOL) containsObject: (id)anObject
{
  if ([self nameForObject: anObject] == nil)
    {
      return NO;
    }
  return YES;
}

/**
 * Returns YES, if the document contains an object with aName and
 * parent.
 */
- (BOOL) containsObjectWithName: (NSString*)aName forParent: (id)parent
{
  id	obj = [nameTable objectForKey: aName];

  if (obj == nil)
    {
      return NO;
    }
  return YES; 
}

/**
 * Copy anObject to aPasteboard using aType.  Returns YES, if
 * successful.
 */
- (BOOL) copyObject: (id)anObject
               type: (NSString*)aType
       toPasteboard: (NSPasteboard*)aPasteboard
{
  return [self copyObjects: [NSArray arrayWithObject: anObject]
		      type: aType
	      toPasteboard: aPasteboard];
}

/**
 * Copy all objects in anArray to aPasteboard using aType.  Returns YES,
 * if successful.
 */
- (BOOL) copyObjects: (NSArray*)anArray
                type: (NSString*)aType
        toPasteboard: (NSPasteboard*)aPasteboard
{
  NSEnumerator	*enumerator;
  NSMutableSet	*editorSet;
  id		obj;
  NSMutableData	*data;
  NSArchiver    *archiver;

  /*
   * Remove all editors from the selected objects before archiving
   * and restore them afterwards.
   */
  editorSet = [[NSMutableSet alloc] init];
  enumerator = [anArray objectEnumerator];
  while ((obj = [enumerator nextObject]) != nil)
    {
      id editor = [self editorForObject: obj create: NO];
      if (editor != nil)
	{
	  [editorSet addObject: editor];
	  [editor deactivate];
	}

      // Windows are a special case.  Check the content view and see if it's an active editor.
      /**
      if([obj isKindOfClass: [NSWindow class]])
	{
	  id contentView = [obj contentView];
	  if([contentView conformsToProtocol: @protocol(IBEditors)])
	    {
	      [contentView deactivate];
	      [editorSet addObject: contentView];
	    }
	}
      */
    }

  // encode the data
  data = [NSMutableData dataWithCapacity: 0];
  archiver = [[NSArchiver alloc] initForWritingWithMutableData: data];
  [archiver encodeClassName: @"GormCustomView" 
	    intoClassName: @"GSCustomView"];
  [archiver encodeRootObject: anArray];

  // reactivate
  enumerator = [editorSet objectEnumerator];
  while ((obj = [enumerator nextObject]) != nil)
    {
      [obj activate];
    }
  RELEASE(editorSet);

  [aPasteboard declareTypes: [NSArray arrayWithObject: aType]
		      owner: self];
  return [aPasteboard setData: data forType: aType];
}

/**
 * Create a subclass of the currently selected class in the classes view.
 */
- (id) createSubclass: (id)sender
{
  [classesView createSubclass];
  return self;
}

/**
 * The given pasteboard chaned ownership.
 */
- (void) pasteboardChangedOwner: (NSPasteboard *)sender
{
  NSDebugLog(@"Owner changed for %@", sender);
}

/**
 * Dealloc all things owned by a GormDocument object.
 */
- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  ASSIGN(lastEditor, nil);

  // close the window...
  [window close];

  // Get rid of the selection box.
  [selectionBox removeFromSuperviewWithoutNeedingDisplay];

  // release the managers...
  RELEASE(classManager);
  RELEASE(filePrefsManager);
  RELEASE(filePrefsView);

  // release editors...
  RELEASE(savedEditors);
  RELEASE(openEditors);

  // hidden objects...
  RELEASE(hidden);

  if (objToName != 0)
    {
      NSFreeMapTable(objToName);
    }

  // editor views...
  RELEASE(documentPath);
  RELEASE(scrollView);
  RELEASE(classesView);
  RELEASE(soundsScrollView);
  RELEASE(imagesScrollView);

  // windows...
  RELEASE(window);
  RELEASE(filePrefsWindow);

  // resource managers
  RELEASE(resourceManagers);

  [super dealloc];
}

/**
 * Pull all objects which are under the given parent, into array.
 */
- (void) _retrieveObjectsForParent: (id)parent
			 intoArray: (NSMutableArray *)array
		       recursively: (BOOL)flag
{
  NSArray *cons = [self connectorsForDestination: parent
			ofClass: [NSNibConnector class]];
  NSEnumerator *en = [cons objectEnumerator];
  id con = nil;

  while((con = [en nextObject]) != nil)
    {
      id obj = [con source];
      [array addObject: obj];
      if(flag)
	{
	  [self _retrieveObjectsForParent: obj intoArray: array recursively: flag];
	}
    }
}

/**
 * Pull all of the objects which are under a given parent.  Returns an 
 * autoreleased array.
 */
- (NSArray *) retrieveObjectsForParent: (id)parent recursively: (BOOL)flag
{
  NSMutableArray *result = [NSMutableArray array];
  [self _retrieveObjectsForParent: parent intoArray: result recursively: flag];
  return result;
}

/**
 * Deteach anObject from the document.
 */
- (void) detachObject: (id)anObject
{
  NSString	   *name = RETAIN([self nameForObject: anObject]); // released at end of method...
  GormClassManager *cm = [self classManager];
  unsigned	   count;
  NSArray          *objs = [self retrieveObjectsForParent: anObject recursively: NO];
  id               obj = nil;
  NSEnumerator     *en = [objs objectEnumerator];

  if([self containsObject: anObject] == NO)
    {
      return;
    }

  [[self editorForObject: anObject create: NO] close];

  count = [connections count];
  while (count-- > 0)
    {
      id<IBConnectors>	con = [connections objectAtIndex: count];

      if ([con destination] == anObject || [con source] == anObject)
	{
	  [connections removeObjectAtIndex: count];
	}
    }

  // if the font manager is being reset, zero out the instance variable.
  if([name isEqual: @"NSFont"])
    {
      fontManager = nil;
    }

  if ([anObject isKindOfClass: [NSWindow class]] == YES
      || [anObject isKindOfClass: [NSMenu class]] == YES
      || [topLevelObjects containsObject: anObject] == YES)
    {
      [objectsView removeObject: anObject];
    }

  // if it's in the top level items array, remove it.
  if([topLevelObjects containsObject: anObject])
    {
      [topLevelObjects removeObject: anObject];
    }

  // eliminate it from being the windows/services menu, if it's being detached.
  if ([anObject isKindOfClass: [NSMenu class]])
    {
      if([self windowsMenu] == anObject)
	{
	  [self setWindowsMenu: nil];
	}
      else if([self servicesMenu] == anObject)
	{
	  [self setServicesMenu: nil];
	}
    }

  /*
   * Make sure this window isn't in the list of objects to be made visible
   * on nib loading.
   */
  if([anObject isKindOfClass: [NSWindow class]])
    {
      [self setObject: anObject isVisibleAtLaunch: NO];
    }

  // some objects are given a name, some are not.  The only ones we need
  // to worry about are those that have names.
  if(name != nil)
    {
      // remove from custom class map...
      NSDebugLog(@"Delete from custom class map -> %@",name);
      [cm removeCustomClassForName: name];
      if([anObject isKindOfClass: [NSScrollView class]] == YES)
	{
	  NSView *subview = [anObject documentView];
	  NSString *objName = [self nameForObject: subview];
	  NSDebugLog(@"Delete from custom class map -> %@",objName);
	  [cm removeCustomClassForName: objName];
	}
      
      // remove from name table...
      [nameTable removeObjectForKey: name];
      
      // free...
      NSMapRemove(objToName, (void*)anObject);
      RELEASE(name);
    }

  // iterate over the list and remove any subordinate objects.
  if(en != nil)
    {
      while((obj = [en nextObject]) != nil)
	{
	  [self detachObject: obj];
	}
    }
}

/**
 * Detach every object in anArray from the document.
 */
- (void) detachObjects: (NSArray*)anArray
{
  NSEnumerator  *enumerator = [anArray objectEnumerator];
  NSObject      *obj;

  while ((obj = [enumerator nextObject]) != nil)
    {
      [self detachObject: obj];
    }
}

/**
 * The path to where the .gorm file is saved.
 */
- (NSString*) documentPath
{
  return documentPath;
}

/**
 * Add an outlet/action to the classes view.
 */
- (id) addAttributeToClass: (id)sender
{
  [classesView addAttributeToClass];
  return self;
}

/**
 * Remove a class from the classes view
 */
- (id) remove: (id)sender
{
  [classesView deleteSelection];
  return self;
}

/**
 * Parse a header into the classes view.
 */
- (id) loadClass: (id)sender
{
  NSArray	*fileTypes = [NSArray arrayWithObjects: @"h", @"H", nil];
  NSOpenPanel	*oPanel = [NSOpenPanel openPanel];
  int		result;

  [oPanel setAllowsMultipleSelection: NO];
  [oPanel setCanChooseFiles: YES];
  [oPanel setCanChooseDirectories: NO];
  result = [oPanel runModalForDirectory: nil
				   file: nil
				  types: fileTypes];
  if (result == NSOKButton)
    {
      NSString *fileName = [oPanel filename];

      NS_DURING
	{
	  if(![classManager parseHeader: fileName])
	    {
	      NSString *file = [fileName lastPathComponent];
	      NSString *message = [NSString stringWithFormat: 
					      _(@"Unable to parse class in %@"),file];
	      NSRunAlertPanel(_(@"Problem parsing class"), 
			      message,
			      nil, nil, nil);
	    }
	  else
	    {
	      return self;
	    }
	}
      NS_HANDLER
	{
	  NSString *message = [localException reason];
	  NSRunAlertPanel(_(@"Problem parsing class"), 
			  message,
			  nil, nil, nil);
	}
      NS_ENDHANDLER
    }

  return nil;
}

/**
 * Create the class files for the selected class.
 */
- (id) createClassFiles: (id)sender
{
  NSSavePanel		*sp;
  NSString              *className = [classesView selectedClassName];
  int			result;
  
  sp = [NSSavePanel savePanel];
  [sp setRequiredFileType: @"m"];
  [sp setTitle: _(@"Save source file as...")];
  if (documentPath == nil)
    {
      result = [sp runModalForDirectory: NSHomeDirectory() 
		   file: [className stringByAppendingPathExtension: @"m"]];
    }
  else
    {
      result = [sp runModalForDirectory: 
		     [documentPath stringByDeletingLastPathComponent]
		   file: [className stringByAppendingPathExtension: @"m"]];
    }

  if (result == NSOKButton)
    {
      NSString *sourceName = [sp filename];
      NSString *headerName;

      [sp setRequiredFileType: @"h"];
      [sp setTitle: _(@"Save header file as...")];
      result = [sp runModalForDirectory: 
		     [sourceName stringByDeletingLastPathComponent]
		   file: 
		     [[[sourceName lastPathComponent]
			stringByDeletingPathExtension] 
		       stringByAppendingString: @".h"]];
      if (result == NSOKButton)
	{
	  headerName = [sp filename];
	  NSDebugLog(@"Saving %@", className);
	  if (![classManager makeSourceAndHeaderFilesForClass: className
			     withName: sourceName
			     and: headerName])
	    {
	      NSRunAlertPanel(_(@"Alert"), 
			      _(@"Could not create the class's file"),
			      nil, nil, nil);
	    }
	  
	  return self;
	}
    }
  return nil;
}

/**
 * Close anEditor for anObject.
 */ 
- (void) editor: (id<IBEditors,IBSelectionOwners>)anEditor didCloseForObject: (id)anObject
{
  NSArray		*links;

  /*
   * If there is a link from this editor to a parent, remove it.
   */
  links = [self connectorsForSource: anEditor
			    ofClass: [GormEditorToParent class]];
  NSAssert([links count] < 2, NSInternalInconsistencyException);
  if ([links count] == 1)
    {
      [connections removeObjectIdenticalTo: [links objectAtIndex: 0]];
    }

  /*
   * Remove the connection linking the object to this editor
   */
  links = [self connectorsForSource: anObject
			    ofClass: [GormObjectToEditor class]];
  NSAssert([links count] < 2, NSInternalInconsistencyException);
  if ([links count] == 1)
    {
      [connections removeObjectIdenticalTo: [links objectAtIndex: 0]];
    }

  /*
   * Add to the master list of editors for this document
   */
  [openEditors removeObjectIdenticalTo: anEditor];

  /*
   * Make sure that this editor is not the selection owner.
   */
  if ([(id<IB>)NSApp selectionOwner] == 
      anEditor)
    {
      [self resignSelectionForEditor: anEditor];
    }
}

/**
 * Returns an editor for anObject, if flag is YES, it creates a new
 * editor, if one doesn't currently exist.
 */
- (id<IBEditors>) editorForObject: (id)anObject
                           create: (BOOL)flag
{
  return [self editorForObject: anObject inEditor: nil create: flag];
}

/**
 * Returns the editor for anObject, in the editor anEditor.  If flag is
 * YES, an editor is created if one doesn't already exist.
 */
- (id<IBEditors>) editorForObject: (id)anObject
                         inEditor: (id<IBEditors>)anEditor
                           create: (BOOL)flag
{
  NSArray	*links;

  /*
   * Look up the editor links for the object to see if it already has an
   * editor.  If it does return it, otherwise create a new editor and a
   * link to it if the flag is set.
   */
  links = [self connectorsForSource: anObject
			    ofClass: [GormObjectToEditor class]];
  if ([links count] == 0 && flag == YES)
    {
      Class		eClass = NSClassFromString([anObject editorClassName]);
      id<IBEditors>	editor;
      id<IBConnectors>	link;

      editor = [[eClass alloc] initWithObject: anObject inDocument: self];
      link = AUTORELEASE([[GormObjectToEditor alloc] init]);
      [link setSource: anObject];
      [link setDestination: editor];
      [connections addObject: link];
      
      if(![openEditors containsObject: editor] && editor != nil)
	{
	  [openEditors addObject: editor];
	}

      if (anEditor == nil)
	{
	  /*
	   * By default all editors are owned by the top-level editor of
	   * the document.
           */
	  anEditor = objectsView;
	}
      if (anEditor != editor)
	{
	  /*
	   * Link to the parent of the editor.
	   */
	  link = AUTORELEASE([[GormEditorToParent alloc] init]);
	  [link setSource: editor];
	  [link setDestination: anEditor];
	  [connections addObject: link];
	}
      else
	{
	  NSDebugLog(@"WARNING anEditor = editor");
	}

      [editor activate];
      RELEASE((NSObject *)editor);

      return editor;
    }
  else if ([links count] == 0)
    {
      return nil;
    }
  else
    {
      [[[links lastObject] destination] activate];
      return [[links lastObject] destination];
    }
}

/**
 * Stop the archiving process.
 */
- (void) endArchiving
{
  NSEnumerator		*enumerator;
  id<IBConnectors>	con;
  id			obj;

  /*
   * Restore class versions.
   */
  [filePrefsManager restoreClassVersions];

  /*
   * Restore removed objects.
   */
  [nameTable setObject: filesOwner forKey: @"NSOwner"];
  NSMapInsert(objToName, (void*)filesOwner, (void*)@"NSOwner");

  [nameTable setObject: firstResponder forKey: @"NSFirst"];
  NSMapInsert(objToName, (void*)firstResponder, (void*)@"NSFirst");

  /*
   * Map all connector source and destination names to their objects.
   */
  enumerator = [connections objectEnumerator];
  while ((con = [enumerator nextObject]) != nil)
    {
      NSString	*name;
      name = (NSString*)[con source];
      obj = [self objectForName: name];
      [con setSource: obj];
      name = (NSString*)[con destination];
      obj = [self objectForName: name];
      [con setDestination: obj];
    }

  /*
   * Restore editor links and reactivate the editors.
   */
  [connections addObjectsFromArray: savedEditors];
  enumerator = [savedEditors objectEnumerator];
  while ((con = [enumerator nextObject]) != nil)
    {
      if ([[con source] isKindOfClass: [NSView class]] == NO)
	[[con destination] activate];
    }
  [savedEditors removeAllObjects];
}

/**
 * Forces the closing of all editors in the document.
 */
- (void) closeAllEditors
{
  NSEnumerator		*enumerator;
  id<IBConnectors>	con;
  NSMutableArray        *editors = [NSMutableArray array];

  // remove the editor connections from the connection array...
  enumerator = [connections objectEnumerator];
  while ((con = [enumerator nextObject]) != nil)
    {
      if ([con isKindOfClass: [GormObjectToEditor class]] == YES)
	{
	  [editors addObject: con];
	}
      else if ([con isKindOfClass: [GormEditorToParent class]] == YES)
	{
	  [editors addObject: con];
	}
    }
  [connections removeObjectsInArray: editors];
  [editors removeAllObjects];

  // Close all of the editors & get all of the objects out.
  // copy the array, since the close method calls editor:didCloseForObject:
  // and would effect the array during the execution of 
  // makeObjectsPerformSelector:.
  [editors addObjectsFromArray: openEditors];
  [editors makeObjectsPerformSelector: @selector(close)]; 
  [openEditors removeAllObjects];
  // [editors makeObjectsPerformSelector: @selector(release)];
  [editors removeAllObjects];

  // Close the editors in the document window...
  // don't worry about the "classesView" since it's not really an
  // editor.
  [objectsView close];
  [imagesView close];
  [soundsView close];
}

/**
 * Handle all notifications.   Checks the value of [aNotification name]
 * against the set of notifications this class responds to and takes
 * appropriate action.
 */
- (void) handleNotification: (NSNotification*)aNotification
{
  NSString *name = [aNotification name];
  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];

  if ([name isEqual: NSWindowWillCloseNotification] == YES)
    {
      NSEnumerator	*enumerator;
      id		obj;
      
      enumerator = [nameTable objectEnumerator];
      while ((obj = [enumerator nextObject]) != nil)
	{
	  /*
	  if ([obj isKindOfClass: [NSMenu class]] == YES)
	    {
	      if ([[obj window] isVisible] == YES)
		{
		  [obj close];
		}
	    }
	    else 
	  */
	  if ([obj isKindOfClass: [NSWindow class]] == YES)
	    {
	      // [obj setReleasedWhenClosed: YES];
	      [obj close];
	      RELEASE(obj);
	    }
	}

      // deactivate the document...
      [self setDocumentActive: NO];
      [self closeAllEditors]; // shut down all of the editors..
      [nc postNotificationName: IBWillCloseDocumentNotification object: self];
      [nc removeObserver: self]; // stop listening to all notifications.
    }
  else if ([name isEqual: NSWindowDidBecomeKeyNotification] == YES)
    {
      [self setDocumentActive: YES];
    }
  else if ([name isEqual: NSWindowWillMiniaturizeNotification] == YES)
    {
      [self setDocumentActive: NO];
    }
  else if ([name isEqual: NSWindowDidDeminiaturizeNotification] == YES)
    {
      [self setDocumentActive: YES];
    }
  else if ([name isEqual: IBWillBeginTestingInterfaceNotification] == YES)
    {
      if ([window isVisible] == YES)
	{
	  [hidden addObject: window];
	  [window setExcludedFromWindowsMenu: YES];
	  [window orderOut: self];
	}
      if ([(id<IB>)NSApp activeDocument] == self)
	{
	  NSEnumerator	*enumerator;
	  id		obj;

	  enumerator = [nameTable objectEnumerator];
	  while ((obj = [enumerator nextObject]) != nil)
	    {
	      if ([obj isKindOfClass: [NSMenu class]] == YES)
		{
		  if ([[obj window] isVisible] == YES)
		    {
		      [hidden addObject: obj];
		      [obj close];
		    }
		}
	      else if ([obj isKindOfClass: [NSWindow class]] == YES)
		{
		  if ([obj isVisible] == YES)
		    {
		      [hidden addObject: obj];
		      [obj orderOut: self];
		    }
		}
	    }
	}
    }
  else if ([name isEqual: IBWillEndTestingInterfaceNotification] == YES)
    {
      if ([hidden count] > 0)
	{
	  NSEnumerator	*enumerator;
	  id		obj;

	  enumerator = [hidden objectEnumerator];
	  while ((obj = [enumerator nextObject]) != nil)
	    {
	      if ([obj isKindOfClass: [NSMenu class]] == YES)
		{
		  [obj display];
		}
	      else if ([obj isKindOfClass: [NSWindow class]] == YES)
		{
		  [obj orderFront: self];
		}
	    }
	  [hidden removeAllObjects];
	  [window setExcludedFromWindowsMenu: NO];
	}
    }
  else if ([name isEqual: IBClassNameChangedNotification] == YES)
    {
      [classesView reloadData];
      [self setSelectionFromEditor: nil];
      [self touch];
    }
  else if ([name isEqual: IBInspectorDidModifyObjectNotification] == YES)
    {
      [classesView reloadData];
      [self touch];
    }
  else if ([name isEqual: GormDidModifyClassNotification] == YES)
    {
      if ([classesView isEditing] == NO) 
	{
	  [classesView reloadData];
	}
    }
  else if ([name isEqual: GormDidAddClassNotification])
    {
      NSArray *customClasses = [classManager allCustomClassNames];
      NSString *newClass = [customClasses lastObject];

      // go to the class which was just loaded in the classes view...
      [classesView reloadData];
      [self changeToViewWithTag: 3];

      if(newClass != nil)
	{
	  [classesView selectClass: newClass];
	}
    }
  else if([name isEqual: IBResourceManagerRegistryDidChangeNotification])
    {
      if(resourceManagers != nil)
	{
	  Class cls = [aNotification object];
	  id mgr = [(IBResourceManager *)[cls alloc] initWithDocument: self];
	  [resourceManagers addObject: mgr];
	}
    }
}

/**
 * Create an instance of a given class.
 */
- (id) instantiateClass: (id)sender
{
  NSString *object = [classesView selectedClassName];
  GSNibItem *item = nil;
  
  if([object isEqualToString: @"FirstResponder"])
    return nil;
  
  if([classManager isSuperclass: @"NSView" linkedToClass: object] ||
     [object isEqual: @"NSView"])
    {
      Class cls;
      NSString *className = object;
      BOOL isCustom = [classManager isCustomClass: object];
      id instance;
      
      if(isCustom)
	{
	  className = [classManager nonCustomSuperClassOf: object];
	}
      
      // instantiate the object or it's substitute...
      cls = NSClassFromString(className);
      if([cls respondsToSelector: @selector(allocSubstitute)])
	{
	  instance = [cls allocSubstitute];
	}
      else
	{
	  instance = [cls alloc];
	}
      
      // give it some initial dimensions...
      if([instance respondsToSelector: @selector(initWithFrame:)])
	{
	  instance = [instance initWithFrame: NSMakeRect(10,10,380,280)];
	}
      else
	{
	  instance = [instance init];
	}
      
      // add it to the top level objects...
      [self setName: nil forObject: instance];
      [self attachObject: instance toParent: nil];
      
      // we want to record if it's custom or not and act appropriately...
      if(isCustom)
	{
	  NSString *name = [self nameForObject: instance];
	  [classManager setCustomClass: object
			forName: name];
	}

      [self changeToViewWithTag: 0];
      NSLog(@"Instantiate NSView subclass %@",object);	      
    }
  else
    {
      item = [[GormObjectProxy alloc] initWithClassName: object
				      frame: NSMakeRect(0,0,0,0)];
      
      [self setName: nil forObject: item];
      [self attachObject: item toParent: nil];      
      [self changeToViewWithTag: 0];
    }
  
  return self;
}

/**
 * Returns YES, if document is active.
 */
- (BOOL) isActive
{
  return isActive;
}

/**
 * Returns the name for anObject.
 */
- (NSString*) nameForObject: (id)anObject
{
  return (NSString*)NSMapGet(objToName, (void*)anObject);
}

/**
 * Returns the object for name.
 */
- (id) objectForName: (NSString*)name
{
  return [nameTable objectForKey: name];
}

/**
 * Returns all objects in the document.
 */
- (NSArray*) objects
{
  return [nameTable allValues];
}

/**
 * Returns YES, if the current select on the classes view is a class.
 */
- (BOOL) classIsSelected
{
  return [classesView currentSelectionIsClass];
}

/**
 * Remove all instances of a given class.
 */
- (void) removeAllInstancesOfClass: (NSString *)className
{
  [objectsView removeAllInstancesOfClass: className];
}

/**
 * Select a class in the classes view
 */
- (void) selectClass: (NSString *)className
{
  [classesView selectClass: className];
}

/**
 * Select a class in the classes view
 */
- (void) selectClass: (NSString *)className editClass: (BOOL)flag
{
  [classesView selectClass: className editClass: flag];
}

/** 
 * The sole purpose of this method is to clean up .gorm files from older
 * versions of Gorm which might have some dangling references.   This method
 * may be added to as time goes on to make sure that it's possible 
 * to repair old .gorm files.
 */
- (void) _repairFile
{
  NSEnumerator *en = [[nameTable allKeys] objectEnumerator];
  NSString *key = nil;
  
  NSRunAlertPanel(_(@"Warning"), 
		  _(@"You are running with 'GormRepairFileOnLoad' set to YES."),
		  nil, nil, nil);

  while((key = [en nextObject]) != nil)
  {
    id obj = [nameTable objectForKey: key];
    if([obj isKindOfClass: [NSMenu class]] && ![key isEqual: @"NSMenu"])
      {
	id sm = [obj supermenu];
	if(sm == nil)
	  {
	    NSArray *menus = findAll(obj);
	    NSLog(@"Found and removed a dangling menu %@, %@.",obj,[self nameForObject: obj]);
	    [self detachObjects: menus];
	    [self detachObject: obj];
	    
	    // Since the menu is a top level object, it is not retained by
	    // anything else.  When it was unarchived it was autoreleased, and
	    // the detach also does a release.  Unfortunately, this causes a
	    // crash, so this extra retain is only here to stave off the 
	    // release, so the autorelease can release the menu when it should.
	    RETAIN(obj); // extra retain to stave off autorelease...
	  }
      }

    if([obj isKindOfClass: [NSMenuItem class]])
      {
	id m = [obj menu];
	if(m == nil)
	  {
	    id sm = [obj submenu];

	    NSLog(@"Found and removed a dangling menu item %@, %@.",obj,[self nameForObject: obj]);
	    [self detachObject: obj];

	    // if there are any submenus, detach those as well.
	    if(sm != nil)
	      {
		NSArray *menus = findAll(sm);
		[self detachObjects: menus];
	      }
	  }
      }

    /**
     * If it's a view and it does't have a window *AND* it's not a top level object
     * then it's not a standalone view, it's an orphan.   Delete it.
     */
    if([obj isKindOfClass: [NSView class]])
      {
	if([obj window] == nil && 
	   [topLevelObjects containsObject: obj] == NO &&
	   [obj hasSuperviewKindOfClass: [NSTabView class]] == NO)
	  {
	    NSLog(@"Found and removed an orphan view %@, %@",obj,[self nameForObject: obj]);
	    [self detachObject: obj];
	  }
      }
  }
}

/**
 * Private method.  Determines if the document contains an instance of a given
 * class or one of it's subclasses.
 */
- (BOOL) _containsKindOfClass: (Class)cls
{
  NSEnumerator *en = [nameTable objectEnumerator];
  id obj = nil;
  while((obj = [en nextObject]) != nil)
    {
      if([obj isKindOfClass: cls])
	{
	  return YES;
	}
    }
  return NO;
}

/**
 * This assumes we have an empty document to start with - the loaded
 * document is merged in to it.
 */
- (id) loadDocument: (NSString*)aFile
{
  NS_DURING
    {
      NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
      NSMutableDictionary	*nt;
      NSMutableDictionary	*cc;
      NSData		        *data;
      NSUnarchiver		*u;
      GSNibContainer	        *c;
      NSEnumerator		*enumerator;
      id <IBConnectors>	         con;
      NSString                  *ownerClass, *key;
      NSFileManager	        *mgr = [NSFileManager defaultManager];
      BOOL                       isDir = NO;
      NSDirectoryEnumerator     *dirEnumerator;
      BOOL                       repairFile = [[NSUserDefaults standardUserDefaults] boolForKey: @"GormRepairFileOnLoad"];
      NSMenu                    *mainMenu;
      NSString                  *ext = [aFile pathExtension];
      GormPalettesManager       *palettesManager = [(id<Gorm>)NSApp palettesManager];
      NSDictionary              *substituteClasses = [palettesManager substituteClasses];
      NSEnumerator              *en = [substituteClasses keyEnumerator];
      NSString                  *subClassName = nil;
      unsigned int           	version = NSNotFound;

      // If someone attempts to open a .gmodel using open or in a 
      // workspace manager, open it.. otherwise open the .gorm file.
      if([ext isEqual: @"gmodel"])
	{
	  return [self openGModel: aFile];
	}
      
      if ([mgr fileExistsAtPath: aFile isDirectory: &isDir])
	{
	  // if the data is in a directory, then load from objects.gorm 
	  if (isDir == NO)
	    {
	      NSString *lastComponent = [aFile lastPathComponent];
	      NSString *parent = [aFile stringByDeletingLastPathComponent];
	      NSString *parentExt = [parent pathExtension];
	      
	      // test if we're doing it wrong...
	      if([lastComponent isEqual: @"objects.gorm"] && 
		 [parentExt isEqual: @"gorm"])
		{
		  NSRunAlertPanel(_(@"Problem Loading"),
				  _(@"Cannot load directly from objects.gorm file, please load from the gorm package."),
				  _(@"OK"), nil, nil);
		  return nil;
		}
	      
	      data = [NSData dataWithContentsOfFile: aFile];
	      NSDebugLog(@"Loaded data from file...");
	    }
	  else
	    {
	      NSString *newFileName;
	      
	      newFileName = [aFile stringByAppendingPathComponent: @"objects.gorm"];
	      data = [NSData dataWithContentsOfFile: newFileName];
	      NSDebugLog(@"Loaded data from %@...", newFileName);
	    }
	}
      else
	{
	  // no file exists...
	  data = nil;
	}
      
      // check the data...
      if (data == nil)
	{
	  NSRunAlertPanel(_(@"Problem Loading"),
			  [NSString stringWithFormat: @"Could not read '%@' data", aFile],
			  _(@"OK"), nil, nil);
	  return nil;
	}
      
      /*
       * Create an unarchiver, and use it to unarchive the nib file while
       * handling class replacement so that standard objects understood
       * by the gui library are converted to their Gorm internal equivalents.
       */
      u = [[NSUnarchiver alloc] initForReadingWithData: data];
      
      // special internal classes
      [u decodeClassName: @"GSNibContainer" 
	 asClassName: @"GormDocument"];
      [u decodeClassName: @"GSNibItem" 
	 asClassName: @"GormObjectProxy"];
      [u decodeClassName: @"GSCustomView" 
	 asClassName: @"GormCustomView"];

      while((subClassName = [en nextObject]) != nil)
	{
	  NSString *realClassName = [substituteClasses objectForKey: subClassName];
	  [u decodeClassName: realClassName
	     asClassName: subClassName];
	}

      [GSClassSwapper setIsInInterfaceBuilder: YES]; // turn off custom classes.
      c = [u decodeObject];
      if (c == nil || [c isKindOfClass: [GSNibContainer class]] == NO)
	{
	  NSRunAlertPanel(_(@"Problem Loading"), 
			  _(@"Could not unarchive document data"), 
			  _(@"OK"), nil, nil);
	  return nil;
	}
      [GSClassSwapper setIsInInterfaceBuilder: NO]; // turn on custom classes.
      
      // retrieve the custom class data...
      cc = [[c nameTable] objectForKey: GSCustomClassMap];
      if (cc == nil)
	{
	  cc = [NSMutableDictionary dictionary]; // create an empty one.
	  [[c nameTable] setObject: cc forKey: GSCustomClassMap];
	}
      [classManager setCustomClassMap: cc];
      NSDebugLog(@"cc = %@", cc);
      NSDebugLog(@"customClasses = %@", [classManager customClassMap]);
      
      // convert from old file format...
      if (isDir == NO)
	{
	  NSString	*s;
	  
	  s = [aFile stringByDeletingPathExtension];
	  s = [s stringByAppendingPathExtension: @"classes"];
	  if (![classManager loadCustomClasses: s])
	    {
	      NSRunAlertPanel(_(@"Problem Loading"), 
			      _(@"Could not open the associated classes file.\n"
				@"You won't be able to edit connections on custom classes"), 
			      _(@"OK"), nil, nil);
	    }
	}
      else
	{
	  NSString	*s;
	  
	  s = [aFile stringByAppendingPathComponent: @"data.classes"];
	  if (![classManager loadCustomClasses: s]) 
	    {
	      NSRunAlertPanel(_(@"Problem Loading"), 
			      _(@"Could not open the associated classes file.\n"
				@"You won't be able to edit connections on custom classes"), 
			      _(@"OK"), nil, nil);
	    }

	  s = [aFile stringByAppendingPathComponent: @"data.info"];
	  if (![filePrefsManager loadFromFile: s])
	    {
	      NSLog(@"Loading gorm without data.info file.  Default settings will be assumed.");
	    }
	  else
	    {
	      int version = [filePrefsManager version];
	      int currentVersion = [GormFilePrefsManager currentVersion];

	      if(version > currentVersion)
		{
		  int retval = NSRunAlertPanel(_(@"Gorm Build Mismatch"),
					       _(@"The file being loaded was created with a newer build, continue?"), 
					       _(@"OK"), 
					       _(@"Cancel"), 
					       nil,
					       nil);
		  if(retval != NSAlertDefaultReturn)
		    {
		      return nil;
		    }
		}
	    }
	}
      
      [classesView reloadData];
      
      /*
       * In the newly loaded nib container, we change all the connectors
       * to hold the objects rather than their names (using our own dummy
       * object as the 'NSOwner'.
       */
      ownerClass = [[c nameTable] objectForKey: @"NSOwner"];
      if (ownerClass)
	[filesOwner setClassName: ownerClass];
      [[c nameTable] setObject: filesOwner forKey: @"NSOwner"];
      [[c nameTable] setObject: firstResponder forKey: @"NSFirst"];
      
      /* Iterate over the contents of nameTable and create the connections */
      nt = [c nameTable];
      enumerator = [[c connections] objectEnumerator];
      while ((con = [enumerator nextObject]) != nil)
	{
	  NSString  *name;
	  id        obj;
	  
	  name = (NSString*)[con source];
	  obj = [nt objectForKey: name];
	  [con setSource: obj];
	  name = (NSString*)[con destination];
	  obj = [nt objectForKey: name];
	  [con setDestination: obj];
	}
      
      /*
       * If the GSNibContainer version is 0, we need to add the top level objects
       * to the list so that they can be properly processed.
       */
      if([u versionForClassName: NSStringFromClass([GSNibContainer class])] == 0)
	{
	  id obj;
	  NSEnumerator *en = [nt objectEnumerator];

	  // get all of the GSNibItem subclasses which could be top level objects
	  while((obj = [en nextObject]) != nil)
	    {
	      if([obj isKindOfClass: [GSNibItem class]] &&
		 [obj isKindOfClass: [GSCustomView class]] == NO)
		{
		  [topLevelObjects addObject: obj];
		}
	    }
	  isOlderArchive = YES;
	}

      /*
       * Now we merge the objects from the nib container into our own data
       * structures, taking care not to overwrite our NSOwner and NSFirst.
       */
      [nt removeObjectForKey: @"NSOwner"];
      [nt removeObjectForKey: @"NSFirst"];
      [topLevelObjects addObjectsFromArray: [[c topLevelObjects] allObjects]];
      [connections addObjectsFromArray: [c connections]];
      [nameTable addEntriesFromDictionary: nt];
      [self rebuildObjToNameMapping];

      /*
       * If the GSWindowTemplate version is 0, we need to let Gorm know that this is
       * an older archive.  Also, if the window template is not in the archive we know
       * it was made by an older version of Gorm.
       */
      version = [u versionForClassName: NSStringFromClass([GSWindowTemplate class])];
      if(version == NSNotFound && [self _containsKindOfClass: [NSWindow class]])
	{
	  isOlderArchive = YES;
	}

      /*
       * repair the .gorm file, if needed.
       */
      if(repairFile == YES)
	{
	  [self _repairFile];
	}
      
      /*
       * set our new file name
       */
      ASSIGN(documentPath, aFile);
      [window setTitleWithRepresentedFilename: documentPath];
      
      /*
       * read in all of the sounds in the .gorm wrapper and
       * load them into the editor.
       */
      dirEnumerator = [mgr enumeratorAtPath: documentPath];
      if (dirEnumerator)
	{
	  NSString *file = nil;
	  NSArray  *fileTypes = [NSSound soundUnfilteredFileTypes];
	  while ((file = [dirEnumerator nextObject]))
	    {
	      if ([fileTypes containsObject: [file pathExtension]])
		{
		  NSString *soundPath;
		  
		  NSDebugLog(@"Add the sound %@", file);
		  soundPath = [documentPath stringByAppendingPathComponent: file];
		  [soundsView addObject: [GormSound soundForPath: soundPath inWrapper: YES]];
		}
	    }
	}
      
      /*
       * read in all of the images in the .gorm wrapper and
       * load them into the editor.
       */
      dirEnumerator = [mgr enumeratorAtPath: documentPath];
      if (dirEnumerator)
	{
	  NSString *file = nil;
	  NSArray  *fileTypes = [NSImage imageFileTypes];
	  while ((file = [dirEnumerator nextObject]))
	    {
	      if ([fileTypes containsObject: [file pathExtension]])
		{
		  NSString	*imagePath;
		  
		  NSDebugLog(@"Add the image %@", file);
		  imagePath = [documentPath stringByAppendingPathComponent: file];
		  [imagesView addObject: [GormImage imageForPath: imagePath inWrapper: YES]];
		}
	    }
	}
      
      NSDebugLog(@"nameTable = %@",[c nameTable]);
      
      // awaken all elements after the load is completed.
      enumerator = [[c nameTable] keyEnumerator];
      while ((key = [enumerator nextObject]) != nil)
	{
	  id o = [[c nameTable] objectForKey: key];
	  if ([o respondsToSelector: @selector(awakeFromDocument:)])
	    {
	      [o awakeFromDocument: self];
	    }
	}

      // reposition the loaded menu appropriately...
      mainMenu = [nameTable objectForKey: @"NSMenu"];
      if(mainMenu != nil)
	{
	  NSRect frame = [window frame];
	  NSPoint origin = frame.origin;
	  NSRect menuFrame = [[mainMenu window] frame];

	  // account for the height of the menu we're loading.
	  origin.y += (frame.size.height + menuFrame.size.height + 150);
	  
	  // place the main menu appropriately...
	  [[mainMenu window] setFrameTopLeftPoint: origin];
	}

      // this is the last thing we should do...
      [nc postNotificationName: IBDidOpenDocumentNotification
	  object: self];
      
      // document opened...
      isDocumentOpen = YES;

      // release the unarchiver.. now that we're all done...
      RELEASE(u);
    }
  NS_HANDLER
    {
      NSRunAlertPanel(_(@"Problem Loading"), 
		      [NSString stringWithFormat: @"Failed to load file.  Exception: %@",[localException reason]], 
		      _(@"OK"), nil, nil);
      return nil; // This will cause the calling method to release the document.
    }
  NS_ENDHANDLER

  return self;
}

/**
 * Build our reverse mapping information and other initialisation
 */
- (void) rebuildObjToNameMapping
{
  NSEnumerator  *enumerator;
  NSString	*name;
  id            o;

  NSDebugLog(@"------ Rebuilding object to name mapping...");
  NSResetMapTable(objToName);
  NSMapInsert(objToName, (void*)filesOwner, (void*)@"NSOwner");
  NSMapInsert(objToName, (void*)firstResponder, (void*)@"NSFirst");
  enumerator = [[nameTable allKeys] objectEnumerator];
  while ((name = [enumerator nextObject]) != nil)
    {
      id obj = [nameTable objectForKey: name];
      
      NSDebugLog(@"%@ --> %@",name, obj);

      NSMapInsert(objToName, (void*)obj, (void*)name);
      if (([obj isKindOfClass: [NSMenu class]] && [name isEqual: @"NSMenu"]) || [obj isKindOfClass: [NSWindow class]])
	{
	  [[self openEditorForObject: obj] activate];
	}
    }

  // All of the entries in the items array are "top level items" 
  // which should be visible in the object's view. 
  enumerator = [topLevelObjects objectEnumerator];
  while((o = [enumerator nextObject]) != nil)
    {
      [objectsView addObject: o];
    }
}

/**
 * This assumes we have an empty document to start with - the loaded
 * document is merged in to it.
 */
- (id) openDocument: (id)sender
{
  NSArray	*fileTypes;
  NSOpenPanel	*oPanel = [NSOpenPanel openPanel];
  int		result;
  NSString      *pth = [[NSUserDefaults standardUserDefaults] 
			 objectForKey:@"OpenDir"];
  
  fileTypes = [NSArray arrayWithObjects: @"gorm", @"gmodel", nil];
  [oPanel setAllowsMultipleSelection: NO];
  [oPanel setCanChooseFiles: YES];
  [oPanel setCanChooseDirectories: NO];
  result = [oPanel runModalForDirectory: pth
				   file: nil
				  types: fileTypes];
  if (result == NSOKButton)
    {
      NSString *filename  = [oPanel filename];
      NSString *ext       = [filename pathExtension];
      BOOL     uniqueName = [(id<Gorm>)NSApp documentNameIsUnique: filename];

      if(uniqueName)
	{
	  [[NSUserDefaults standardUserDefaults] setObject: [oPanel directory]
						 forKey:@"OpenDir"];
	  if ([ext isEqualToString:@"gorm"] || [ext isEqualToString:@"nib"])
	    {
	      return [self loadDocument: filename];
	    }
	  else if ([ext isEqualToString:@"gmodel"])
	    {
	      return [self openGModel: filename];
	    }
	}
      else
	{
	  // if we get this far, we didn't succeed..
	  NSRunAlertPanel(_(@"Problem Loading"),
			  _(@"Attempted to load a model which is already opened."), 
			  _(@"OK"), nil, nil);
	}
    }

  return nil; /* Failed */
}

/**
 * Open the editor for anObject.
 */
- (id<IBEditors>) openEditorForObject: (id)anObject
{
  id<IBEditors>	e = [self editorForObject: anObject create: YES];
  id<IBEditors, IBSelectionOwners> p = [self parentEditorForEditor: e];
  
  if (p != nil && p != objectsView)
    {
      [self openEditorForObject: [p editedObject]];
    }

  // prevent bringing front of menus before they've been properly sized.
  if([anObject isKindOfClass: [NSMenu class]] == NO) 
    {
      [e orderFront];
      [[e window] makeKeyAndOrderFront: self];
    }

  return e;
}

/**
 * Return the parent editor for anEditor.
 */
- (id<IBEditors, IBSelectionOwners>) parentEditorForEditor: (id<IBEditors>)anEditor
{
  NSArray		*links;
  GormObjectToEditor	*con;

  links = [self connectorsForSource: anEditor
			    ofClass: [GormEditorToParent class]];
  con = [links lastObject];
  return [con destination];
}

/**
 * Return the parent of anObject.
 */
- (id) parentOfObject: (id)anObject
{
  NSArray		*old;
  id<IBConnectors>	con;

  old = [self connectorsForSource: anObject ofClass: [NSNibConnector class]];
  con = [old lastObject];
  if ([con destination] != filesOwner && [con destination] != firstResponder)
    {
      return [con destination];
    }
  return nil;
}

/**
 * Paste objects of aType into the document from aPasteboard 
 * with parent as the parent of the objects.
 */
- (NSArray*) pasteType: (NSString*)aType
        fromPasteboard: (NSPasteboard*)aPasteboard
                parent: (id)parent
{
  NSData	*data;
  NSArray	*objects;
  NSEnumerator	*enumerator;
  NSPoint	filePoint;
  NSPoint	screenPoint;
  NSUnarchiver *u;

  data = [aPasteboard dataForType: aType];
  if (data == nil)
    {
      NSDebugLog(@"Pasteboard %@ doesn't contain data of %@", aPasteboard, aType);
      return nil;
    }
  u = AUTORELEASE([[NSUnarchiver alloc] initForReadingWithData: data]);
  [u decodeClassName: @"GSCustomView" 
     asClassName: @"GormCustomView"];
  objects = [u decodeObject];
  enumerator = [objects objectEnumerator];
  filePoint = [window mouseLocationOutsideOfEventStream];
  screenPoint = [window convertBaseToScreen: filePoint];

  /*
   * Windows and panels are a special case - for a multiple window paste,
   * the windows need to be positioned so they are not on top of each other.
   */
  if ([aType isEqualToString: IBWindowPboardType])
    {
      NSWindow	*win;

      while ((win = [enumerator nextObject]) != nil)
	{
	  [win setFrameTopLeftPoint: screenPoint];
	  screenPoint.x += 10;
	  screenPoint.y -= 10;
	}
    }
  else if([aType isEqualToString: IBViewPboardType]) 
    {
      NSEnumerator *enumerator = [objects objectEnumerator];
      NSRect frame;
      id obj;

      while ((obj = [enumerator nextObject]) != nil)
      {
	// check to see if the object has a frame.  If so, then
	// modify it.  If not, simply iterate to the next object
	if([obj respondsToSelector: @selector(frame)]
	   && [obj respondsToSelector: @selector(setFrame:)])
	  {
	    frame = [obj frame];
	    frame.origin.x -= 6;
	    frame.origin.y -= 6;
	    [obj setFrame: frame];
	    RETAIN(obj);
	  }
      } 
    }

  // attach the objects to the parent and touch the document.
  [self attachObjects: objects toParent: parent];
  [self touch];

  return objects;
}

/**
 * Remove aConnector from the connections array and send the
 * notifications.
 */
- (void) removeConnector: (id<IBConnectors>)aConnector
{
  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];

  RETAIN(aConnector); // prevent it from being dealloc'd until the notification is done.
  // issue pre notification..
 [nc postNotificationName: IBWillRemoveConnectorNotification
      object: aConnector];

  // mark the document as changed.
  [self touch];

  // issue post notification..
  [connections removeObjectIdenticalTo: aConnector];
  [nc postNotificationName: IBDidRemoveConnectorNotification
      object: aConnector];
  RELEASE(aConnector); // NOW we can dealloc it.
}

/**
 * The editor wants to give up the selection.  Go through all the known
 * editors (with links in the connections array) and try to find one
 * that wants to take over the selection.  Activate whatever editor we
 * find (if any).
 */
- (void) resignSelectionForEditor: (id<IBEditors>)editor
{
  NSEnumerator		*enumerator = [connections objectEnumerator];
  Class			editClass = [GormObjectToEditor class];
  id<IBConnectors>	c;

  while ((c = [enumerator nextObject]) != nil)
    {
      if ([c class] == editClass)
	{
	  id<IBEditors>	e = [c destination];

	  if (e != editor && [e wantsSelection] == YES)
	    {
	      [e activate];
	      [self setSelectionFromEditor: e];
	      return;
	    }
	}
    }
  /*
   * No editor available to take the selection - set a nil owner.
   */
  [self setSelectionFromEditor: nil];
}

/**
 * Creates a blank document depending on the value of type.
 * If type is "Application", "Inspector" or "Palette" it creates 
 * an appropriate blank document for the user to start with.
 */
- (void) setupDefaults: (NSString*)type
{
  if (hasSetDefaults == YES)
    {
      return;
    }
  hasSetDefaults = YES;
  if ([type isEqual: @"Application"] == YES)
    {
      NSMenu	*aMenu;
      NSWindow	*aWindow;
      NSRect    winFrame = [window frame];
      NSPoint   origin = winFrame.origin;
      NSRect	frame = [[NSScreen mainScreen] frame];
      unsigned	style = NSTitledWindowMask | NSClosableWindowMask
                        | NSResizableWindowMask | NSMiniaturizableWindowMask;

      origin.y += (winFrame.size.height + 150);

      if ([NSMenu respondsToSelector: @selector(allocSubstitute)])
	{
	  aMenu = [[NSMenu allocSubstitute] init];
	}
      else
	{
	  aMenu = [[NSMenu alloc] init];
	}

      if ([NSWindow respondsToSelector: @selector(allocSubstitute)])
	{
	  aWindow = [[NSWindow allocSubstitute]
		      initWithContentRect: NSMakeRect(0,0,600, 400)
		      styleMask: style
		      backing: NSBackingStoreRetained
		      defer: NO];
	}
      else
	{
	  aWindow = [[NSWindow alloc]
		      initWithContentRect: NSMakeRect(0,0,600, 400)
		      styleMask: style
		      backing: NSBackingStoreRetained
		      defer: NO];
	}
      [aWindow setFrameTopLeftPoint:
	NSMakePoint(220, frame.size.height-100)];
      [aWindow setTitle: _(@"My Window")]; 
      [self setName: @"My Window" forObject: aWindow];
      [self attachObject: aWindow toParent: nil];
      [self setObject: aWindow isVisibleAtLaunch: YES];

      [aMenu setTitle: _(@"Main Menu")];
      [aMenu addItemWithTitle: _(@"Hide") 
		       action: @selector(hide:)
		keyEquivalent: @"h"];	
      [aMenu addItemWithTitle: _(@"Quit") 
		       action: @selector(terminate:)
		keyEquivalent: @"q"];

      // the first menu attached becomes the main menu.
      [self attachObject: aMenu toParent: nil]; 
      [[aMenu window] setFrameTopLeftPoint: origin];
    }
  else if ([type isEqual: @"Inspector"] == YES)
    {
      NSPanel	*aWindow;
      NSRect	frame = [[NSScreen mainScreen] frame];
      unsigned	style = NSTitledWindowMask | NSClosableWindowMask;

      if ([NSPanel respondsToSelector: @selector(allocSubstitute)])
	{
	  aWindow = [[NSPanel allocSubstitute] 
		      initWithContentRect: NSMakeRect(0,0, IVW, IVH)
		      styleMask: style
		      backing: NSBackingStoreRetained
		      defer: NO];
	}
      else
	{
	  aWindow = [[NSPanel alloc] 
		      initWithContentRect: NSMakeRect(0,0, IVW, IVH)
		      styleMask: style
		      backing: NSBackingStoreRetained
		      defer: NO];
	}

      [aWindow setFrameTopLeftPoint:
		 NSMakePoint(220, frame.size.height-100)];
      [aWindow setTitle: _(@"Inspector Window")];
      [self setName: @"InspectorWin" forObject: aWindow];
      [self attachObject: aWindow toParent: nil];
    }
  else if ([type isEqual: @"Palette"] == YES)
    {
      NSPanel	*aWindow;
      NSRect	frame = [[NSScreen mainScreen] frame];
      unsigned	style = NSTitledWindowMask | NSClosableWindowMask;

      if ([NSPanel respondsToSelector: @selector(allocSubstitute)])
	{
	  aWindow = [[NSPanel allocSubstitute] 
		      initWithContentRect: NSMakeRect(0,0,272,160)
		      styleMask: style
		      backing: NSBackingStoreRetained
		      defer: NO];
	}
      else
	{
	  aWindow = [[NSPanel alloc] 
		      initWithContentRect: NSMakeRect(0,0,272,160)
		      styleMask: style
		      backing: NSBackingStoreRetained
		      defer: NO];
	}

      [aWindow setFrameTopLeftPoint:
		 NSMakePoint(220, frame.size.height-100)];
      [aWindow setTitle: _(@"Palette Window")];
      [self setName: @"PaletteWin" forObject: aWindow];
      [self attachObject: aWindow toParent: nil];
    }

  [self touch];
}

/**
 * Set aName for object in the document.  If aName is nil,
 * a name is automatically created for object.
 */
- (void) setName: (NSString*)aName forObject: (id)object
{
  id		       oldObject = nil;
  NSString	      *oldName = nil;
  NSMutableDictionary *cc = [classManager customClassMap];
  NSString            *className = nil;

  if (object == nil)
    {
      NSDebugLog(@"Attempt to set name for nil object");
      return;
    }

  if (aName == nil)
    {
      /*
       * No name given - so we must generate one unless we already have one.
       */
      oldName = [self nameForObject: object];
      if (oldName == nil)
	{
	  NSString	*base;
	  unsigned	i = 0;

	  /*
	   * Generate a sensible name for the object based on its class.
	   */
	  if ([object isKindOfClass: [GSNibItem class]])
	    {
	      // use the actual class name for proxies
	      base = [(id)object className];
	    }
	  else
	    {
	      base = NSStringFromClass([object class]);
	    }
	  if ([base hasPrefix: @"NS"] || [base hasPrefix: @"GS"])
	    {
	      base = [base substringFromIndex: 2];
	    }
	  aName = base;
	  while ([nameTable objectForKey: aName] != nil)
	    {
	      aName = [base stringByAppendingFormat: @"%u", ++i];
	    }
	}
      else
	{
	  return; /* Already named ... nothing to do */
	}
    }
  else // user supplied a name...
    {
      oldObject = [nameTable objectForKey: aName];
      if (oldObject != nil)
	{
	  NSDebugLog(@"Attempt to re-use name '%@'", aName);
	  return;
	}
      oldName = [self nameForObject: object];
      if (oldName != nil)
	{
	  if ([oldName isEqual: aName] == YES)
	    {
	      return; /* Already have this name ... nothing to do */
	    }
	  [nameTable removeObjectForKey: oldName];
	  NSMapRemove(objToName, (void*)object);
	}
    }

  // add it to the dictionary.
  [nameTable setObject: object forKey: aName];
  NSMapInsert(objToName, (void*)object, (void*)aName);
  if (oldName != nil)
    {
      RETAIN(oldName); // hold on to this temporarily...
      [nameTable removeObjectForKey: oldName];
    }
  if ([objectsView containsObject: object] == YES)
    {
      [objectsView refreshCells];
    }

  // check the custom classes map and replace the appropriate
  // object, if a mapping exists.
  if(cc != nil)
    {
      className = [cc objectForKey: oldName];
      if(className != nil)
	{
	  [cc removeObjectForKey: oldName];
	  [cc setObject: className forKey: aName]; 
	}
    }

  // release oldName, if we get to this point.
  if(oldName != nil)
    {
      RELEASE(oldName);
    }
}

/**
 * Add object to the visible at launch list.
 */
- (void) setObject: (id)anObject isVisibleAtLaunch: (BOOL)flag
{
  NSMutableArray	*a = [nameTable objectForKey: @"NSVisible"];

  if (flag == YES)
    {
      if (a == nil)
	{
	  a = [[NSMutableArray alloc] init];
	  [nameTable setObject: a forKey: @"NSVisible"];
	  RELEASE(a);
	}
      if ([a containsObject: anObject] == NO)
	{
	  [a addObject: anObject];
	}
    }
  else
    {
      [a removeObject: anObject];
    }
}

/**
 * Return YES, if anObject is visible at launch time.
 */
- (BOOL) objectIsVisibleAtLaunch: (id)anObject
{
  return [[nameTable objectForKey: @"NSVisible"] containsObject: anObject];
}

/**
 * Add anObject to the deferred list.
 */
- (void) setObject: (id)anObject isDeferred: (BOOL)flag
{
  NSMutableArray	*a = [nameTable objectForKey: @"NSDeferred"];

  if (flag == YES)
    {
      if (a == nil)
	{
	  a = [[NSMutableArray alloc] init];
	  [nameTable setObject: a forKey: @"NSDeferred"];
	  RELEASE(a);
	}
      if ([a containsObject: anObject] == NO)
	{
	  [a addObject: anObject];
	}
    }
  else
    {
      [a removeObject: anObject];
    }
}

/**
 * Return YES, if the anObject is in the deferred list.
 */
- (BOOL) objectIsDeferred: (id)anObject
{
  return [[nameTable objectForKey: @"NSDeferred"] containsObject: anObject];
}

// windows / services menus...

/**
 * Set the windows menu.
 */
- (void) setWindowsMenu: (NSMenu *)anObject 
{
  if(anObject != nil)
    {
      [nameTable setObject: anObject forKey: @"NSWindowsMenu"];
    }
  else
    {
      [nameTable removeObjectForKey: @"NSWindowsMenu"];
    }
}

/**
 * return the windows menu.
 */ 
- (NSMenu *) windowsMenu
{
  return [nameTable objectForKey: @"NSWindowsMenu"];
}

/**
 * Set the object that will be the services menu in the app.
 */
- (void) setServicesMenu: (NSMenu *)anObject
{
  if(anObject != nil)
    {
      [nameTable setObject: anObject forKey: @"NSServicesMenu"];
    }
  else
    {
      [nameTable removeObjectForKey: @"NSServicesMenu"];
    }
}

/**
 * Return the object that will be the services menu.
 */
- (NSMenu *) servicesMenu
{
  return [nameTable objectForKey: @"NSServicesMenu"];
}

/**
 * To revert to a saved version, we actually load a new document and
 * close the original document, returning the id of the new document.
 */
- (id) revertDocument: (id)sender
{
  GormDocument	*reverted = AUTORELEASE([[GormDocument alloc] init]);

  if ([reverted loadDocument: documentPath] != nil)
    {
      NSRect	frame = [window frame];

      [window close];
      [[reverted window] setFrame: frame display: YES];
      return reverted;
    }
  return nil;
}

/**
 * Save the document.  If this is called when documentPath is nil, 
 * then saveGormDocument: will call it to define the path.
 */
- (BOOL) saveAsDocument: (id)sender
{
  NSSavePanel		*sp;
  int			result;

  sp = [NSSavePanel savePanel];
  [sp setRequiredFileType: @"gorm"];
  result = [sp runModalForDirectory: NSHomeDirectory() file: @""];
  if (result == NSOKButton)
    {
      NSFileManager	*mgr = [NSFileManager defaultManager];
      NSString		*path = [sp filename];

      if ([path isEqual: documentPath] == NO
	&& [mgr fileExistsAtPath: path] == YES)
	{
	  /* NSSavePanel has already asked if it's ok to replace */
	  NSString	*bPath = [path stringByAppendingString: @"~"];
	  
	  [mgr removeFileAtPath: bPath handler: nil];
	  [mgr movePath: path toPath: bPath handler: nil];
	}

      // set the path...
      ASSIGN(documentPath, path);
      return [self saveGormDocument: sender];
    }
  return NO;
}

/**
 * Private method which iterates through the list of custom classes and instructs 
 * the archiver to replace the actual object with template during the archiving 
 * process.
 */
- (void) _replaceObjectsWithTemplates: (NSArchiver *)archiver
{
  GormClassManager *cm = [self classManager];
  NSEnumerator *en = [[self nameTable] keyEnumerator];
  id key = nil;

  // loop through all custom objects and windows
  while((key = [en nextObject]) != nil)
    {
      id customClass = [cm customClassForName: key];
      id object = [self objectForName: key];
      id template = nil;
      if(customClass != nil)
	{
	  NSString *superClass = [cm nonCustomSuperClassOf: customClass];
	  template = [GSTemplateFactory templateForObject: object
					withClassName: customClass 
					withSuperClassName: superClass];
	}
      else if([object isKindOfClass: [NSWindow class]] 
	      && [filePrefsManager versionOfClass: @"GSWindowTemplate"] > 0)
	{
	  template = [GSTemplateFactory templateForObject: object
					withClassName: [object className]
					withSuperClassName: [object className]]; 
	  
	}

      // if the template has been created, replace the object with it.
      if(template != nil)
	{
	  // if the object is deferrable, then set the flag appropriately.
	  if([template respondsToSelector: @selector(setDeferFlag:)])
	    {
	      [template setDeferFlag: [self objectIsDeferred: object]];
	    }
	  
	  //  if the object can accept autoposition information
	  if([object respondsToSelector: @selector(autoPositionMask)])
	    {
	      int mask = [object autoPositionMask];
	      if([template respondsToSelector: @selector(setAutoPositionMask:)])
		{
		  [template setAutoPositionMask: mask];
		}
	    }

	  // replace the object with the template.
	  [archiver replaceObject: object withObject: template];
	}
    }
}

/**
 * Save the document.  This method creates the directory and the files needed
 * to comprise the .gorm package.
 */
- (BOOL) saveGormDocument: (id)sender
{
  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
  BOOL			archiveResult;
  NSArchiver            *archiver;
  NSMutableData         *archiverData;
  NSString              *gormPath;
  NSString              *classesPath;
  NSString              *infoPath;
  NSFileManager         *mgr = [NSFileManager defaultManager];
  BOOL                  isDir;
  BOOL                  fileExists;
  int                   retval;
  GormPalettesManager   *palettesManager = [(id<Gorm>)NSApp palettesManager];
  NSDictionary          *substituteClasses = [palettesManager substituteClasses];
  NSEnumerator          *en = [substituteClasses keyEnumerator];
  NSString              *subClassName = nil;
  
  if (documentPath == nil)
    {
      // if no path has been defined... define one.
      return ([self saveAsDocument: sender]);
    }

  // Warn the user about possible incompatibility.
  // TODO: Remove after the next release of GUI.
  if(isOlderArchive && [filePrefsManager isLatest])
    {
      retval = NSRunAlertPanel(_(@"Compatibility Warning"), 
			       _(@"Saving will update this gorm to the latest version, which is not compatible with GNUstep's gui 0.9.5 (or earlier) Release or CVS prior to June 2 2005."),
			       _(@"Save"),
			       _(@"Don't Save"), nil, nil);
      if (retval != NSAlertDefaultReturn)
	{
	  return NO;
	}
      else
	{
	  // we're saving anyway... set to new value.
	  isOlderArchive = NO;
	}
    }

  [nc postNotificationName: IBWillSaveDocumentNotification
		    object: self];

  [self beginArchiving];

  // set up the necessary paths...
  gormPath = [documentPath stringByAppendingPathComponent: @"objects.gorm"];
  classesPath = [documentPath stringByAppendingPathComponent: @"data.classes"];
  infoPath = [documentPath stringByAppendingPathComponent: @"data.info"];

  archiverData = [NSMutableData dataWithCapacity: 0];
  archiver = [[NSArchiver alloc] initForWritingWithMutableData: archiverData];

  /* Special gorm classes to their archive equivalents. */
  // NOTE: GSNibContainer replaces GormDocument using classforCoder
  [archiver encodeClassName: @"GormObjectProxy" 
	    intoClassName: @"GSNibItem"];
  [archiver encodeClassName: @"GormCustomView"
	    intoClassName: @"GSCustomView"];

  while((subClassName = [en nextObject]) != nil)
    {
      NSString *realClassName = [substituteClasses objectForKey: subClassName];
      [archiver encodeClassName: subClassName
		intoClassName: realClassName];
    }


  [self _replaceObjectsWithTemplates: archiver];

  [archiver encodeRootObject: self];
  NSDebugLog(@"nameTable = %@",nameTable);
  NSDebugLog(@"customClasses = %@", [classManager customClassMap]);

  fileExists = [mgr fileExistsAtPath: documentPath isDirectory: &isDir];
  if (fileExists)
    {
      if (isDir == NO)
	{
	  NSString *saveFilePath;

	  saveFilePath = [documentPath stringByAppendingPathExtension: @"save"];
	  // move the old file to something...
	  if (![mgr movePath: documentPath toPath: saveFilePath handler: nil])
	    {
	      NSDebugLog(@"Error moving old %@ file to %@",
	      	documentPath, saveFilePath);
	    }
	  
	  // create the new directory..
	  archiveResult = [mgr createDirectoryAtPath: documentPath
	 				  attributes: nil];
	}
      else
	{
	  // set to yes since the directory is already present.
	  archiveResult = YES;
	}
    }
  else
    {
      // create the directory...
      archiveResult = [mgr createDirectoryAtPath: documentPath attributes: nil];
    }
  
  RELEASE(archiver); // We're done with the archiver here..

  if (archiveResult)
    {
      // save the data...
      archiveResult = [archiverData writeToFile: gormPath atomically: YES]; 
      if (archiveResult) 
	{
	  // save the custom classes.. and we're done...
	  archiveResult = [classManager saveToFile: classesPath];
	  
	  // save the file prefs metadata...
	  if (archiveResult)
	    {
	      archiveResult = [filePrefsManager saveToFile: infoPath];
	    }

	  //
	  // Copy resources into the new folder...
	  // Gorm doesn't copy these into the folder right away since the folder may
	  // not yet exist.   This allows the user to add/delete resources as they see fit
	  // but only those which they end up with will actually be put into the wrapper
	  // when the model/document is saved.
	  //
	  if (archiveResult)
	    {
	      NSArray *sounds = [soundsView objects];
	      NSArray *images = [imagesView objects];
	      NSArray *resources = [sounds arrayByAddingObjectsFromArray: images];
	      
	      id object = nil;
	      NSEnumerator *en = [resources objectEnumerator];
	      while ((object = [en nextObject]) != nil)
		{
		  if(![object isSystemResource])
		    {
		      NSString *rscPath;
		      NSString *path = [object path];
		      BOOL copied = NO;
		      
		      rscPath = [documentPath stringByAppendingPathComponent:
						[path lastPathComponent]];
		      if(![path isEqualToString: rscPath])
			{
			  copied = [mgr copyPath: path
					toPath: rscPath
					handler: nil];
			  if(copied)
			    {
			      [object setInWrapper: YES];
			      [object setPath: rscPath];
			    }
			}
		      else
			{
			  // mark as copied if paths are equal...
			  copied = YES;
			  [object setInWrapper: YES];
			}
		      
		      if (!copied)
			{
			  NSDebugLog(@"Could not find resource at path %@", object);
			}
		    }
		}
	    }
	}
    }

  [self endArchiving];

  if (archiveResult == NO)
    {
      NSRunAlertPanel(_(@"Problem Saving"),
		      _(@"Could not save document"), 
		      _(@"OK"), nil, nil);
    }
  else
    {
      // mark the file as not edited.
      [window setDocumentEdited: NO];
      [window setTitleWithRepresentedFilename: documentPath];

      // notify everyone of the save.
      [nc postNotificationName: IBDidSaveDocumentNotification
			object: self];
    }
  return YES;
}

/**
 * Marks this document as the currently active document.  The active document is
 * the one being edited by the user.
 */
- (void) setDocumentActive: (BOOL)flag
{
  if (flag != isActive && isDocumentOpen)
    {
      NSEnumerator	*enumerator;
      id		obj;

      // stop all connection activities.
      [(id<Gorm>)NSApp stopConnecting];

      enumerator = [nameTable objectEnumerator];
      if (flag == YES)
	{
	  GormDocument *document = (GormDocument*)[(id<IB>)NSApp activeDocument];

	  // set the current document active and unset the old one.
	  [document setDocumentActive: NO];
	  isActive = YES;

	  // display everything.
	  while ((obj = [enumerator nextObject]) != nil)
	    {
	      NSString *name = [document nameForObject: obj];
	      if ([obj isKindOfClass: [NSWindow class]] == YES)
		{
		  [obj orderFront: self];
		}
	      else if ([obj isKindOfClass: [NSMenu class]] && 
		       [name isEqual: @"NSMenu"] == YES)
		{
		  [obj display];
		}
	    }

	  //
	  // Reset the selection to the current selection held by the current
	  // selection owner of this document when the document becomes active.
	  // This allows the app to switch to the correct inspector when the new
	  // document is selected.
	  //
	  [self setSelectionFromEditor: lastEditor];
	}
      else
	{
	  isActive = NO;
	  while ((obj = [enumerator nextObject]) != nil)
	    {
	      if ([obj isKindOfClass: [NSWindow class]] == YES)
		{
		  [obj orderOut: self];
		}
	      else if ([obj isKindOfClass: [NSMenu class]] == YES &&
		       [[self nameForObject: obj] isEqual: @"NSMenu"] == YES)
		{
		  [obj close];
		}
	    }
	  [self setSelectionFromEditor: nil];
	}
    }
}

/**
 * Sets the current selection from the given editor.  This method
 * causes the inspector to refresh with the proper object.
 */
- (void) setSelectionFromEditor: (id<IBEditors>)anEditor
{
  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];

  NSDebugLog(@"setSelectionFromEditor %@", anEditor);
  ASSIGN(lastEditor, anEditor);
  [(id<Gorm>)NSApp stopConnecting]; // cease any connection
  if ([(NSObject *)anEditor respondsToSelector: @selector(window)])
    {
      [[anEditor window] makeKeyWindow];
      [[anEditor window] makeFirstResponder: (id)anEditor];
    }
  [nc postNotificationName: IBSelectionChangedNotification
		    object: anEditor];
}

/**
 * Mark the document as modified.
 */
- (void) touch
{
  [window setDocumentEdited: YES];
}

/**
 * Returns the window and the rect r for object.
 */
- (NSWindow*) windowAndRect: (NSRect*)r forObject: (id)object
{
  /*
   * Get the window and rectangle for which link markup should be drawn.
   */
  if ([objectsView containsObject: object] == YES)
    {
      /*
       * objects that exist in the document objects view must have their link
       * markup drawn there, so we ask the view for the required rectangle.
       */
      *r = [objectsView rectForObject: object];
      return [objectsView window];
    }
  else if ([object isKindOfClass: [NSMenuItem class]] == YES)
    {
      NSArray	*links;
      NSMenu	*menu;
      id	editor;

      /*
       * Menu items must have their markup drawn in the window of the
       * editor of the parent menu.
       */
      links = [self connectorsForSource: object
				ofClass: [NSNibConnector class]];
      menu = [[links lastObject] destination];
      editor = [self editorForObject: menu create: NO];
      *r = [editor rectForObject: object];
      return [editor window];
    }
  else if ([object isKindOfClass: [NSView class]] == YES)
    {
      /*
       * Normal view objects just get link markup drawn on them.
       */
      id temp = object;
      id editor = [self editorForObject: temp create: NO];
      
      while ((temp != nil) && (editor == nil))
	{
	  temp = [temp superview];
	  editor = [self editorForObject: temp create: NO];
	}

      if (temp == nil)
	{
	  *r = [object convertRect: [object bounds] toView: nil];
	}
      else if ([editor respondsToSelector: 
			 @selector(windowAndRect:forObject:)])
	{
	  return [editor windowAndRect: r forObject: object];
	}
    }
  else if ([object isKindOfClass: [NSTableColumn class]] == YES)
    {
      NSTableView *tv = [[(NSTableColumn*)object dataCell] controlView];
      NSTableHeaderView *th =  [tv headerView];
      int index;

      if (th == nil || tv == nil)
	{
	  NSDebugLog(@"fail 1 %@ %@ %@", [(NSTableColumn*)object headerCell], th, tv);
	  *r = NSZeroRect;
	  return nil;
	}
      
      index = [[tv tableColumns] indexOfObject: object];

      if (index == NSNotFound)
	{
	  NSDebugLog(@"fail 2");
	  *r = NSZeroRect;
	  return nil;
	}
      
      *r = [th convertRect: [th headerRectOfColumn: index]
	       toView: nil];
      return [th window];
    }
  else
    {
      *r = NSZeroRect;
      return nil;
    }

  // never reached, keeps gcc happy
  return nil;
}

/**
 * The document window.
 */
- (NSWindow*) window
{
  return window;
}

/**
 * Determine if the document should be closed or not.
 */
- (BOOL) couldCloseDocument
{
  if ([window isDocumentEdited] == YES)
    {
      NSString	*msg;
      int	result;

      if (documentPath == nil)
	{
	  msg = _(@"Document 'UNTITLED' has been modified");
	}
      else
	{
	  msg = [NSString stringWithFormat: _(@"Document '%@' has been modified"),
	    [documentPath lastPathComponent]];
	}
      result = NSRunAlertPanel(_(@"Close Document"), 
			       msg, 
			       _(@"Save"), 
			       _(@"Don't Save"), 
			       _(@"Cancel"));

      if (result == NSAlertDefaultReturn) 
	{ 	  
	  //Save
	  if (! [self saveGormDocument: self] )
	    {
	      return NO;
	    }
	  else
	    {
	      isDocumentOpen = NO;
	    }
	}
      else if (result == NSAlertOtherReturn)
	{
	  //Cancel
	  return NO;
	}
      else // Don't save...
	{
	  isDocumentOpen = NO;
	}
    }

  return YES;
}

/**
 * Called when the document window close is selected.
 */
- (BOOL) windowShouldClose: (id)sender
{
  return [self couldCloseDocument];
}

/**
 * Removes all connections given action or outlet with the specified label 
 * (paramter name) class name (parameter className). 
 */
- (BOOL) removeConnectionsWithLabel: (NSString *)name
		      forClassNamed: (NSString *)className
			   isAction: (BOOL)action
{
  NSEnumerator *en = [connections objectEnumerator];
  NSMutableArray *removedConnections = [NSMutableArray array];
  id<IBConnectors> c = nil;
  BOOL removed = YES;
  BOOL prompted = NO;

  // find connectors to be removed.
  while ((c = [en nextObject]) != nil)
    {
      id proxy = nil;
      NSString *proxyClass = nil;
      NSString *label = [c label];

      if(label == nil)
	continue;

      if (action)
	{
	  if (![label hasSuffix: @":"]) 
	    continue;

	  if (![classManager isAction: label ofClass: className])
	    continue;

	  proxy = [c destination];
	}
      else
	{
	  if ([label hasSuffix: @":"]) 
	    continue;

	  if (![classManager isOutlet: label ofClass: className])
	    continue;

	  proxy = [c source];
	}
      
      // get the class for the current connectors object
      proxyClass = [proxy className];

      if ([label isEqualToString: name] && ([proxyClass isEqualToString: className] ||
	  [classManager isSuperclass: className linkedToClass: proxyClass]))
	{
	  NSString *title;
	  NSString *msg;
	  int retval;

	  if(prompted == NO)
	    {
	      title = [NSString stringWithFormat:
				  @"Modifying %@",(action==YES?@"Action":@"Outlet")];
	      msg = [NSString stringWithFormat:
				_(@"This will break all connections to '%@'.  Continue?"), name];
	      retval = NSRunAlertPanel(title, msg,_(@"OK"),_(@"Cancel"), nil, nil);
	      prompted = YES;
	    }

	  if (retval == NSAlertDefaultReturn)
	    {
	      removed = YES;
	      [removedConnections addObject: c];
	    }
	  else
	    {
	      removed = NO;
	      break;
	    }
	}
    }

  // actually remove the connections.
  if(removed)
    {
      en = [removedConnections objectEnumerator];
      while((c = [en nextObject]) != nil)
	{
	  [self removeConnector: c];
	}
    }

  // done...
  NSDebugLog(@"Removed references to %@ on %@", name, className);
  return removed;
}

/**
 * Remove all connections to any and all instances of className.
 */
- (BOOL) removeConnectionsForClassNamed: (NSString *)className
{
  NSEnumerator *en = nil; 
  id<IBConnectors> c = nil;
  BOOL removed = YES;
  int retval = -1;
  NSString *title = [NSString stringWithFormat: _(@"Modifying Class")];
  NSString *msg;

  msg = [NSString stringWithFormat: _(@"This will break all connections to "
    @"actions/outlets to instances of class '%@' and it's subclasses.  Continue?"), className];

  // ask the user if he/she wants to continue...
  retval = NSRunAlertPanel(title, msg,_(@"OK"),_(@"Cancel"), nil, nil);
  if (retval == NSAlertDefaultReturn)
    {
      removed = YES;
    }
  else
    {
      removed = NO;
    }

  // remove all.
  if(removed)
    {
      NSMutableArray *removedConnections = [NSMutableArray array];

      // first find all of the connections...
      en = [connections objectEnumerator];
      while ((c = [en nextObject]) != nil)
	{
	  NSString *srcClass = [[c source] className];
	  NSString *dstClass = [[c destination] className];

	  if ([srcClass isEqualToString: className] ||
	      [classManager isSuperclass: className linkedToClass: srcClass] ||
	      [dstClass isEqualToString: className] ||
	      [classManager isSuperclass: className linkedToClass: dstClass])
	    {
	      [removedConnections addObject: c];
	    }
	}

      // then remove them.
      en = [removedConnections objectEnumerator];
      while((c = [en nextObject]) != nil)
	{
	  [self removeConnector: c];
	}
    }
  
  // done...
  NSDebugLog(@"Removed references to actions/outlets for objects of %@",
    className);
  return removed;
}

/**
 * Rename connections connected to an instance of on class to another.
 */
- (BOOL) renameConnectionsForClassNamed: (NSString *)className
				 toName: (NSString *)newName
{
  NSEnumerator *en = [connections objectEnumerator];
  id<IBConnectors> c = nil;
  BOOL renamed = YES;
  int retval = -1;
  NSString *title = [NSString stringWithFormat: _(@"Modifying Class")];
  NSString *msg = [NSString stringWithFormat: 
			      _(@"Change class name '%@' to '%@'.  Continue?"),
			    className, newName];

  // ask the user if he/she wants to continue...
  retval = NSRunAlertPanel(title, msg,_(@"OK"),_(@"Cancel"), nil, nil);
  if (retval == NSAlertDefaultReturn)
    {
      renamed = YES;
    }
  else
    {
      renamed = NO;
    }

  // remove all.
  if(renamed)
    {
      while ((c = [en nextObject]) != nil)
	{
	  id source = [c source];
	  id destination = [c destination];
	  
	  // check both...
	  if ([[[c source] className] isEqualToString: className])
	    {
	      [source setClassName: newName];
	      NSDebugLog(@"Found matching source");
	    }
	  else if ([[[c destination] className] isEqualToString: className])
	    {
	      [destination setClassName: newName];
	      NSDebugLog(@"Found matching destination");
	    }
	}
    }

  // done...
  NSDebugLog(@"Changed references to actions/outlets for objects of %@", className);
  return renamed;
}


/**
 * Print out all editors for debugging purposes.
 */
- (void) printAllEditors
{
  NSMutableSet	        *set = [NSMutableSet setWithCapacity: 16];
  NSEnumerator		*enumerator = [connections objectEnumerator];
  id<IBConnectors>	c;

  while ((c = [enumerator nextObject]) != nil)
    {
      if ([GormObjectToEditor class] == [c class])
	{
	  [set addObject: [c destination]];
	}
    }

  NSLog(@"all editors %@", set);
}

/**
 * Open a sound and load it into the document.
 */
- (id) openSound: (id)sender
{
  NSArray	*fileTypes = [NSSound soundUnfilteredFileTypes]; 
  NSArray	*filenames;
  NSString	*filename;
  NSOpenPanel	*oPanel = [NSOpenPanel openPanel];
  int		result;
  int		i;

  [oPanel setAllowsMultipleSelection: YES];
  [oPanel setCanChooseFiles: YES];
  [oPanel setCanChooseDirectories: NO];
  result = [oPanel runModalForDirectory: nil
				   file: nil
				  types: fileTypes];
  if (result == NSOKButton)
    {
      filenames = [oPanel filenames];
      for (i=0; i<[filenames count]; i++)
      {
        filename = [filenames objectAtIndex:i];
        NSDebugLog(@"Loading sound file: %@",filenames);
        [soundsView addObject: [GormSound soundForPath: filename]];
      }
      return self;
    }

  return nil;
}

/**
 * Open an image and copy it into the document.
 */
- (id) openImage: (id)sender
{
  NSArray	*fileTypes = [NSImage imageFileTypes]; 
  NSArray	*filenames;
  NSOpenPanel	*oPanel = [NSOpenPanel openPanel];
  NSString	*filename;
  int		result;
  int		i;

  [oPanel setAllowsMultipleSelection: YES];
  [oPanel setCanChooseFiles: YES];
  [oPanel setCanChooseDirectories: NO];
  result = [oPanel runModalForDirectory: nil
				   file: nil
				  types: fileTypes];
  if (result == NSOKButton)
    {
      filenames = [oPanel filenames];
      for (i=0; i<[filenames count]; i++)
      {
        filename = [filenames objectAtIndex:i];
        NSDebugLog(@"Loading image file: %@",filename);
        [imagesView addObject: [GormImage imageForPath: filename]];
      }
      return self;
    }

  return nil;
}

/**
 * Return a text description of the document.
 */
- (NSString *) description
{
  return [NSString stringWithFormat: @"<%s: %lx> = %@",
		   GSClassNameFromObject(self), 
		   (unsigned long)self,
		   nameTable];
}

/**
 * Returns YES, if obj is a top level object.
 */
- (BOOL) isTopLevelObject: (id)obj
{
  return [topLevelObjects containsObject: obj];
}

/**
 * Return first responder stand in.
 */
- (id) firstResponder
{
  return firstResponder;
}

/**
 * Return font manager stand in.
 */
- (id) fontManager
{
  return fontManager;
}

/**
 * Create resource manager instances for all registered classes.
 */
- (void) createResourceManagers
{
  NSArray *resourceClasses = [IBResourceManager registeredResourceManagerClassesForFramework: nil];
  NSEnumerator *en = [resourceClasses objectEnumerator];
  Class cls = nil;
  
  if(resourceManagers != nil)
    {
      // refresh...
      DESTROY(resourceManagers);
    }
  
  resourceManagers = [[NSMutableArray alloc] init];
  while((cls = [en nextObject]) != nil)
    {
      id mgr = AUTORELEASE([(IBResourceManager *)[cls alloc] initWithDocument: self]);
      [resourceManagers addObject: mgr];
    }
}

/**
 * The list of all resource managers.
 */
- (NSArray *) resourceManagers
{
  return resourceManagers;
}

/**
 * Get the resource manager which handles the content on pboard.
 */
- (IBResourceManager *) resourceManagerForPasteboard: (NSPasteboard *)pboard
{
  NSEnumerator *en = [resourceManagers objectEnumerator];
  IBResourceManager *mgr = nil, *result = nil;
  
  while((mgr = [en nextObject]) != nil)
    {
      if([mgr acceptsResourcesFromPasteboard: pboard])
	{
	  result = mgr;
	  break;
	}
    }

  return result;
}

/**
 * Get all pasteboard types managed by the resource manager.
 */
- (NSArray *) allManagedPboardTypes
{
  NSMutableArray *allTypes = [[NSMutableArray alloc] initWithObjects: NSFilenamesPboardType,
						     GormLinkPboardType, 
						     nil];
  NSArray *mgrs = [self resourceManagers];
  NSEnumerator *en = [mgrs objectEnumerator];
  IBResourceManager *mgr = nil;
  
  AUTORELEASE(allTypes);

  while((mgr = [en nextObject]) != nil)
    {
      NSArray *pbTypes = [mgr resourcePasteboardTypes];
      [allTypes addObjectsFromArray: pbTypes]; 
    }
  
  return allTypes;
}

// language translation methods.

/**
 * This method collects all of the objects in the document.
 */
- (NSArray *) _collectAllObjects
{
  NSMutableArray *allObjects = [NSMutableArray arrayWithArray: [topLevelObjects allObjects]];
  NSEnumerator *en = [topLevelObjects objectEnumerator];
  NSMutableArray *removeObjects = [NSMutableArray array];
  id obj = nil;
  
  // collect all subviews/menus/etc.
  while((obj = [en nextObject]) != nil)
    {
      if([obj isKindOfClass: [NSWindow class]])
	{
	  NSMutableArray *views = [NSMutableArray array];
	  NSEnumerator *ven = [views objectEnumerator];
	  id vobj = nil;
	  
	  subviewsForView([(NSWindow *)obj contentView], views);
	  [allObjects addObjectsFromArray: views];
	  
	  while((vobj = [ven nextObject]))
	    {
	      if([vobj isKindOfClass: [GormCustomView class]])
		{
		  [removeObjects addObject: vobj];
		}
	      else if([vobj isKindOfClass: [NSMatrix class]])
		{
		  [allObjects addObjectsFromArray: [vobj cells]];
		}
	      else if([vobj isKindOfClass: [NSPopUpButton class]])
		{
		  [allObjects addObjectsFromArray: [vobj itemArray]];
		}
	      else if([vobj isKindOfClass: [NSTabView class]])
		{
		  [allObjects addObjectsFromArray: [vobj tabViewItems]];
		}
	    }
	}
      else if([obj isKindOfClass: [NSMenu class]])
	{
	  [allObjects addObjectsFromArray: findAll(obj)];
	}
    }

  // take out objects which shouldn't be considered.
  [allObjects removeObjectsInArray: removeObjects];

  return allObjects;
}

/**
 * This method is used to translate all of the strings in the file from one language
 * into another.  This is helpful when attempting to translate an application for use
 * in different locales.
 */
- (void) translate
{
  NSArray	*fileTypes = [NSArray arrayWithObjects: @"strings", nil];
  NSOpenPanel	*oPanel = [NSOpenPanel openPanel];
  int		result;

  [oPanel setAllowsMultipleSelection: NO];
  [oPanel setCanChooseFiles: YES];
  [oPanel setCanChooseDirectories: NO];
  result = [oPanel runModalForDirectory: nil
				   file: nil
				  types: fileTypes];
  if (result == NSOKButton)
    {
      NSMutableArray *allObjects = [self _collectAllObjects];
      NSString *filename = [oPanel filename];
      NSDictionary *dictionary = [[NSString stringWithContentsOfFile: filename] propertyListFromStringsFileFormat];
      NSEnumerator *en = [allObjects objectEnumerator];
      id obj = nil;

      // change to translated values.
      while((obj = [en nextObject]) != nil)
	{
	  NSString *translation = nil; 

	  if([obj respondsToSelector: @selector(setTitle:)] &&
	     [obj respondsToSelector: @selector(title)])
	    {
	      translation = [dictionary objectForKey: [obj title]];
	      if(translation != nil)
		{
		  [obj setTitle: translation];
		}
	    }
	  else if([obj respondsToSelector: @selector(setStringValue:)] &&
		  [obj respondsToSelector: @selector(stringValue)])
	    {
	      translation = [dictionary objectForKey: [obj stringValue]];
	      if(translation != nil)
		{
		  [obj setStringValue: translation];
		}
	    }
	  else if([obj respondsToSelector: @selector(setLabel:)] &&
		  [obj respondsToSelector: @selector(label)])
	    {
	      translation = [dictionary objectForKey: [obj label]];
	      if(translation != nil)
		{
		  [obj setLabel: translation];
		}
	    }

	  if(translation != nil)
	    {
	      if([obj isKindOfClass: [NSView class]])
		{
		  [obj setNeedsDisplay: YES];
		}

	      [self touch]; 
	    }
	  
	  // redisplay/flush, if the object is a window.
	  if([obj isKindOfClass: [NSWindow class]])
	    {
	      NSWindow *w = (NSWindow *)obj;
	      [w setViewsNeedDisplay: YES];
	      [w disableFlushWindow];
	      [[w contentView] setNeedsDisplay: YES];
	      [[w contentView] displayIfNeeded];
	      [w enableFlushWindow];
	      [w flushWindowIfNeeded];
	    }

	}
    } 
}

/**
 * This method is used to export all strings in a document to a file for Language
 * translation.  This allows the user to see all of the strings which can be translated
 * and allows the user to provide a translateion for each of them.
 */ 
- (void) exportStrings
{
  NSOpenPanel	*sp = [NSSavePanel savePanel];
  int		result;

  [sp setRequiredFileType: @"strings"];
  [sp setTitle: _(@"Save strings file as...")];
  result = [sp runModalForDirectory: NSHomeDirectory()
	       file: nil];
  if (result == NSOKButton)
    {
      NSMutableArray *allObjects = [self _collectAllObjects];
      NSString *filename = [sp filename];
      NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
      NSEnumerator *en = [allObjects objectEnumerator];
      id obj = nil;
      BOOL touched = NO;

      // change to translated values.
      while((obj = [en nextObject]) != nil)
	{
	  NSString *string = nil;
	  if([obj respondsToSelector: @selector(setTitle:)] &&
	     [obj respondsToSelector: @selector(title)])
	    {
	      string = [obj title];
	    }
	  else if([obj respondsToSelector: @selector(setStringValue:)] &&
		  [obj respondsToSelector: @selector(stringValue)])
	    {
	      string = [obj stringValue];
	    }
	  else if([obj respondsToSelector: @selector(setLabel:)] &&
		  [obj respondsToSelector: @selector(label)])
	    {
	      string = [obj label];
	    }

	  if(string != nil)
	    {
	      [dictionary setObject: string forKey: string];
	      touched = YES;
	    }
	}

      if(touched)
	{
	  NSString *stringToWrite = [dictionary descriptionInStringsFileFormat];
	  [stringToWrite writeToFile: filename atomically: YES];
	}
    } 
}

/**
 * Arrange views in front or in back of one another.
 */
- (void) arrangeSelectedObjects: (id)sender
{
  NSArray *selection =  [[(id<IB>)NSApp selectionOwner] selection];
  int tag = [sender tag];
  NSEnumerator *en = [selection objectEnumerator];
  id v = nil;

  while((v = [en nextObject]) != nil)
    {
      if([v isKindOfClass: [NSView class]])
	{
	  id editor = [self editorForObject: v create: NO];
	  if([editor respondsToSelector: @selector(superview)])
	    {
	      id superview = [editor superview];
	      if(tag == 0) // bring to front...
		{ 
		  [superview moveViewToFront: editor];
		}
	      else if(tag == 1) // send to back
		{
		  [superview moveViewToBack: editor];
		}
	      [superview setNeedsDisplay: YES];
	    }
	}
    }
}

/**
 * Align objects to center, left, right, top, bottom.
 */
- (void) alignSelectedObjects: (id)sender
{
  NSArray *selection =  [[(id<IB>)NSApp selectionOwner] selection];
  int tag = [sender tag];
  NSEnumerator *en = [selection objectEnumerator];
  id v = nil;

  id prev = nil;
  while((v = [en nextObject]) != nil)
    {
      if([v isKindOfClass: [NSView class]])
	{
	  id editor = [self editorForObject: v create: NO];
	  if(prev != nil)
	    {
	      NSRect r = [prev frame];
	      NSRect e = [editor frame];
	      if(tag == 0) // center vertically
		{
		  float center = (r.origin.x + (r.size.width / 2));
		  e.origin.x = (center - (e.size.width / 2));
		}
	      else if(tag == 1) // center horizontally
		{
		  float center = (r.origin.y + (r.size.height / 2));		  
		  e.origin.y = (center - (e.size.height / 2));  
		}
	      else if(tag == 2) // align left
		{
		  e.origin.x = r.origin.x;
		}	      
	      else if(tag == 3) // align right
		{
		  float right = (r.origin.x + r.size.width);
		  e.origin.x = (right - e.size.width);
		}	      
	      else if(tag == 4) // align top
		{
		  float top = (r.origin.y + r.size.height);
		  e.origin.y = (top - e.size.height);
		}
	      else if(tag == 5) // align bottom
		{
		  e.origin.y = r.origin.y;
		}

	      [editor setFrame: e];
	      [[editor superview] setNeedsDisplay: YES];
	    }
	  prev = editor;
	} 
    }	      
}

@end

@implementation GormDocument (MenuValidation)
- (BOOL) isEditingObjects
{
  return ([selectionBox contentView] == scrollView);
}

- (BOOL) isEditingImages
{
  return ([selectionBox contentView] == imagesScrollView);
}

- (BOOL) isEditingSounds
{
  return ([selectionBox contentView] == soundsScrollView);
}

- (BOOL) isEditingClasses
{
  return ([selectionBox contentView] == classesView);
}
@end

@implementation GormDocument (NSToolbarDelegate)

- (NSToolbarItem*)toolbar: (NSToolbar*)toolbar
    itemForItemIdentifier: (NSString*)itemIdentifier
willBeInsertedIntoToolbar: (BOOL)flag
{
  NSToolbarItem *toolbarItem = AUTORELEASE([[NSToolbarItem alloc]
					     initWithItemIdentifier: itemIdentifier]);

  if([itemIdentifier isEqual: @"ObjectsItem"])
    {
      [toolbarItem setLabel: @"Objects"];
      [toolbarItem setImage: objectsImage];
      [toolbarItem setTarget: self];
      [toolbarItem setAction: @selector(changeView:)];     
      [toolbarItem setTag: 0];
    }
  else if([itemIdentifier isEqual: @"ImagesItem"])
    {
      [toolbarItem setLabel: @"Images"];
      [toolbarItem setImage: imagesImage];
      [toolbarItem setTarget: self];
      [toolbarItem setAction: @selector(changeView:)];     
      [toolbarItem setTag: 1];
    }
  else if([itemIdentifier isEqual: @"SoundsItem"])
    {
      [toolbarItem setLabel: @"Sounds"];
      [toolbarItem setImage: soundsImage];
      [toolbarItem setTarget: self];
      [toolbarItem setAction: @selector(changeView:)];     
      [toolbarItem setTag: 2];
    }
  else if([itemIdentifier isEqual: @"ClassesItem"])
    {
      [toolbarItem setLabel: @"Classes"];
      [toolbarItem setImage: classesImage];
      [toolbarItem setTarget: self];
      [toolbarItem setAction: @selector(changeView:)];     
      [toolbarItem setTag: 3];
    }
  else if([itemIdentifier isEqual: @"FileItem"])
    {
      [toolbarItem setLabel: @"File"];
      [toolbarItem setImage: fileImage];
      [toolbarItem setTarget: self];
      [toolbarItem setAction: @selector(changeView:)];     
      [toolbarItem setTag: 4];
    }

  return toolbarItem;
}

- (NSArray*) toolbarAllowedItemIdentifiers: (NSToolbar*)toolbar
{
  return [NSArray arrayWithObjects: @"ObjectsItem", 
		  @"ImagesItem", 
		  @"SoundsItem", 
		  @"ClassesItem", 
		  @"FileItem", 
		  nil];
}

- (NSArray*) toolbarDefaultItemIdentifiers: (NSToolbar*)toolbar
{ 
  return [NSArray arrayWithObjects: @"ObjectsItem", 
		  @"ImagesItem", 
		  @"SoundsItem", 
		  @"ClassesItem", 
		  @"FileItem",
		  nil];
}

- (NSArray*) toolbarSelectableItemIdentifiers: (NSToolbar*)toolbar
{ 
  return [NSArray arrayWithObjects: @"ObjectsItem", 
		  @"ImagesItem", 
		  @"SoundsItem", 
		  @"ClassesItem", 
		  @"FileItem",
		  nil];
}
@end
