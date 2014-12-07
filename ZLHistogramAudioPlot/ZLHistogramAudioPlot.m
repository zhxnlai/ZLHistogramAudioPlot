//
//  MRBarChartAudioPlot.m
//  MurmurReborn
//
//  Created by Zhixuan Lai on 8/2/14.
//  Copyright (c) 2014 Zhixuan Lai. All rights reserved.
//

#import "ZLHistogramAudioPlot.h"
#import <math.h>
#import <Accelerate/Accelerate.h>
#import "EZAudio.h"

const Float32 kAdjust0DB = 1.5849e-13;
const float kTimerDelay = 1/60.0;

@interface ZLHistogramAudioPlot() {
    int tick;
    float *dataBuffer;
    size_t bufferCapacity;	// In samples
    size_t index;	// In samples
    
    FFTSetup fftSetup;
    COMPLEX_SPLIT A;
    int log2n, n, nOver2;
    
    float sampleRate;
    float frequency;
    
    float *speeds;
    float *times;
    
    // in percent
    CGFloat rollingOffset;
    
    float *heightsByFrequency;
    NSUInteger numOfBins;
}

@property (strong,nonatomic) NSMutableArray *heightsByTime;
@property (strong,nonatomic) NSTimer *timer;

@end

@implementation ZLHistogramAudioPlot
@synthesize backgroundColor = _backgroundColor;
@synthesize color           = _color;
@synthesize plotType        = _plotType;
@synthesize numOfBins;
@synthesize padding;
@synthesize gain;
@synthesize gravity;

#pragma mark - Init
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setup:frame];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self layoutIfNeeded];
    [self setup:self.frame];
}

- (void)setup:(CGRect)frame {
    // default attributes
    self.maxFrequency = 10000;
    self.minFrequency = 1200;
    self.numOfBins = 30;
    self.padding = 1/10.0;
    self.gain = 10;
    self.gravity = 10*kTimerDelay;
    self.color = [UIColor grayColor];
    self.colors =     @[[UIColor colorWithRed:242/255.0 green:128/255.0 blue:78/255.0 alpha:1],
                        [UIColor colorWithRed:40/255.0 green:56/255.0 blue:72/255.0 alpha:1],
                        [UIColor colorWithRed:244/255.0 green:234/255.0 blue:119/255.0 alpha:1],
                        [UIColor colorWithRed:255/255.0 green:197/255.0 blue:69/255.0 alpha:1],
                        [UIColor colorWithRed:193/255.0 green:75/255.0 blue:43/255.0 alpha:1],
                        [UIColor colorWithRed:40/255.0 green:181/255.0 blue:164/255.0 alpha:1],
                        [UIColor colorWithRed:208/255.0 green:221/255.0 blue:38/255.0 alpha:1],
                        ];
    

    // RealFFT setup
    UInt32 maxFrames = 2048;
    dataBuffer = (float*)malloc(maxFrames * sizeof(float));
    log2n = log2f(maxFrames);
    n = 1 << log2n;
    assert(n == maxFrames);
    nOver2 = maxFrames/2;
    bufferCapacity = maxFrames;
    index = 0;
    A.realp = (float *)malloc(nOver2 * sizeof(float));
    A.imagp = (float *)malloc(nOver2 * sizeof(float));
    fftSetup = vDSP_create_fftsetup(log2n, FFT_RADIX2);
    
    // inherited properties
    _plotType = EZPlotTypeRolling;
    
    // Configure audio session
    AVAudioSession *session = [AVAudioSession sharedInstance];
    sampleRate = session.sampleRate;

    // schedule timer
    if (self.timer == nil) { self.timer = [NSTimer scheduledTimerWithTimeInterval:kTimerDelay target:self selector:@selector(updateHeights) userInfo:nil repeats:YES];}
}

- (void)dealloc {
    [self.timer invalidate];
    self.timer = nil;
    if( plotData ){free(plotData);}
    if (heightsByFrequency) {free(heightsByFrequency);}
    if (speeds) {free(speeds);}
    if (times) {free(heightsByFrequency);}
}

#pragma mark - Properties
- (void)setNumOfBins:(NSUInteger)someNumOfBins {
    numOfBins = someNumOfBins;
    
    // reset buffers
    if (heightsByFrequency) {free(heightsByFrequency);}
    if (speeds) {free(speeds);}
    if (times) {free(times);}
    
    heightsByFrequency = (float *)calloc(sizeof(float), numOfBins);
    self.heightsByTime = [NSMutableArray arrayWithCapacity:numOfBins];
    for (int i=0; i<numOfBins; i++) {
        self.heightsByTime[i] = [NSNumber numberWithFloat:0];
    }
    speeds = (float *)calloc(sizeof(int), numOfBins);
    times = (float *)calloc(sizeof(int), numOfBins);
    rollingOffset = 0;
}

#pragma mark - Timer Callback
- (void)updateHeights {
    if (heightsByFrequency) {
        // increment time
        vDSP_vsadd(times, 1, &kTimerDelay, times, 1, numOfBins);
        
        // clamp time
        static const float timeMin = 1.5, timeMax = 10;
        vDSP_vclip(times, 1, &timeMin, &timeMax, times, 1, numOfBins);
        
        // increment speed
        vDSP_vsma(times, 1, &gravity, speeds, 1, speeds, 1, numOfBins);
        
        // increment height
        float *tSqrt = (float *)calloc(sizeof(float), numOfBins);
        vDSP_vsq(times, 1, tSqrt, 1, numOfBins);
        float *vt = (float *)calloc(sizeof(float), numOfBins);
        vDSP_vmul(speeds, 1, times, 1, vt, 1, numOfBins);
        float aOver2 = gravity/2;
        float *deltaHeight = (float *)calloc(sizeof(float), numOfBins);
        vDSP_vsma(tSqrt, 1, &aOver2, vt, 1, deltaHeight, 1, numOfBins);
        vDSP_vneg(deltaHeight, 1, deltaHeight, 1, numOfBins);
        vDSP_vadd(heightsByFrequency, 1, deltaHeight, 1, heightsByFrequency, 1, numOfBins);
        
        free(tSqrt);
        free(vt);
        free(deltaHeight);
    }
}

#pragma mark - Update Buffers
- (void)setSampleData:(float *)data
              length:(int)length {
    int requiredTickes = 1; // Alter this to draw more or less often
    tick = (tick+1)%requiredTickes;
    
    uint32_t stride = 1;
    
    // Fill the buffer with our sampled data. If we fill our buffer, run the fft.
    int inNumberFrames = length;
    int read = bufferCapacity - index;
    if (read > inNumberFrames) {
        memcpy((float *)dataBuffer + index, data, inNumberFrames*sizeof(float));
        index += inNumberFrames;
        
        rollingOffset = (float)index/bufferCapacity;
    } else {
        rollingOffset = 0;
        // If we enter this conditional, our buffer will be filled and we should perform the FFT.
        memcpy((float *)dataBuffer + index, data, read*sizeof(float));
        
        // Reset the index.
        index = 0;
        
        /*************** FFT ***************/
        /**
         Look at the real signal as an interleaved complex vector by casting it.
         Then call the transformation function vDSP_ctoz to get a split complex
         vector, which for a real signal, divides into an even-odd configuration.
         */
        vDSP_ctoz((COMPLEX*)dataBuffer, 2, &A, 1, nOver2);
        
        // Carry out a Forward FFT transform.
        vDSP_fft_zrip(fftSetup, &A, stride, log2n, FFT_FORWARD);
        
        // The output signal is now in a split real form. Use the vDSP_ztoc to get
        // a split real vector.
        vDSP_ztoc(&A, 1, (COMPLEX *)dataBuffer, 2, nOver2);
        Float32 one = 1;
        
        // counvert to dB
        vDSP_vsq(dataBuffer, 1, dataBuffer, 1, inNumberFrames);
        vDSP_vsadd(dataBuffer, 1, &kAdjust0DB, dataBuffer, 1, inNumberFrames);
        vDSP_vdbcon(dataBuffer, 1, &one, dataBuffer, 1, inNumberFrames, 0);
        
        float mul = (sampleRate/bufferCapacity)/2;
        int minFrequencyIndex = self.minFrequency/mul;
        int maxFrequencyIndex = self.maxFrequency/mul;
        int numDataPointsPerColumn = (maxFrequencyIndex-minFrequencyIndex)/numOfBins;
        float maxHeight = 0;
        
        for(NSUInteger i=0;i<numOfBins;i++) {
            float avg = 0;
            vDSP_meanv(dataBuffer+minFrequencyIndex+i*numDataPointsPerColumn, 1, &avg, numDataPointsPerColumn);
            
            CGFloat columnHeight = MIN(avg*gain, CGRectGetHeight(self.bounds));
            maxHeight = MAX(maxHeight, columnHeight);
            CGFloat previousHeight = heightsByFrequency[i];

            CGFloat newHeight = MAX(columnHeight, previousHeight);
            if (columnHeight>previousHeight) {
                speeds[i] = 0;
                times[i] = 0;
            }
            
            heightsByFrequency[i] = newHeight;
        }
        
        [self.heightsByTime addObject: [NSNumber numberWithFloat:maxHeight]];
        
        if (self.heightsByTime.count>numOfBins) {
            [self.heightsByTime removeObjectAtIndex:0];
        }
    }
    
    if (tick==0) {
        [self _refreshDisplay];
    }
}

- (void)updateBuffer:(float *)buffer withBufferSize:(UInt32)bufferSize {
    [self setSampleData:buffer length:bufferSize];
}

#pragma mark - Drawing
- (void)drawRect:(CGRect)rect
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSaveGState(ctx);
    CGRect frame = self.bounds;
    
    // Set the background color
    [(UIColor*)self.backgroundColor set];
    UIRectFill(frame);
    
    CGFloat columnWidth = rect.size.width/numOfBins;
    CGFloat actualWidth = MAX(1, columnWidth*(1-2*padding));
    CGFloat actualPadding = (columnWidth-actualWidth)/2;
    // TODO: warning: padding is larger than width
    
    for(NSUInteger i=0;i<numOfBins;i++) {
        CGFloat columnHeight = _plotType==EZPlotTypeBuffer ? heightsByFrequency[i] : [self.heightsByTime[i] floatValue];
        columnHeight = MAX(0, columnHeight);
        CGFloat columnX = i*columnWidth - (_plotType==EZPlotTypeBuffer ? 0 : columnWidth*rollingOffset);
        UIBezierPath* rectanglePath = [UIBezierPath bezierPathWithRect:
                                       CGRectMake(columnX+actualPadding, CGRectGetHeight(frame)-columnHeight, actualWidth, columnHeight)];
        UIColor *color = (_plotType == EZPlotTypeBuffer&&self.colors) ? [self.colors objectAtIndex:i%self.colors.count] : self.color;
        [color setFill];
        [rectanglePath fill];
    }
    
    CGContextRestoreGState(ctx);
}

- (void)_refreshDisplay {
#if TARGET_OS_IPHONE
    [self setNeedsDisplay];
#elif TARGET_OS_MAC
    [self setNeedsDisplay:YES];
#endif
}

#pragma mark - ()
void printFloatArray(float * array, int length, NSString *prefix) {
    NSMutableString *str = [NSMutableString string];
    for (int i=0; i<length; i++) {
        [str appendFormat:@"%f ", array[i]];
    }
    NSLog(@"%@ %@", prefix, str);
}

@end
