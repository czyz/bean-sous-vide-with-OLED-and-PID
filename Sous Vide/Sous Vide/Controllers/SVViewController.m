//
//  SVViewController.m
//  Sous Vide
//
//  Created by Matthew Lewis on 6/19/14.
//  Copyright (c) 2014 Kestrel Development. All rights reserved.
//

// Which Bean to connect to (BLE local name)
#define SOUS_VIDE_BEAN_NAME @"SousVide"

// How often the app should ask the Bean for updates
#define UPDATE_INTERVAL_SECS 5.0

// Image resource locations
#define ICON_CHECK @"checkmark.png"
#define ICON_X @"cancel.png"
#define ICON_QUESTION @"help.png"
#define ICON_QUESTION_LG @"help_lg.png"
#define ICON_HEATING_LG @"hot.png"
#define ICON_COOLING_LG @"cool.png"

// Text templates for the top two status lines
#define BT_STATUS_TEXT @"Bluetooth: %@"
#define BEAN_STATUS_TEXT @"Bean: %@"

// Alpha values for fading disabled interface elements
#define ALPHA_FADED 0.3
#define ALPHA_OPAQUE 1.0

// Command bytes for telling the Bean what to do
#define CMD_STATUS 0x00
#define CMD_ENABLE 0x01
#define CMD_DISABLE 0x02
#define CMD_SETTARGET 0x03
#define CMD_SET_KP 0x08
#define CMD_SET_KI 0x09
#define CMD_SET_KD 0x0A


#define CMD_AUTOTUNE 0x06

// Bytes indicating message types for Bean messages
#define MSG_STATUS 0x00
#define MSG_ENABLE 0x01
#define MSG_DISABLE 0x02
#define MSG_SET_TARGET_TEMP 0x03

#define MSG_AUTOTUNE_START 0x06
#define MSG_AUTOTUNE_FINISH 0x07
#define MSG_SET_KP 0x08
#define MSG_SET_KI 0x09
#define MSG_SET_KD 0x0A

// State machine states for parsing Bean messages
#define ST_READY 0x00               // Waiting for message type byte
#define ST_STATUS_CURRENT_TEMP 0x01 // Got message type STATUS (0x00); waiting for current temp
#define ST_STATUS_TARGET_TEMP 0x02  // Got current temp; waiting for target temp
#define ST_STATUS_ENABLED 0x03      // Got target temp; waiting for ENABLED byte
#define ST_STATUS_HEATING 0x05      // Got ENABLED byte; waiting for HEATING byte
#define ST_SET_TARGET_TEMP 0x04     // Got message type SET_TARGET_TEMP (0x03); waiting for target temp

#define ST_AUTOTUNE_STARTED 0x06
#define ST_AUTOTUNE_FINISHED 0x07

#define ST_SET_KP 0x08
#define ST_SET_KI 0x09
#define ST_SET_KD 0x0A

#define ST_STATUS_KP 0x0B
#define ST_STATUS_KI 0x0C
#define ST_STATUS_KD 0x0A

#define ST_DONE 0xFF                // Got expected message bytes; waiting for terminator (0xFF)

#import "SVViewController.h"

@interface SVViewController () <PTDBeanManagerDelegate, PTDBeanDelegate>


@property PTDBeanManager *beanManager;  // Searches for Beans and manages Bluetooth connection
@property NSMutableDictionary *beans;   // A list of all found Beans, indexed by UUID
@property PTDBean *sousVideBean;        // The connected Bean, specified by SOUS_VIDE_BEAN_NAME
@property NSTimer *updateTimer;         // Used for asking the Bean for a status update every x seconds

@property BOOL targetTempSliding;       // Used to keep the Bean from getting updates until the
                                        // user's thumb is off the slider

// These variables are used to store parsed data from serial messages
@property unsigned char msgType;            // The last message type parsed (STATUS, ENABLE, DISABLE, SETTARGET)
@property unsigned char msgCurrentState;    // The current state of the parser state machine
@property float msgCurrentTemp;     // Storage for the "current cooker temperature" variable
@property float msgTargetTemp;      // Storage for the "target cooker temperature" variable
@property BOOL msgEnabled;                  // Storage for the "is the cooker enabled right now?" boolean
@property BOOL msgHeating;                  // Storage for the "is the cooker heating right now?" boolean
@property float msgKp;      // Storage for the "Kp" variable
@property float msgKi;      // Storage for the "Ki" variable
@property float msgKd;      // Storage for the "Kd" variable


@end

@implementation SVViewController

//for dismissing the keyboard as per http://stackoverflow.com/questions/5306240/iphone-dismiss-keyboard-when-touching-outside-of-uitextfield

UIGestureRecognizer *tapper;

// Called on load of the View.
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Set up BeanManager
    self.beanManager = [[PTDBeanManager alloc] initWithDelegate:self];
    
    // Clear program state
    [self reset];
    
    //for dismissing the keyboard as per http://stackoverflow.com/questions/5306240/iphone-dismiss-keyboard-when-touching-outside-of-uitextfield
    
    tapper = [[UITapGestureRecognizer alloc]
              initWithTarget:self action:@selector(handleSingleTap:)];
    tapper.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tapper];
    
    
    //core plot graph stuff adapted from http://www.mobdevel.com/?p=96
    // Create a CPTGraph object and add to hostView
    CPTGraph* graph = [[CPTXYGraph alloc] initWithFrame:self.GraphHostView.bounds];
    self.GraphHostView.hostedGraph = graph;

    
    NSMutableArray *tempHistory = [NSMutableArray arrayWithCapacity:1];
    self.GraphHostView.tempHistory = tempHistory;
    //let's pre-fill the temperature history array just to test it

    int indexy;
    for (indexy = 0; indexy < 9; indexy++) {
        
     
        
        
        [self.GraphHostView.tempHistory
         addObject:@[
                     [NSNumber numberWithDouble:NSDate.date.timeIntervalSince1970+(indexy*5)],
                     [NSNumber numberWithFloat:(indexy*5*arc4random_uniform(10))]]
         ];

        
    }
    NSLog(@"%@", self.GraphHostView.tempHistory);

    
    
    // Get the (default) plotspace from the graph so we can set its x/y ranges
    //CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *) graph.defaultPlotSpace;
    
    // Note that these CPTPlotRange are defined by START and LENGTH (not START and END) !!
    //[plotSpace setYRange: [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat( 0 ) length:CPTDecimalFromFloat( 80 )]];
    
//    [plotSpace setXRange: [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat( -2 ) length:CPTDecimalFromFloat( 10 )]];
   //[plotSpace setXRange: [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat( [[[self.GraphHostView.tempHistory objectAtIndex:0] objectAtIndex:0] floatValue] - 10 ) length:CPTDecimalFromFloat( 100 )]];
   // NSLog(@"first x value: %@",[[self.GraphHostView.tempHistory objectAtIndex:0] objectAtIndex:0]);
    
   
    
    // Create the plot (we do not define actual x/y values yet, these will be supplied by the datasource...)
    //CPTScatterPlot* plot = [[CPTScatterPlot alloc] initWithFrame:CGRectZero];
    CPTScatterPlot* plot = [[CPTScatterPlot alloc] initWithFrame:self.GraphHostView.frame];
    
    // Let's keep it simple and let this class act as datasource (therefore we implemtn <CPTPlotDataSource>)
    plot.dataSource = self.GraphHostView;

    graph.plotAreaFrame.paddingTop    = 20.0;
    graph.plotAreaFrame.paddingBottom = 35.0;
    graph.plotAreaFrame.paddingLeft   = 50.0;
    graph.plotAreaFrame.paddingRight  = 20.0;
    
    // style the graph with white text and lines
    
    CPTMutableTextStyle *graphText = [CPTMutableTextStyle textStyle];
    graphText.color = [CPTColor blackColor];
    CPTMutableLineStyle *graphStyle = [CPTMutableLineStyle lineStyle];
    graphStyle.lineColor = [CPTColor blackColor];
    graphStyle.lineWidth = 2.0f;
    
    // set up the axis
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *)graph.axisSet;
    CPTXYAxis *x = axisSet.xAxis;
    CPTXYAxis *y = axisSet.yAxis;
    //x.majorIntervalLength = CPTDecimalFromFloat(maxDistance/10.0f);
    x.majorIntervalLength = CPTDecimalFromFloat(5.0);
    x.minorTicksPerInterval = 3;
    x.majorTickLineStyle = graphStyle;
    x.minorTickLineStyle = graphStyle;
    x.axisLineStyle = graphStyle;
    x.minorTickLength = 5.0f;
    x.majorTickLength = 10.0f;
    x.labelOffset = 3.0f;
    x.labelTextStyle = graphText;
    y.majorIntervalLength = CPTDecimalFromFloat(50);
    y.minorTicksPerInterval = 3;
    y.majorTickLineStyle = graphStyle;
    y.minorTickLineStyle = graphStyle;
    y.axisLineStyle = graphStyle;
    y.minorTickLength = 5.0f;
    y.majorTickLength = 10.0f;
    y.labelOffset = 3.0f;
    y.labelTextStyle = graphText;
    
    
     //graph.plotAreaFrame.masksToBorder = NO;
    
    // Finally, add the created plot to the default plot space of the CPTGraph object we created before
    [graph addPlot:plot toPlotSpace:graph.defaultPlotSpace];

    [graph.defaultPlotSpace scaleToFitPlots:[graph allPlots]];
    
}




- (void)handleSingleTap:(UITapGestureRecognizer *) sender
{
    [self.view endEditing:YES];
}



// Called when something happens to Bluetooth (turns on, turns off, etc).
- (void)beanManagerDidUpdateState:(PTDBeanManager *)beanManager
{
    
    CGPoint scrollBannerPoint; //create point to use to scroll banner scrollview.
    int layoutMargin = 20;
    
    // Set Bluetooth status label and icon for the current Bluetooth state.
    if (self.beanManager.state == BeanManagerState_PoweredOn) {
        [self setBtStatus:@"Enabled" withIcon:ICON_CHECK];
        
        //bluetooth is enabled, scroll to show bean connectivity
        scrollBannerPoint = CGPointMake(self.beanStatusSpinner.frame.origin.x - layoutMargin,0);
        
    } else if (self.beanManager.state == BeanManagerState_PoweredOff) {
        [self setBtStatus:@"Disabled" withIcon:ICON_X];
        
                //bluetooth is disabled, scroll view to show bluetooth connectivity
                scrollBannerPoint = CGPointMake(self.btStatusIcon.frame.origin.x - layoutMargin,0);
        
    } else {
        [self setBtStatus:@"Unknown" withIcon:ICON_QUESTION];
        
        //bluetooth is disabled, scroll view to show bluetooth connectivity
        scrollBannerPoint = CGPointMake(self.btStatusIcon.frame.origin.x - layoutMargin,0);
    }
    
    //scroll banner to show relevant info, bluetooth or bean connectivity
    [self.BluetoothBeanConnectionBanner setContentOffset:scrollBannerPoint animated:YES];
    
    if (self.beanManager.state == BeanManagerState_PoweredOn) {
        // If Bluetooth is on, start scanning for beans.
        [self startScanning];
    } else {
        // When we turn Bluetooth off, stop scanning.
        [self stopScanning];
        // When the Bean disconnects, clean up
        [self reset];
        // Show the Bean as disconnected
        [self setBeanStatus:@"Disconnected" withIcon:ICON_X];
    }
}

// Called on discovery of any Bean during scanning.
- (void)BeanManager:(PTDBeanManager *)beanManager didDiscoverBean:(PTDBean *)bean error:(NSError *)error
{
    NSUUID *key = bean.identifier;
    // Add newly-seen Beans to the dict.
    if (![self.beans objectForKey:key]) {
        [self.beans setObject:bean forKey:key];
        NSLog(@"New Bean discovered: %@ (%@)", bean.name, [key UUIDString]);
        if ([bean.name isEqualToString:SOUS_VIDE_BEAN_NAME]) {
            // Connect to the Sous Vide Bean.
            [self.beanManager connectToBean:bean error:nil];
            // Show the connection status.
            [self setBeanStatusWithSpinner:@"Connecting..."];
        }
    }
}

// Called when the sous vide Bean is connected.
- (void)BeanManager:(PTDBeanManager *)beanManager didConnectToBean:(PTDBean *)bean error:(NSError *)error
{
    // Set Bean delegate to self
    [bean setDelegate:self];
    
    // Show connected status
    [self setBeanStatus:@"Connected" withIcon:ICON_CHECK];
    
    // Stop scanning
    [self stopScanning];
    
    // Keep track of the connected Bean
    self.sousVideBean = bean;
    
    // Start sending update packets
    [self startUpdateRequests];
    
    
    //scroll main view upward to hide the bluetooth and bean status banner (scroll upward exactly the height of the banner)
    CGPoint scrollPoint = CGPointMake(0,self.BluetoothBeanConnectionBanner.frame.size.height);
    
    [self.mainScrollView setContentOffset:scrollPoint animated:YES];
    
}

// Called when the sous vide Bean disconnects.
- (void)BeanManager:(PTDBeanManager *)beanManager didDisconnectBean:(PTDBean *)bean error:(NSError *)error
{
    // When the Bean disconnects, clean up
    [self reset];
}

// Called when serial data is received from the connected Bean.
// This is the state machine that parses incoming serial messages.
- (void)bean:(PTDBean *)bean serialDataReceived:(NSData *)data
{
    const char *dataBytes = (const char *)[data bytes];
    unsigned char dataByte = dataBytes[0];
    
    //got this method of converting 4 bytes to float with endian swap
    // from http://www.codeitive.com/7QyxXVqUeX/get-float-value-from-nsdata-objectivec-ios.html
    // I tried several other methods, it's the only one that worked.
    
    uint32_t hostData = CFSwapInt32BigToHost(*(const uint32_t *)[data bytes]);
    float dataFloat = *(float *)(&hostData);
    
//    int dataLength; //just debugging
//    dataLength = [data length];

    
    if (([data length] > 3)) {
        //we've received something more than a single byte, since the only other data type we're sending are floats
        //let's store it in a float
        //  Why doesn't this work?        [data getBytes:&dataFloat length:sizeof(float)];
        
        //trying this instead
//        dataFloat = dataBytes[0];
        NSLog(@"dataFloat: %f", dataFloat);

        
    }

    
    

    if (self.msgCurrentState == ST_READY) {
        // Read message type and set next state accordingly
        self.msgType = dataByte;
        
        if (self.msgType == MSG_STATUS) {
            self.msgCurrentState = ST_STATUS_CURRENT_TEMP;
            
        } else if (self.msgType == MSG_ENABLE) {
            self.msgCurrentState = ST_DONE;
        
        } else if (self.msgType == MSG_DISABLE) {
            self.msgCurrentState = ST_DONE;
        
        } else if (self.msgType == MSG_SET_TARGET_TEMP) {
            self.msgCurrentState = ST_SET_TARGET_TEMP;
        
        } else if (self.msgType == MSG_AUTOTUNE_START) {
            self.msgCurrentState = ST_AUTOTUNE_STARTED;

        } else if (self.msgType == MSG_AUTOTUNE_FINISH) {
            self.msgCurrentState = ST_AUTOTUNE_FINISHED;
            
        } else if (self.msgType == MSG_SET_KP) {
            
            self.msgCurrentState = ST_SET_KP;
            
        } else if (self.msgType == MSG_SET_KI) {
            self.msgCurrentState = ST_SET_KI;
            
        } else if (self.msgType == MSG_SET_KD) {
            self.msgCurrentState = ST_SET_KD;

        } // Ignore all other messages

    } else if (self.msgCurrentState == ST_STATUS_CURRENT_TEMP) {
        self.msgCurrentTemp = dataFloat;
        
        self.msgCurrentState = ST_STATUS_TARGET_TEMP;
        
    } else if (self.msgCurrentState == ST_STATUS_TARGET_TEMP) {
        self.msgTargetTemp = dataFloat;
        self.msgCurrentState = ST_STATUS_ENABLED;
        
    } else if (self.msgCurrentState == ST_STATUS_ENABLED) {
        self.msgEnabled = dataByte;
        self.msgCurrentState = ST_STATUS_HEATING;
        
    } else if (self.msgCurrentState == ST_STATUS_HEATING) {
        self.msgHeating = dataByte;
        self.msgCurrentState = ST_STATUS_KP;
        
    } else if (self.msgCurrentState == ST_STATUS_KP) {
        self.msgKp = dataFloat;
        self.msgCurrentState = ST_STATUS_KI;

    } else if (self.msgCurrentState == ST_STATUS_KI) {
        self.msgKi = dataFloat;
        self.msgCurrentState = ST_STATUS_KD;
        
    } else if (self.msgCurrentState == ST_STATUS_KD) {
        self.msgKd = dataFloat;
        self.msgCurrentState = ST_DONE;
    
    
    } else if (self.msgCurrentState == ST_SET_TARGET_TEMP) {
        self.msgTargetTemp = dataFloat;
        self.msgCurrentState = ST_DONE;
        
    } else if (self.msgCurrentState == ST_AUTOTUNE_FINISHED) {
        [self endAutotune];
        self.msgCurrentState = ST_DONE;
        
    } else if (self.msgCurrentState == ST_DONE && dataByte == 0xFF) {
        // State machine was waiting for terminator and received it.
        if (self.msgType == MSG_STATUS) {
            [self enableControlsWithTemp:self.msgCurrentTemp
                              targetTemp:self.msgTargetTemp
                               isEnabled:self.msgEnabled
                               isHeating:self.msgHeating
                              pidKpvalue:self.msgKp
                              pidKivalue:self.msgKi
                              pidKdvalue:self.msgKd
             ];
            
            
            [self.GraphHostView.tempHistory
             addObject:@[
                [NSNumber numberWithDouble:NSDate.date.timeIntervalSince1970],
                [NSNumber numberWithFloat:self.msgCurrentTemp]]
             ];

            
        }
        self.msgCurrentState = ST_READY;
    }
}

// Set the Bluetooth status text/icon.
- (void)setBtStatus:(NSString *)statusText withIcon:(NSString *)iconName
{
    [self.btStatusIcon setImage:[UIImage imageNamed:iconName]];
    [self.btStatusLabel setText:[NSString stringWithFormat:BT_STATUS_TEXT, statusText]];
}

// Set the Bean status text/icon.
- (void)setBeanStatus:(NSString *)statusText withIcon:(NSString *)iconName
{
    [self.beanStatusLabel setText:[NSString stringWithFormat:BEAN_STATUS_TEXT, statusText]];
    [self.beanStatusSpinner stopAnimating];
    [self.beanStatusIcon setImage:[UIImage imageNamed:iconName]];
    self.beanStatusIcon.hidden = NO;
}

// Set the Bean status text and set the icon to an activity spinner.
- (void)setBeanStatusWithSpinner:(NSString *)statusText
{
    [self.beanStatusLabel setText:[NSString stringWithFormat:BEAN_STATUS_TEXT, statusText]];
    [self.beanStatusSpinner startAnimating];
    self.beanStatusIcon.hidden = YES;
}

// Start scanning for Beans.
- (void)startScanning
{
    [self.beanManager startScanningForBeans_error:nil];
    [self setBeanStatusWithSpinner:@"Scanning..."];
}

// Stop scanning for Beans.
- (void)stopScanning
{
    // Clear all found Beans and stop scanning.
    [self.beans removeAllObjects];
    [self.beanManager stopScanningForBeans_error:nil];
}

// Display the current temperature of the cooker.
- (void)showTemp:(float)temp
{
    [self.tempLabel setText:[NSString stringWithFormat:@"%0.2f° F", temp]];
}

// Display the Kp tune setting
- (void)showKp:(float)Kp
{
    [self.pidKp setText:[NSString stringWithFormat:@"%0.2f", Kp]];
}

// Display the Ki tune setting
- (void)showKi:(float)Ki
{
    [self.pidKi setText:[NSString stringWithFormat:@"%0.2f", Ki]];
}

// Display the Kd tune setting
- (void)showKd:(float)Kd
{
    [self.pidKd setText:[NSString stringWithFormat:@"%0.2f", Kd]];
}



// Display the target temperature.
- (void)showTargetTemp:(int)targetTemp
{
    [self.targetTempLabel setText:[NSString stringWithFormat:@"%i° F", targetTemp]];
    [self.targetTempSlider setValue:targetTemp];
    [self.targetTempStepper setValue:targetTemp];
}

// Display the current cooker enable status.
- (void)showEnabled:(BOOL)enabled
{
    self.cookingSwitch.on = enabled;
    [self.cookingLabel setText:enabled ? @"Yes" : @"No"];
}

// Display the current cooker heating/cooling status.
- (void)showHeating:(BOOL)heating
{
    NSString *heatingImage = heating ? ICON_HEATING_LG : ICON_COOLING_LG;
    [self.heatingIcon setImage:[UIImage imageNamed:heatingImage]];
    [self.heatingLabel setText:heating ? @"Heating" : @"Cooling"];
}

// Enable controls with latest status data. We don't want to enable the controls
// and un-dim the display with stale data, so we have to pass in fresh data
// (temp, enabled, etc.) when we call this method.
- (void)enableControlsWithTemp:(float)temp
                    targetTemp:(int)targetTemp
                     isEnabled:(BOOL)enabled
                     isHeating:(BOOL)heating
                    pidKpvalue:(double)pidKp
                    pidKivalue:(double)pidKi
                    pidKdvalue:(double)pidKd
{
    self.heatingIcon.alpha = ALPHA_OPAQUE;
    self.tempLabel.alpha = ALPHA_OPAQUE;
    self.heatingLabel.alpha = ALPHA_OPAQUE;
    self.targetTempLabel.alpha = ALPHA_OPAQUE;
    self.cookingLabel.alpha = ALPHA_OPAQUE;
    [self.targetTempSlider setEnabled:YES];
    self.targetTempSlider.alpha = ALPHA_OPAQUE;
    [self.targetTempStepper setEnabled:YES];
    self.targetTempStepper.alpha = ALPHA_OPAQUE;

    [self.cookingSwitch setEnabled:YES];
    
    [self.autotune setEnabled:YES];
    [self.pidKp setEnabled:YES];
    [self.pidKi setEnabled:YES];
    [self.pidKd setEnabled:YES];
    
    
    
    [self showTemp:temp];
    [self showEnabled:enabled];
    [self showHeating:heating];
    [self showKp:pidKp];
    [self showKi:pidKi];
    [self showKd:pidKd];
    
    if (!self.targetTempSliding) {
        [self showTargetTemp:targetTemp];
    }
}

// Disable controls and dim the display.
- (void)disableControls
{
    self.heatingIcon.alpha = ALPHA_FADED;
    self.tempLabel.alpha = ALPHA_FADED;
    self.heatingLabel.alpha = ALPHA_FADED;
    self.targetTempLabel.alpha = ALPHA_FADED;
    self.cookingLabel.alpha = ALPHA_FADED;
    [self.targetTempSlider setEnabled:NO];
    self.targetTempSlider.alpha = ALPHA_FADED;
    [self.targetTempStepper setEnabled:NO];
    self.targetTempStepper.alpha = ALPHA_FADED;
    [self.cookingSwitch setEnabled:NO];
    
    [self.heatingIcon setImage:[UIImage imageNamed:ICON_QUESTION_LG]];
    [self.tempLabel setText:@"?° F"];
    [self.heatingLabel setText:@"Unknown"];
    [self.targetTempLabel setText:@"?° F"];
    [self.cookingLabel setText:@"?"];
    
    [self.autotune setEnabled:NO];
    [self.pidKp setEnabled:NO];
    [self.pidKi setEnabled:NO];
    [self.pidKd setEnabled:NO];
    self.autotune.alpha = ALPHA_FADED;
    self.pidKp.alpha = ALPHA_FADED;
    self.pidKi.alpha = ALPHA_FADED;
    self.pidKd.alpha = ALPHA_FADED;
}

// targetTempDown, targetTempChanged, targetTempUp keep the slider from
// spamming the Bean with serial data. Sending lots of packets very quickly
// can cause the Bean to lose connection with the iOS device, so we send
// packets only when the user releases the slider.

// On slider touch
- (IBAction)targetTempDown:(UISlider *)sender
{
    self.targetTempSliding = true;
}

// On slider slide
- (IBAction)targetTempChanged:(UISlider *)sender
{
    [self showTargetTemp:[sender value]];
}

// On slider release
- (IBAction)targetTempUp:(UISlider *)sender
{
    self.targetTempSliding = false;
    [self setTargetTemp:[sender value]];
}

- (IBAction)targetTempUpStepper:(UIStepper *)sender {
    [self showTargetTemp:[sender value]];
    [self setTargetTemp:[sender value]];
}

- (IBAction)mainInterfacePageChanged:(UIPageControl *)sender {

    CGFloat pageWidth = self.mainScrollView.frame.size.width;
    //set x point of scrollview to sender.value * width_of_page
    
    CGPoint scrollPoint = CGPointMake(sender.currentPage * pageWidth, 0);
    [self.infoScrollView setContentOffset:scrollPoint animated:YES];
}

/*
// from http://iosmadesimple.blogspot.com/2013/01/page-control-for-switching-between-views.html

- (void)scrollViewDidScroll:(UIScrollView *)sender
{
    // Update the page when more than 50% of the previous/next page is visible
    CGFloat pageWidth = self.scrollView.frame.size.width;
    int page = floor((self.scrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
    self.pageControl.currentPage = page;
}
*/

- (IBAction)infoScrollViewSwipeLeft:(UISwipeGestureRecognizer *)sender {

    if (self.mainInfoPageControl.currentPage < 1) {
        self.mainInfoPageControl.currentPage++;
    }
    
    CGFloat pageWidth = self.mainScrollView.frame.size.width;
    //set x point of scrollview to sender.value * width_of_page
    CGPoint scrollPoint = CGPointMake(self.mainInfoPageControl.currentPage * pageWidth, 0);
    [self.infoScrollView setContentOffset:scrollPoint animated:YES];

    
}

- (IBAction)infoScrollViewSwipeRight:(UISwipeGestureRecognizer *)sender {

    if (self.mainInfoPageControl.currentPage > 0) {
        self.mainInfoPageControl.currentPage--;
    }
    
    
    CGFloat pageWidth = self.mainScrollView.frame.size.width;
    //set x point of scrollview to sender.value * width_of_page
    CGPoint scrollPoint = CGPointMake(self.mainInfoPageControl.currentPage * pageWidth, 0);
    [self.infoScrollView setContentOffset:scrollPoint animated:YES];
    
}








- (IBAction)editBeginKp:(id)sender {
    
    //scroll view up when keyboard appears
    //taken from answer "Just using text fields" at http://stackoverflow.com/questions/1126726/how-to-make-a-uitextfield-move-up-when-keyboard-is-present

    //should really find the height of the keyboard, and then scroll the view that distance in y, rather than scrolling the uitextfield to the middle of the screen.
    CGPoint scrollPoint = CGPointMake(0, self.pidKp.frame.origin.y/2);
    [self.mainScrollView setContentOffset:scrollPoint animated:YES];

    
}




- (IBAction)editedKp:(UITextField *)sender {
    
    //scroll view back into place after editing text field (not sure if this works
    //taken from answer "Just using text fields" at http://stackoverflow.com/questions/1126726/how-to-make-a-uitextfield-move-up-when-keyboard-is-present
    
    [self.mainScrollView setContentOffset:CGPointZero animated:YES];
    [self setKp:[sender.text floatValue]];

}

- (IBAction)editedKi:(UITextField *)sender {
    [self.mainScrollView setContentOffset:CGPointZero animated:YES];
    [self setKi:[sender.text floatValue]];

}


- (IBAction)editedKd:(UITextField *)sender {
    [self.mainScrollView setContentOffset:CGPointZero animated:YES];
    [self setKd:[sender.text floatValue]];
}

// Handle changes in the Cooking Enable switch.
- (IBAction)enableSwitchChanged:(UISwitch *)sender
{
    if (sender.on) {
        [self enableHeater];
    } else {
        [self disableHeater];
    }
}

- (IBAction)autotuneButtonClicked:(id)sender {
    [sender setTitle:@"tuning…" forState:UIControlStateNormal];

    //disable PID controls during autotune
    [sender setEnabled:NO];
    [self.pidKp setEnabled:NO];
    [self.pidKi setEnabled:NO];
    [self.pidKd setEnabled:NO];
    //will need to re-enable and change the text back after receiving info from the arduino that tuning has finished. Actually, this could change to various tuning status messages, unless I do that in the main icon area at the center of the screen. Or it could become a "cancel autotune" button.
    
    [self startAutotune];
    
    
}


// Run this when the Bean disconnects or Bluetooth chokes.
- (void)reset
{
    // Disable controls
    [self disableControls];
    
    // Stop sending update requests
    [self stopUpdateRequests];
    
    // Throw away the connected Bean
    self.sousVideBean = nil;

    // Reset the state machine
    self.msgCurrentState = ST_READY;

    //scroll main view downward to expose the bluetooth and bean status banner
    CGPoint scrollPoint = CGPointMake(0,0);
    
    [self.mainScrollView setContentOffset:scrollPoint animated:YES];

    
    
    // If Bluetooth is ready, start scanning again right away
    if (self.beanManager.state == BeanManagerState_PoweredOn) {
        [self startScanning];
    }
}

// Helper function. Send a char array of bytes with specified length to the Bean.
- (void)sendData:(char[])cmdBytes length:(int)length
{
    // If the connected Bean is nil or not connected, stop updating
    if (!self.sousVideBean || [self.sousVideBean state] != BeanState_ConnectedAndValidated) {
        NSLog(@"Tried to send data while Bean was disconnected. Ignoring.");
    } else {
        NSMutableData *data = [[NSMutableData alloc] init];
        [data appendBytes:cmdBytes length:length];
        [self.sousVideBean sendSerialData:data];
    }
}

// Ask the Bean for a status update. This happens asynchronously, so the iOS
// device will get results and handle them in the bean:serialDataReceived method.
- (void)requestUpdate
{
    [self sendData:(char[]){CMD_STATUS} length:1];
}

// Enable heating.
- (void)enableHeater
{
    [self sendData:(char[]){CMD_ENABLE} length:1];
    
    // when heater is enabled, disable sleep
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
}

// Disable heating. The Bean will not turn on the heater pin even if the temperature is low.
- (void)disableHeater
{
    [self sendData:(char[]){CMD_DISABLE} length:1];
    
    //if heater is disabled, re-enable sleep
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
}

// Begin autotune.
- (void)startAutotune
{
     [self sendData:(char[]){CMD_AUTOTUNE} length:1];
}

// End autotune
- (void)endAutotune
{
    [self.autotune setTitle:@"autotune" forState:UIControlStateNormal];
    
    //re-enable PID controls and autotune button
    [self.autotune setEnabled:YES];
    [self.pidKp setEnabled:YES];
    [self.pidKi setEnabled:YES];
    [self.pidKd setEnabled:YES];
    //will need to re-enable and change the text back after receiving info from the arduino that tuning has finished. Actually, this could change to various tuning status messages, unless I do that in the main icon area at the center of the screen. Or it could become a "cancel autotune" button.
    
}


// Set the Bean target temperature.
- (void)setTargetTemp:(float)targetTemp
{
//    [self sendData:(char[]){CMD_SETTARGET, targetTemp} length:2];
    
    //method to send serialized numbers borrowed from http://www.gammon.com.au/serial
//    const char startOfNumberDelimiter = '<';
//    const char endOfNumberDelimiter   = '>';
//    
//    int sizeOfData = 3 + sizeof(float);
//    [self sendData:(char[]){CMD_SETTARGET, startOfNumberDelimiter, targetTemp, endOfNumberDelimiter} length:sizeOfData];

    
    //lets send our float as a string so that the arduino's parsefloat function can interpret it
    
    NSString *floatString = [NSString stringWithFormat:@"%f", targetTemp];
    
    char *cstrFloat = [floatString UTF8String];
    
    int sizeOfData = sizeof(cstrFloat);
    
    [self sendData:(char[]){CMD_SETTARGET} length:1];
    [self sendData:cstrFloat length:sizeOfData];
    NSLog(@"sent targetTemp: %s", cstrFloat);

    
}


// Set the Bean Kp value
- (void)setKp:(float)targetKp
{
    
    
    //method to send serialized numbers borrowed from http://www.gammon.com.au/serial
//    const char startOfNumberDelimiter = '<';
//    const char endOfNumberDelimiter   = '>';
//    
//    int sizeOfData = 3 + sizeof(float);
//    [self sendData:(char[]){CMD_SET_KP, startOfNumberDelimiter, targetKp, endOfNumberDelimiter} length:sizeOfData];
//    
    NSString *floatString = [NSString stringWithFormat:@"%f", targetKp];
    
    const char *cstrFloat = [floatString UTF8String];
    
    int sizeOfData = sizeof(cstrFloat);
    
    [self sendData:(char[]){CMD_SET_KP} length:1];
    [self sendData:cstrFloat length:sizeOfData];
    NSLog(@"sent Kp: %s", cstrFloat);
    
    
}

// Set the Bean Ki value
- (void)setKi:(float)targetKi
{
    
//    //method to send serialized numbers borrowed from http://www.gammon.com.au/serial
//    const char startOfNumberDelimiter = '<';
//    const char endOfNumberDelimiter   = '>';
//    
//    int sizeOfData = 3 + sizeof(float);
//    [self sendData:(char[]){CMD_SET_KI, startOfNumberDelimiter, targetKi, endOfNumberDelimiter} length:sizeOfData];
    
    
    NSString *floatString = [NSString stringWithFormat:@"%f", targetKi];
    
    const char *cstrFloat = [floatString UTF8String];
    
    int sizeOfData = sizeof(cstrFloat);
    
    [self sendData:(char[]){CMD_SET_KI} length:1];
    [self sendData:cstrFloat length:sizeOfData];
    NSLog(@"sent Ki: %s", cstrFloat);
    
}

// Set the Bean Kd valu
- (void)setKd:(float)targetKd
{
    
    //method to send serialized numbers borrowed from http://www.gammon.com.au/serial
//    const char startOfNumberDelimiter = '<';
//    const char endOfNumberDelimiter   = '>';
//    
//    int sizeOfData = 3 + sizeof(float);
//    [self sendData:(char[]){CMD_SET_KD, startOfNumberDelimiter, targetKd, endOfNumberDelimiter} length:sizeOfData];
    
    NSString *floatString = [NSString stringWithFormat:@"%f", targetKd];
    
    const char *cstrFloat = [floatString UTF8String];
    
    int sizeOfData = sizeof(cstrFloat);
    
    [self sendData:(char[]){CMD_SET_KD} length:1];
    [self sendData:cstrFloat length:sizeOfData];
    NSLog(@"sent Kd: %s", cstrFloat);

    
}


// Start asking the Bean for status updates every 5 seconds.
- (void)startUpdateRequests
{
    // Disable any prior timers
    [self stopUpdateRequests];
    
    // Schedule update requests to run every 5 seconds
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:UPDATE_INTERVAL_SECS
                                                        target:self
                                                      selector:@selector(requestUpdate)
                                                      userInfo:nil
                                                       repeats:YES];

    // Send an update request immediately
    [self requestUpdate];
}

// Cancel the update timer and stop asking the Bean for updates.
- (void)stopUpdateRequests
{
    if (self.updateTimer) {
        [self.updateTimer invalidate];
    }
    self.updateTimer = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
