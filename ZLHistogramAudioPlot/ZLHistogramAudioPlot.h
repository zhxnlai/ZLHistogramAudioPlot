//
//  MRBarChartAudioPlot.h
//  MurmurReborn
//
//  Created by Zhixuan Lai on 8/2/14.
//  Copyright (c) 2014 Zhixuan Lai. All rights reserved.
//

#import "EZAudioPlot.h"

@interface ZLHistogramAudioPlot : EZAudioPlot

#pragma mark - TypeBuffer

@property (nonatomic) float minFrequency;
@property (nonatomic) float maxFrequency;

@property (nonatomic) CGFloat barChartColumnWidth;
@property (strong,nonatomic) NSArray *barChartColors;

#pragma mark - TypeRolling

@property (nonatomic) CGFloat rollingPlotColumnWidth;
@property (nonatomic) CGFloat rollingPlotGapWidth;
@property (strong,nonatomic) UIColor *rollingPlotColor;
@property (strong,nonatomic) UIColor *rollingPlotSelectedColor;


@property (nonatomic) float heightDecendingAcceleration;

@end
