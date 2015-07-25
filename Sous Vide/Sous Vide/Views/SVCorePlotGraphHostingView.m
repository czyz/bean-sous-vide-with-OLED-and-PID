//
//  SVCorePlotGraphHostingView.m
//  Sous Vide
//
//  Created by Zach Fine on 7/17/15.
//  Copyright (c) 2015 Kestrel Development. All rights reserved.
//

#import "SVCorePlotGraphHostingView.h"

@implementation SVCorePlotGraphHostingView


-(void) viewDidLoad {
    
  /*
    
    //core plot graph stuff adapted from http://www.mobdevel.com/?p=96
    // Create a CPTGraph object and add to hostView
    CPTGraph* graph = [[CPTXYGraph alloc] initWithFrame:self.GraphHostView.bounds];
    self.GraphHostView.hostedGraph = graph;
    
    // Get the (default) plotspace from the graph so we can set its x/y ranges
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *) graph.defaultPlotSpace;
    
    // Note that these CPTPlotRange are defined by START and LENGTH (not START and END) !!
    [plotSpace setYRange: [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat( 0 ) length:CPTDecimalFromFloat( 16 )]];
    [plotSpace setXRange: [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat( -4 ) length:CPTDecimalFromFloat( 8 )]];
    
    // Create the plot (we do not define actual x/y values yet, these will be supplied by the datasource...)
    CPTScatterPlot* plot = [[CPTScatterPlot alloc] initWithFrame:CGRectZero];
    
    // Let's keep it simple and let this class act as datasource (therefore we implemtn <CPTPlotDataSource>)
    plot.dataSource = self;
    
    // Finally, add the created plot to the default plot space of the CPTGraph object we created before
    [graph addPlot:plot toPlotSpace:graph.defaultPlotSpace];
    
 */
}




// This method is here because this class also functions as datasource for our graph
// Therefore this class implements the CPTPlotDataSource protocol
-(NSUInteger)numberOfRecordsForPlot:(CPTPlot *)plotnumberOfRecords {
    return (int)[self.tempHistory count];
}

// This method is here because this class also functions as datasource for our graph
// Therefore this class implements the CPTPlotDataSource protocol
-(NSNumber *)numberForPlot:(CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)index
{
    // This method is actually called twice per point in the plot, one for the X and one for the Y value
    if(fieldEnum == CPTScatterPlotFieldX)
    {
        //get time value, as seconds since first sample (current sample minus first in set)
        NSNumber *relativeSeconds = @(
                                        ( [[[self.tempHistory objectAtIndex:index] objectAtIndex:0] intValue]
                                        - [[[self.tempHistory objectAtIndex:0] objectAtIndex:0] intValue] )
                                    );
        
        return relativeSeconds;
        
    } else {
        // Return y value
        return [[self.tempHistory objectAtIndex:index] objectAtIndex:1];
    }
}



/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
