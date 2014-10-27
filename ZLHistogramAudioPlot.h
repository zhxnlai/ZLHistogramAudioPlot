//
//  MRBarChartAudioPlot.h
//  MurmurReborn
//
//  Created by Zhixuan Lai on 8/2/14.
//  Copyright (c) 2014 Zhixuan Lai. All rights reserved.
//

#import "EZAudioPlot.h"

@interface ZLHistogramAudioPlot : EZAudioPlot

/**
 *  the width of columns
 */
@property (nonatomic) CGFloat barChartColumnWidth;
@property (strong,nonatomic) NSArray *barChartColors;
@property (strong,nonatomic) NSArray *barChartGrayColors;

@property (nonatomic) BOOL shouldUseGrayColors;

@property (nonatomic) CGFloat rollingPlotColumnWidth;
@property (nonatomic) CGFloat rollingPlotGapWidth;
@property (strong,nonatomic) UIColor *rollingPlotColor;
@property (strong,nonatomic) UIColor *rollingPlotSelectedColor;


@property (nonatomic) float logBase;
@property (nonatomic) float multiplier;
@property (nonatomic) float heightDecendingAcceleration;

@end
