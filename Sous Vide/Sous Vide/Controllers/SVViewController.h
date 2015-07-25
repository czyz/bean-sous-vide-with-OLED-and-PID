//
//  SVViewController.h
//  Sous Vide
//
//  Created by Matthew Lewis on 6/19/14.
//  Copyright (c) 2014 Kestrel Development. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <PTDBeanManager.h>


//#import "CorePlot-CocoaTouch.h"
#import "SVCorePlotGraphHostingView.h"



@interface SVViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIImageView *btStatusIcon;
@property (weak, nonatomic) IBOutlet UILabel *btStatusLabel;
@property (weak, nonatomic) IBOutlet UIImageView *beanStatusIcon;
@property (weak, nonatomic) IBOutlet UILabel *beanStatusLabel;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *beanStatusSpinner;

@property (weak, nonatomic) IBOutlet UIImageView *heatingIcon;
@property (weak, nonatomic) IBOutlet UILabel *tempLabel;
@property (weak, nonatomic) IBOutlet UILabel *heatingLabel;

@property (weak, nonatomic) IBOutlet UILabel *targetTempLabel;
@property (weak, nonatomic) IBOutlet UISlider *targetTempSlider;
@property (weak, nonatomic) IBOutlet UIStepper *targetTempStepper;


@property (weak, nonatomic) IBOutlet UILabel *cookingLabel;
@property (weak, nonatomic) IBOutlet UISwitch *cookingSwitch;

@property (weak, nonatomic) IBOutlet UIButton *autotune;
@property (weak, nonatomic) IBOutlet UITextField *pidKp;
@property (weak, nonatomic) IBOutlet UITextField *pidKi;
@property (weak, nonatomic) IBOutlet UITextField *pidKd;

@property (weak, nonatomic) IBOutlet UIScrollView *mainScrollView;

@property (strong, nonatomic) IBOutlet UIScrollView *infoScrollView;


@property (weak, nonatomic) IBOutlet UIScrollView *BluetoothBeanConnectionBanner;


@property (strong, nonatomic) IBOutlet UIPageControl *mainInterfacePage;

@property (strong, nonatomic) IBOutlet UIPageControl *mainInfoPageControl;

@property (strong, nonatomic) IBOutlet SVCorePlotGraphHostingView *GraphHostView;


@end
