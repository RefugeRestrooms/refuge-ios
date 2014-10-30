//
//  RRMapViewController.m
//  RRiOSApp
//
//  Created by Harlan Kellaway on 10/14/14.
//  Copyright (c) 2014 ___REFUGERESTROOMS___. All rights reserved.
//

#import "RRMapViewController.h"
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>

#import "Constants.h"
#import "MBProgressHUD.h"
#import "MKPointAnnotation+RR.h"
#import "Restroom.h"
#import "RestroomManager.h"
#import "RestroomDetailsViewController.h"
#import "RRMapLocation.h"
#import "Reachability.h"

@interface RRMapViewController ()

@property (weak, nonatomic) IBOutlet MKMapView *mapView;

@end

@implementation RRMapViewController
{
    Reachability *internetReachability;
    CLLocationManager *locationManager;
    MBProgressHUD *hud;
    BOOL internetIsAccessible;
    BOOL initialZoomComplete;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationController.navigationBar.topItem.title = APP_NAME;
    
    // set up mapView
    self.mapView.delegate = self;
    self.mapView.mapType = MKMapTypeStandard;
    self.mapView.showsUserLocation = YES;
    
    // set up HUD
    hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.mode = MBProgressHUDAnimationFade;
    hud.color = [UIColor colorWithRed:RRCOLOR_DARKPURPLE_RED green:RRCOLOR_DARKPURPLE_GREEN blue:RRCOLOR_DARKPURPLE_BLUE alpha:1.0];
    hud.labelText = SYNC_TEXT;
    
    // set up location manager
    locationManager = [[CLLocationManager alloc] init];
    locationManager.delegate = self;
    locationManager.distanceFilter = kCLDistanceFilterNone;
    locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
    
    // set RestroomManager delegate
    RestroomManager *restroomManager = (RestroomManager *)[RestroomManager sharedInstance];
    restroomManager.delegate = self;
    
    internetIsAccessible = YES;
    initialZoomComplete = NO;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // prompt for location allowing
    if ([locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)])
    {
        [locationManager requestWhenInUseAuthorization];
    }
    else
    {
#pragma message "Should provide else case here that can run on iOS 7"
        // TODO: Test on iOS 7 device
    }
    
    [locationManager startUpdatingLocation];
    
    // check for Internet reachability
    internetReachability = [Reachability reachabilityWithHostname:URL_TO_TEST_REACHABILITY];
    
    // Internet is reachable
    internetReachability.reachableBlock = ^(Reachability*reach)
    {
        dispatch_async
        (
            // update UI on main thread
            dispatch_get_main_queue(), ^
            {
                internetIsAccessible = YES;
                
//                if(!initialZoomComplete) { [[RestroomManager sharedInstance] fetchNewRestrooms]; }
//                if(!initialZoomComplete) {
                    [[RestroomManager sharedInstance] fetchRestroomsForQuery:@"Palo Alto CA"];
//                }
            }
         );
    };

    // Internet is not reachable
    internetReachability.unreachableBlock = ^(Reachability*reach)
    {
        // Update the UI on the main thread
        dispatch_async
        (
            dispatch_get_main_queue(), ^
            {
                internetIsAccessible = NO;
                
                hud.mode = MBProgressHUDModeText;
                hud.labelText = NO_INTERNET_TEXT;
            }
         );
    };
    
    [internetReachability startNotifier];
}

- (void)plotRestrooms:(NSArray *)restrooms
{
    // remove existing annotations
    for (id<MKAnnotation> annotation in self.mapView.annotations)
    {
        [self.mapView removeAnnotation:annotation];
    }
    
    // add all annotations
    for (Restroom *restroom in restrooms)
    {
        CLLocationCoordinate2D coordinate;
        coordinate.latitude = [restroom.latitude doubleValue];
        coordinate.longitude = [restroom.longitude doubleValue];
    
        // create map location object
        RRMapLocation *mapLocation = [[RRMapLocation alloc] initWithName:restroom.name address:restroom.street coordinate:coordinate];
        mapLocation.restroom = restroom;
        
        // add annotation
        MKPointAnnotation *annotation = [mapLocation annotation];
        [self.mapView addAnnotation:annotation];
        
        [self mapView:self.mapView viewForAnnotation:annotation];
    }
}

#pragma mark - CLLocationManagerDelegate methods

-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    [locationManager stopUpdatingLocation];
    
    if(!initialZoomComplete)
    {
        // zoom to initial location
        CLLocation *location = [locationManager location];
        CLLocationCoordinate2D coordinate = [location coordinate];
    
        float longitude = coordinate.longitude;
        float latitude = coordinate.latitude;
    
        CLLocationCoordinate2D zoomLocation;
        zoomLocation.latitude = latitude;
        zoomLocation.longitude= longitude;
        MKCoordinateRegion viewRegion = [self getRegionWithZoomLocation:zoomLocation];
    
        [self.mapView setRegion:viewRegion animated:YES];
    
        [locationManager startUpdatingLocation];
        
        initialZoomComplete = YES;
    }
}

- (void) locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    [locationManager stopUpdatingLocation];
    
    if(internetIsAccessible) { hud.labelText = NO_LOCATION_TEXT; }
    [hud hide:YES afterDelay:5];
    
    hud.labelText = SYNC_TEXT;
    [hud hide:NO];
}

#pragma mark - RestroomManagerDelegate methods

- (void)didReceiveRestrooms:(NSArray *)restrooms
{
    // plot Restrooms on map
    dispatch_async
    (
        // update UI on main thread
        dispatch_get_main_queue(), ^(void)
        {
            [self plotRestrooms:restrooms];
            
            hud.mode = MBProgressHUDModeCustomView;
            hud.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:COMPLETION_GRAPHIC]];
            hud.labelText = COMPLETION_TEXT;
            [hud hide:YES afterDelay:2];
        }
     );
}

- (void)fetchingRestroomsFailedWithError:(NSError *)error
{;
    // display error
    hud.mode = MBProgressHUDModeText;
    hud.labelText = SYNC_ERROR_TEXT;
    hud.detailsLabelText = [NSString stringWithFormat:@"Code: %li", (long)[error code]];
}

#pragma mark MKMapViewDelegate methods

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation
{
    // If it's the user location, just return nil.
    if ([annotation isKindOfClass:[MKUserLocation class]])
        return nil;
    
    // Handle any custom annotations.
    if ([annotation isKindOfClass:[MKPointAnnotation class]])
    {
        // Try to dequeue an existing pin view first
        MKAnnotationView *pinView = (MKAnnotationView*)[mapView dequeueReusableAnnotationViewWithIdentifier:@"RestroomPinAnnotationView"];
        if (!pinView)
        {
            // If an existing pin view was not available, create one.
            pinView = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"RestroomPinAnnotationView"];
            pinView.canShowCallout = YES;
            
            // re-size pin image
            CGSize newSize = CGSizeMake(31.0f, 39.5f);
            UIGraphicsBeginImageContext(newSize);
            [[UIImage imageNamed:PIN_GRAPHIC] drawInRect:CGRectMake(0,0,newSize.width,newSize.height)];
            UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            // set pin image
            pinView.image = newImage;
//            pinView.calloutOffset = CGPointMake(0, 32);
            
            // set callout
            UIButton *rightButton = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
            pinView.rightCalloutAccessoryView = rightButton;
        }
        else
        {
            pinView.annotation = annotation;
        }
        
        return pinView;
    }
    
    return nil;
}

-(void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control
{
    id <MKAnnotation> annotation = [view annotation];
    
    if ([[view annotation] isKindOfClass:[MKPointAnnotation class]])
    {
        // segue to details controller
        [self performSegueWithIdentifier:@"ShowRestroomDetails" sender:annotation];
        
    }
}

#pragma mark - Segue

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if([[segue identifier] isEqualToString:@"ShowRestroomDetails"])
    {
        RestroomDetailsViewController *destinationController = [segue destinationViewController];
        
        MKPointAnnotation *annotation = (MKPointAnnotation *)sender;
        destinationController.restroom = annotation.restroom;
    }
}

#pragma mark - Helper methods

- (MKCoordinateRegion)getRegionWithZoomLocation:(CLLocationCoordinate2D)zoomLocation
{
    return MKCoordinateRegionMakeWithDistance(zoomLocation, (0.5 * METERS_PER_MILE), (0.5 * METERS_PER_MILE));
}


@end
