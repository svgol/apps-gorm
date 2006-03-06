/* GormPrivate.h
 *
 * Copyright (C) 1999, 2003 Free Software Foundation, Inc.
 *
 * Author:	Richard Frith-Macdonald <richard@brainstrom.co.uk>
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	1999, 2003
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

#ifndef INCLUDED_GormPrivate_h
#define INCLUDED_GormPrivate_h

#include <InterfaceBuilder/IBApplicationAdditions.h>
#include <InterfaceBuilder/IBInspector.h>
#include <InterfaceBuilder/IBViewAdditions.h>
#include <GormCore/GormFilesOwner.h>
#include <GormCore/GormDocument.h>
#include <GormCore/GormInspectorsManager.h>
#include <GormCore/GormClassManager.h>
#include <GormCore/GormPalettesManager.h>
#include <GormCore/GormProtocol.h>
#include <GormCore/GormClassEditor.h>

extern NSString *GormLinkPboardType;
extern NSString *GormToggleGuidelineNotification;
extern NSString *GormDidModifyClassNotification;
extern NSString *GormDidAddClassNotification;
extern NSString *GormDidDeleteClassNotification;
extern NSString *GormWillDetachObjectFromDocumentNotification;
extern NSString *GormResizeCellNotification;

@class	GormDocument;
@class	GormInspectorsManager;
@class	GormPalettesManager;

// templates
@interface GSNibItem (GormAdditions)
- initWithClassName: (NSString*)className frame: (NSRect)frame;
- (NSString*) className;
@end

@interface GSClassSwapper (GormCustomClassAdditions)
+ (void) setIsInInterfaceBuilder: (BOOL)flag;
- (BOOL) isInInterfaceBuilder;
@end

@interface GormObjectProxy : GSNibItem 
{
  NSImage *imageForViewer;
}
/*
 * Use a GormObjectProxy in Gorm, but encode a GSNibItem in the archive.
 * This is done so that we can provide our own decoding method
 * (GSNibItem tries to morph into the actual class)
 */
- (void) setClassName: (NSString *)className;
- (void) setImageForViewer: (NSImage *)image;
@end

@interface GormClassProxy : NSObject
{
  NSString *name;
  int t;
}

- initWithClassName: (NSString*)n;
- (NSString*) className;
- (NSString*) inspectorClassName;
- (NSString*) connectInspectorClassName;
- (NSString*) sizeInspectorClassName;
@end

/*
 * NSDateFormatter and NSNumberFormatter extensions
 * for Gorm Formatters used in the Data Palette
 */

@interface NSDateFormatter (GormAdditions)

+ (void) initialize;
+ (int) formatCount;
+ (NSString *) formatAtIndex: (int)index;
+ (int) indexOfFormat: (NSString *) format;
+ (NSString *) defaultFormat;
+ (id) defaultFormatValue;

@end

@interface NSNumberFormatter (GormAdditions)

+ (void) initialize;
+ (int) formatCount;
+ (NSString *) formatAtIndex: (int)index;
+ (NSString *) positiveFormatAtIndex: (int)index;
+ (NSString *) zeroFormatAtIndex: (int)index;
+ (NSString *) negativeFormatAtIndex: (int)index;
+ (NSDecimalNumber *) positiveValueAtIndex: (int)index;
+ (NSDecimalNumber *) negativeValueAtIndex: (int)index;
+ (int) indexOfFormat: (NSString *)format;
+ (NSString *) defaultFormat;
+ (id) defaultFormatValue;
- (NSString *) zeroFormat;

@end

@interface NSObject (GormAdditions)
- (id) allocSubstitute;
- (NSImage *) imageForViewer;
@end

@interface IBResourceManager (GormAdditions)
+ (void) registerForAllPboardTypes: (id)editor
                        inDocument: (id)document;
@end

#endif
