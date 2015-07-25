//
//  SVCorePlotGraphHostingView.h
//  Sous Vide
//
//  Created by Zach Fine on 7/17/15.
//  Copyright (c) 2015 Kestrel Development. All rights reserved.
//
#import "CorePlot-CocoaTouch.h"
#import "CPTGraphHostingView.h"
#import "CPTPlot.h"

@interface SVCorePlotGraphHostingView : CPTGraphHostingView <CPTPlotDataSource>


@property (nonatomic,retain) NSMutableArray *tempHistory;

@end
