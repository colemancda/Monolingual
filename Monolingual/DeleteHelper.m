//
//  DeleteHelper.m
//  Monolingual
//
//  Created by Ingmar Stein on Tue Mar 23 2004.
//  Copyright (c) 2004 Ingmar Stein. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//

#import "DeleteHelper.h"

@implementation DeleteHelper
//NSLock *statusLock;
BOOL removeTaskStatus;
NSSet *directories;
NSArray *roots;
NSArray *files;

- (id) initWithDirectories: (NSSet *)dirs roots: (NSArray *)r files: (NSArray *)f
{
	self = [super init];
	NSFileHandle *inputHandle = [NSFileHandle fileHandleWithStandardInput];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(cancelRemoval:) 
												 name:NSFileHandleReadCompletionNotification 
											   object:inputHandle];
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(finishedTask:) 
												 name:NSThreadWillExitNotification 
											   object:nil];
	[inputHandle readInBackgroundAndNotify];
	removeTaskStatus = FALSE;
	directories = dirs;
	roots = r;
	files = f;
	//statusLock = [[NSLock alloc] init];
	return self;
}

- (void) finishedTask: (NSNotification *)aNotification
{
	//[statusLock release];
	[files release];
	[roots release];
	[directories release];
	[NSApp terminate: self];
}

- (void) cancelRemoval: (NSNotification *)aNotification
{
	//while( ![statusLock tryLock] ) {}
	removeTaskStatus = FALSE;
	//[statusLock unlock];
}

- (void) applicationDidFinishLaunching: (NSNotification *)notification
{
	removeTaskStatus = TRUE;
	[NSThread detachNewThreadSelector: @selector(removeDirectories) toTarget: self withObject: nil];
}

- (void) fileManager: (NSFileManager *)manager willProcessPath: (NSString *)path
{
	NSDictionary *fattrs = [manager fileAttributesAtPath: path traverseLink: YES];
	printf( "%s%c%llu%c", [path fileSystemRepresentation], '\0', [fattrs fileSize], '\0' );
	fflush( stdout );
}

- (BOOL) fileManager: (NSFileManager *)manager shouldProceedAfterError: (NSDictionary *)errorInfo
{
	return( TRUE );
}

- (void) removeDirectories
{
	NSString *root;
	NSString *file;
	NSEnumerator *enumerator;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSFileManager *fileManager = [NSFileManager defaultManager];

	// delete regular files
	enumerator = [files objectEnumerator];
	while( (file = [enumerator nextObject]) ) {
		if( !removeTaskStatus ) {
			break;
		}
		[fileManager removeFileAtPath:file handler:self];
	}

	// recursively delete directories
	enumerator = [roots objectEnumerator];
	while( (root = [enumerator nextObject]) ) {
		if( removeTaskStatus ) {
			NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtPath:root];
			while( (file = [enumerator nextObject]) ) {
				//if( [statusLock tryLock] ) {
				if( !removeTaskStatus ) {
					//		[statusLock unlock];
					break;
				}
				//	[statusLock unlock];
				//}
				if( [directories containsObject: [file lastPathComponent]] ) {
					[enumerator skipDescendents];
					NSString *path = [root stringByAppendingPathComponent:file];
					[fileManager removeFileAtPath:path handler:self];
				}
			}
		} else {
			break;
		}
	}

	[pool release];
}

@end
