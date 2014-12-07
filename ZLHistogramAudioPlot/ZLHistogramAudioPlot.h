//
//  MRBarChartAudioPlot.h
//  MurmurReborn
//
//  Created by Zhixuan Lai on 8/2/14.
//  Copyright (c) 2014 Zhixuan Lai. All rights reserved.
//

#import "EZAudioPlot.h"

@interface ZLHistogramAudioPlot : EZAudioPlot

/// The upper bound of the frequency range the audio plot will process. Default: 10000Hz
@property (nonatomic) float maxFrequency;

/// The lower bound of the frequency range the audio plot will process. Default: 1200Hz
@property (nonatomic) float minFrequency;

/// The number of bins in the audio plot. Default: 30
@property (nonatomic) NSUInteger numOfBins;

/// The padding of the bins in percent. Default: 0.1
@property (nonatomic) CGFloat padding;

/// The gain applied the heights of bins. Default: 10
@property (nonatomic) CGFloat gain;

/// A float that specifies the vertical gravitational acceleration applied to bins in the audio plot. Default: 10 pixel/s^2
@property (nonatomic) float gravity;

/// The color of bins in the audio plot
@property (strong,nonatomic) UIColor *color;

/// An array of color objects defining the color of each bin in the audio plot. If not set, the color attribute will be used instead. Currently not supported by Buffer type.
@property (strong,nonatomic) NSArray *colors;

@end
