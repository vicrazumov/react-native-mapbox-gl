//
//  RCTMGLShapeSource.m
//  RCTMGL
//
//  Created by Nick Italiano on 9/19/17.
//  Copyright © 2017 Mapbox Inc. All rights reserved.
//

#import "RCTMGLShapeSource.h"
#import "RCTMGLUtils.h"


@implementation RCTMGLShapeSource

static NSMutableDictionary *_buildingCoords;

+ (void)initialize {
    if(_buildingCoords == nil) {
        NSMutableDictionary *coords = [[NSMutableDictionary alloc] init];
        NSString* filePath = [[NSBundle mainBundle] pathForResource:@"buildings" ofType:@"csv"];
        NSError *error;
        NSString *fileContents = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
        
        if (error)
            NSLog(@"Error reading file: %@", error.localizedDescription);
        
        NSArray* cols = [fileContents componentsSeparatedByString:@","];
        
        for(int i = 0; i < cols.count -2; i = i+3) {
            NSString *columnValue = [NSString stringWithFormat:@"%@,%@", cols[i+2], cols[i+1]];
            coords[cols[i]] = columnValue;
        }

        _buildingCoords = coords;
    }
}

- (void)setShape:(NSString *)shape
{
    _shape = shape;
    
    if (self.source != nil) {
        MGLShapeSource *source = (MGLShapeSource *)self.source;
        [source setShape:[RCTMGLUtils shapeFromGeoJSON:_shape]];
    }
}

- (void)addToMap
{
    if (self.map.style == nil) {
        return;
    }
    
    if (![self _hasImages] && ![self _hasNativeImages]) {
        [super addToMap];
    } else {
        if ([self _hasNativeImages]) {
            for (NSString *imageName in _nativeImages) {
                UIImage *image = [UIImage imageNamed:imageName];
                [self.map.style setImage:image forName:imageName];
            }
        }
        [RCTMGLUtils fetchImages:_bridge style:self.map.style objects:_images callback:^{ [super addToMap]; }];
    }
}

- (void)removeFromMap
{
    if (self.map.style == nil) {
        return;
    }
    
    [super removeFromMap];
    
    if ([self _hasImages]) {
        NSArray<NSString *> *imageNames = _images.allKeys;
        
        for (NSString *imageName in imageNames) {
            [self.map.style removeImageForName:imageName];
        }
    }
    
    if ([self _hasNativeImages]) {
        for (NSString *imageName in _nativeImages) {
            [self.map.style removeImageForName:imageName];
        }
    }
}

- (NSArray*)_requestClusters
{
    NSError *error = nil;
    NSString *urlString = [NSString stringWithFormat: @"%@", _csvUrl];
    NSString *idToApartmentsString = [NSString stringWithContentsOfURL:[NSURL URLWithString:urlString] encoding:NSUTF8StringEncoding error:&error];
   
    NSArray *clustersArray = [idToApartmentsString componentsSeparatedByString: @","];

    return clustersArray;
}

- (NSString*)_makeGeoJson
{
    NSArray *clustersArray = [self _requestClusters];
    
    NSMutableString *geoJson = [NSMutableString stringWithString:@"{\"type\":\"FeatureCollection\",\"features\":["];
    NSString *buildingJsonStart = @"{\"type\":\"Feature\",\"properties\":{},\"geometry\":{\"type\": \"Point\", \"coordinates\":[";
    NSString *buildingJsonFinish = @"]}}";
    NSLog(@"clustersArray length = %lu", (unsigned long)clustersArray.count);
    for(int i = 0; i < clustersArray.count -1; i = i+2) {
        NSString *buildingCoord = clustersArray[i];
        NSInteger apartmentsInCluster = [clustersArray[i+1] integerValue];

        // get coordinates from dictionary
        for(int n = 0; n < apartmentsInCluster; n++) {
            [geoJson appendString:buildingJsonStart];
            [geoJson appendString:_buildingCoords[buildingCoord]];
            [geoJson appendString:buildingJsonFinish];
        
            if (i != clustersArray.count -2 || n+1 != apartmentsInCluster) {
                NSString *lastComma = @",";
                [geoJson appendString:lastComma];
            }
        }
    }
    
    NSString *geoJsonFinish = @"]}";
    [geoJson appendString:geoJsonFinish];
    
    return geoJson;
}

- (MGLSource*)makeSource
{
    NSDictionary<MGLShapeSourceOption, id> *options = [self _getOptions];
    if (_csvUrl != nil) {
        NSString *geoJson = [self _makeGeoJson];
        MGLShape *shape = [RCTMGLUtils shapeFromGeoJSON:geoJson];
        return [[MGLShapeSource alloc] initWithIdentifier:self.id shape:shape options:options];
    }

    if (_shape != nil) {
        MGLShape *shape = [RCTMGLUtils shapeFromGeoJSON:_shape];
        return [[MGLShapeSource alloc] initWithIdentifier:self.id shape:shape options:options];
    }
    
    NSURL *url = [[NSURL alloc] initWithString:_url];
    return [[MGLShapeSource alloc] initWithIdentifier:self.id URL:url options:options];
}

- (NSDictionary<MGLShapeSourceOption, id>*)_getOptions
{
    NSMutableDictionary<MGLShapeSourceOption, id> *options = [[NSMutableDictionary alloc] init];
    
    if (_cluster != nil) {
        options[MGLShapeSourceOptionClustered] = [NSNumber numberWithBool:[_cluster intValue] == 1];
    }
    
    if (_clusterRadius != nil) {
        options[MGLShapeSourceOptionClusterRadius] = _clusterRadius;
    }
    
    if (_clusterMaxZoomLevel != nil) {
        options[MGLShapeSourceOptionMaximumZoomLevelForClustering] = _clusterMaxZoomLevel;
    }
    
    if (_maxZoomLevel != nil) {
        options[MGLShapeSourceOptionMaximumZoomLevel] = _maxZoomLevel;
    }
    
    if (_buffer != nil) {
        options[MGLShapeSourceOptionBuffer] = _buffer;
    }
    
    if (_tolerence != nil) {
        options[MGLShapeSourceOptionSimplificationTolerance] = _tolerence;
    }
    
    return options;
}

- (BOOL)_hasImages
{
    return _images != nil && _images.count > 0;
}

- (BOOL)_hasNativeImages
{
    return _nativeImages != nil && _nativeImages.count > 0;
}

@end
