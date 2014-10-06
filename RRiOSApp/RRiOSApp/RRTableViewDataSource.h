//
//  RRTableViewDataSource.h
//  RRiOSApp
//
//  Created by Harlan Kellaway on 10/3/14.
//  Copyright (c) 2014 ___REFUGERESTROOMS___. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <UIKit/UIKit.h>

#import "Restroom.h"

@interface RRTableViewDataSource : NSObject <UITableViewDataSource>

@property (assign, nonatomic) NSArray *restroomsList;

- (Restroom *)restroomForIndexPath:(NSIndexPath *)indexPath;

@end
