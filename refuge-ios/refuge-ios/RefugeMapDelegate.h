//
//  RefugeMapDelegate.h
//  refuge-ios
//
//  Created by Harlan Kellaway on 2/11/15.
//  Copyright (c) 2015 Refuge Restrooms. All rights reserved.
//

#import <MapKit/MapKit.h>

@protocol RefugeMapDelegate <NSObject>

- (void)calloutAccessoryWasTappedForAnnotation:(id<MKAnnotation>)annotation;

@end
