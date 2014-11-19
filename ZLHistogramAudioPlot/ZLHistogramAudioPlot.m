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

@interface ZLHistogramAudioPlot() {
    int tick;
    float *dataBuffer;
//    float *outputBuffer;
    size_t bufferCapacity;	// In samples
    size_t index;	// In samples
    
    FFTSetup fftSetup;
    COMPLEX_SPLIT A;
    int log2n, n, nOver2;
    
    float sampleRate;
    float frequency;
    
    float maxFrequency;
    float minFrequency;

    float *heightDecendingSpeeds;
    float *heightDecendingTimes;
    
    // Rolling History
    BOOL    _setMaxLength;
    float   *_scrollHistory;
    int     _scrollHistoryIndex;
    UInt32  _scrollHistoryLength;
    BOOL    _changingHistorySize;

    int rollingCounter;
    CGFloat rollingOffset;
}

@property (strong,nonatomic) NSMutableArray *heightsBuffer;

@property (strong,nonatomic) NSMutableArray *heightsRolling;


@property (nonatomic) NSUInteger numOfColumnsBuffer;
@property (nonatomic) NSUInteger numOfColumnsRolling;

@property (strong,nonatomic) NSDate *lastUpdate;

@property (strong,nonatomic) NSTimer *heightDescendTimer;

@end

@implementation ZLHistogramAudioPlot
@synthesize backgroundColor = _backgroundColor;
@synthesize color           = _color;
@synthesize gain            = _gain;
@synthesize plotType        = _plotType;
@synthesize shouldFill      = _shouldFill;
@synthesize shouldMirror    = _shouldMirror;

@synthesize barChartColors;
@synthesize barChartGrayColors;
@synthesize shouldUseGrayColors;
@synthesize barChartColumnWidth;
@synthesize numOfColumnsBuffer;

@synthesize rollingPlotColor;
@synthesize rollingPlotSelectedColor;
@synthesize rollingPlotColumnWidth;
@synthesize rollingPlotGapWidth;
@synthesize numOfColumnsRolling;

@synthesize heightsBuffer;
@synthesize heightsRolling;

@synthesize logBase;
@synthesize multiplier;

@synthesize lastUpdate;
@synthesize heightDecendingAcceleration;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setup:frame];
    }
    return self;
}

-(void)awakeFromNib {
    [super awakeFromNib];
    
    [self layoutIfNeeded];
    [self setup:self.frame];
}

-(void)setup:(CGRect)frame {
    // Initialization code
    barChartColumnWidth = 12.8f;
    //        barChartColors = @[[UIColor colorWithRed:1 green:0.467 blue:0 alpha:1], [UIColor blackColor], [UIColor colorWithRed:0.157 green:0.6 blue:0.765 alpha:1], [UIColor colorWithRed:0.125 green:0.675 blue:0.910 alpha:1], [UIColor colorWithRed:0.310 green:0.765 blue:0.341 alpha:1]];
    barChartColors = @[[UIColor colorWithRed:242/255.0 green:128/255.0 blue:78/255.0 alpha:1],
                       [UIColor colorWithRed:40/255.0 green:56/255.0 blue:72/255.0 alpha:1],
                       [UIColor colorWithRed:244/255.0 green:234/255.0 blue:119/255.0 alpha:1],
                       [UIColor colorWithRed:255/255.0 green:197/255.0 blue:69/255.0 alpha:1],
                       [UIColor colorWithRed:193/255.0 green:75/255.0 blue:43/255.0 alpha:1],
                       [UIColor colorWithRed:40/255.0 green:181/255.0 blue:164/255.0 alpha:1],
                       [UIColor colorWithRed:208/255.0 green:221/255.0 blue:38/255.0 alpha:1],
                       ];
    
    barChartGrayColors = @[
                           [UIColor colorWithRed:241/255.0 green:242/255.0 blue:242/255.0 alpha:1],
                           [UIColor colorWithRed:230/255.0 green:231/255.0 blue:232/255.0 alpha:1],
                           [UIColor colorWithRed:209/255.0 green:211/255.0 blue:212/255.0 alpha:1],
                           [UIColor colorWithRed:188/255.0 green:190/255.0 blue:192/255.0 alpha:1],
                           [UIColor colorWithRed:167/255.0 green:169/255.0 blue:172/255.0 alpha:1],
                           [UIColor colorWithRed:147/255.0 green:149/255.0 blue:152/255.0 alpha:1],
                           [UIColor colorWithRed:128/255.0 green:130/255.0 blue:133/255.0 alpha:1],
                           ];
    
    numOfColumnsBuffer = CGRectGetWidth(frame)/barChartColumnWidth+1;
    
    
    rollingPlotColumnWidth = 3;
    rollingPlotGapWidth = 2;
    rollingPlotSelectedColor = [UIColor blackColor];
    rollingPlotColor = [UIColor lightGrayColor];
    numOfColumnsRolling = CGRectGetWidth(frame)/(rollingPlotColumnWidth+rollingPlotGapWidth)+1;
    
    rollingCounter = 0;
    rollingOffset = 0;
    
    
    _gain = 1000;
    
    heightsBuffer = [NSMutableArray arrayWithCapacity:numOfColumnsBuffer];
    for (int i=0; i<numOfColumnsBuffer; i++) {
        heightsBuffer[i] = [NSNumber numberWithFloat:0];
    }
    
    heightsRolling = [NSMutableArray arrayWithCapacity:numOfColumnsRolling];
    for (int i=0; i<numOfColumnsRolling; i++) {
        heightsRolling[i] = [NSNumber numberWithFloat:0];
    }
    
    logBase = 2;
    multiplier = 22;
    
    maxFrequency = 10000;
    minFrequency = 1200;
    
    [self realFFTSetup];
    
    lastUpdate = [NSDate date];
    
    
    _plotType = EZPlotTypeRolling;
    
    _scrollHistory       = NULL;
    _scrollHistoryLength = kEZAudioPlotDefaultHistoryBufferLength;

}

/* Setup our FFT */
- (void)realFFTSetup {
    UInt32 maxFrames = 2048;
    dataBuffer = (float*)malloc(maxFrames * sizeof(float));
//    outputBuffer = (float*)malloc(maxFrames *sizeof(float));
    log2n = log2f(maxFrames);
    n = 1 << log2n;
    assert(n == maxFrames);
    nOver2 = maxFrames/2;
    bufferCapacity = maxFrames;
    index = 0;
    A.realp = (float *)malloc(nOver2 * sizeof(float));
    A.imagp = (float *)malloc(nOver2 * sizeof(float));
    fftSetup = vDSP_create_fftsetup(log2n, FFT_RADIX2);
    
    AVAudioSession *session = [AVAudioSession sharedInstance];
    sampleRate = session.sampleRate;
    
    heightDecendingSpeeds = (float *)calloc(sizeof(int), numOfColumnsBuffer);
    heightDecendingTimes = (float *)calloc(sizeof(int), numOfColumnsBuffer);
    
    heightDecendingAcceleration = 0.1;
    if (self.heightDescendTimer == nil) {
        self.heightDescendTimer = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(updateHeights) userInfo:nil repeats:YES];
    }
}
-(void)dealloc {
    [self.heightDescendTimer invalidate];
    self.heightDescendTimer = nil;
    if( plotData ){
        free(plotData);
    }
}
float MagnitudeSquared(float x, float y) {
    return ((x*x) + (y*y));
}

-(void)updateHeights {
    if (heightsBuffer && _plotType == EZPlotTypeBuffer) {
        for(NSUInteger i=0;i<numOfColumnsBuffer;i++) {
            CGFloat previousHeight = [heightsBuffer[i] floatValue];
            
            CGFloat timeIncrement = 0.01;
            heightDecendingTimes[i] = MAX(heightDecendingTimes[i]+timeIncrement, 1.5);
            
            heightDecendingSpeeds[i] = MIN(MAX(heightDecendingSpeeds[i]+heightDecendingAcceleration*powf(heightDecendingTimes[i], 2), 0.1), 5);
            
            CGFloat newHeight = MAX(0,previousHeight-heightDecendingSpeeds[i]);
            
            heightsBuffer[i] = [NSNumber numberWithFloat:newHeight];
        }
    }
    
    
}

-(void)setSampleData:(float *)data
              length:(int)length {
    
    int requiredTickes = 1; // Alter this to draw more or less often
    tick = (tick+1)%requiredTickes;
    
    
    if (_plotType == EZPlotTypeBuffer) {

        NSMutableArray *magnitudes = nil;

        uint32_t stride = 1;

        // Fill the buffer with our sampled data. If we fill our buffer, run the
        // fft.
        int inNumberFrames = length;
        int read = bufferCapacity - index;
        if (read > inNumberFrames) {
            memcpy((float *)dataBuffer + index, data, inNumberFrames*sizeof(float));
            index += inNumberFrames;
        } else {
            // If we enter this conditional, our buffer will be filled and we should
            // perform the FFT.
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

            
            magnitudes = [[NSMutableArray alloc] initWithCapacity:numOfColumnsBuffer];
            for (int i=0; i<numOfColumnsBuffer; i++) {
                magnitudes[i] = [[NSMutableArray alloc] init];
            }
            
            // Determine the dominant frequency by taking the magnitude squared and
            // saving the bin which it resides in.
            int bin = -1;
            for (int i=0; i<n; i+=2) {

                float curFreqMagnitude = MagnitudeSquared(dataBuffer[i], dataBuffer[i+1]);
                bin = (i+1)/2;
                float curFreqInHz = bin*(sampleRate/bufferCapacity);
                
                if (curFreqInHz>minFrequency && curFreqInHz<maxFrequency) {
                    float percent = (curFreqInHz-minFrequency)/(maxFrequency-minFrequency);
                    float width = 1.0/numOfColumnsBuffer;
                    int arrayIndex = percent/width;

                    [(NSMutableArray *)magnitudes[arrayIndex] addObject: [NSNumber numberWithFloat: curFreqMagnitude]];
                    
                }
                
            }
        }
        
        
        for(NSUInteger i=0;i<numOfColumnsBuffer;i++) {
            
            CGFloat avg = 0;
            if (magnitudes) {
                avg = [[magnitudes[i] valueForKeyPath:@"@avg.floatValue"] floatValue];
            }

            CGFloat columnHeight = MIN(1+multiplier*(logf(avg+1)/logf(logBase)), CGRectGetHeight(self.bounds));
            
            float multi = 1/(0.3*columnHeight)+1;
            columnHeight = MIN(columnHeight*multi-2, CGRectGetHeight(self.bounds));

            CGFloat previousHeight = [heightsBuffer[i] floatValue];

            CGFloat newHeight = 0;
            if (columnHeight>previousHeight) {
                newHeight = columnHeight;
                heightDecendingSpeeds[i] = 0;
                heightDecendingTimes[i] = 0;
            } else {
                newHeight = previousHeight;
                
            }

            heightsBuffer[i] = [NSNumber numberWithFloat:newHeight];
            
        }
    }
    
    if (_plotType == EZPlotTypeRolling) {
        
        static BOOL firstCall = NO;
        if (!firstCall) {
            firstCall = YES;
            return;
        }
        
        static BOOL initialState = YES;
        static int initialStateCounter = 0;
        
        int numDataPointsPerColumn = 2;

        CGFloat pixelsPerDataPoint = (rollingPlotColumnWidth+rollingPlotGapWidth)/numDataPointsPerColumn;
        
        if (rollingCounter>=numDataPointsPerColumn-1 && length>numDataPointsPerColumn) {
            float total = 0;
            float max = 0;
            if (initialState) {
                for (int j=initialStateCounter-numDataPointsPerColumn; j<initialStateCounter; j++) {
                    total += data[j];
                    if (max<data[j]) {
                        max = data[j];
                    }
                }

            } else {
                for (int j=length-numDataPointsPerColumn; j<length; j++) {
                    total += data[j];
                    if (max<data[j]) {
                        max = data[j];
                    }
                }
            }

            
            float avg = total/numDataPointsPerColumn;
            float newHeight = avg*_gain/50;
            
            CGFloat columnHeight = MIN(1+multiplier*(logf(newHeight+1)/logf(logBase)), CGRectGetHeight(self.bounds));
            
            float multi = 1/(0.3*columnHeight)+1;
            columnHeight = MIN(columnHeight*multi-2-2, CGRectGetHeight(self.bounds));
            
            [heightsRolling addObject: [NSNumber numberWithFloat:columnHeight]];
            [heightsRolling removeObjectAtIndex:0];
            rollingCounter = 0;
        } else {
            rollingCounter ++;
        }
        
        rollingOffset = pixelsPerDataPoint*rollingCounter;

        initialStateCounter++;
        initialState = initialStateCounter<length;


    }
    
    
    if (tick==0) {
        
        [self _refreshDisplay];
        //        NSLog(@"drwaing");
    } else {
        //        NSLog(@"not drwaing");
    }
}
#pragma mark - Update
-(void)updateBuffer:(float *)buffer withBufferSize:(UInt32)bufferSize {
    if( _plotType == EZPlotTypeRolling ){
        
        // Update the scroll history datasource
        [EZAudio updateScrollHistory:&_scrollHistory
                          withLength:_scrollHistoryLength
                             atIndex:&_scrollHistoryIndex
                          withBuffer:buffer
                      withBufferSize:bufferSize
                isResolutionChanging:&_changingHistorySize];
        
        //
        [self setSampleData:_scrollHistory
                     length:(!_setMaxLength?kEZAudioPlotMaxHistoryBufferLength:_scrollHistoryLength)];
        _setMaxLength = YES;
        
    }
    else if( _plotType == EZPlotTypeBuffer ){
        
        [self setSampleData:buffer
                     length:bufferSize];
        
    }
    else {
        
        // Unknown plot type
        
    }
}

#pragma mark - Adjust Resolution
-(int)setRollingHistoryLength:(int)historyLength {
    historyLength = MIN(historyLength,kEZAudioPlotMaxHistoryBufferLength);
    size_t floatByteSize = sizeof(float);
    _changingHistorySize = YES;
    if( _scrollHistoryLength != historyLength ){
        _scrollHistoryLength = historyLength;
    }
    _scrollHistory = realloc(_scrollHistory,_scrollHistoryLength*floatByteSize);
    if( _scrollHistoryIndex < _scrollHistoryLength ){
        memset(&_scrollHistory[_scrollHistoryIndex],
               0,
               (_scrollHistoryLength-_scrollHistoryIndex)*floatByteSize);
    }
    else {
        _scrollHistoryIndex = _scrollHistoryLength;
    }
    _changingHistorySize = NO;
    return historyLength;
}

-(int)rollingHistoryLength {
    return _scrollHistoryLength;
}


- (void)drawRect:(CGRect)rect
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSaveGState(ctx);
    CGRect frame = self.bounds;
    
    
    // Set the background color
    [(UIColor*)self.backgroundColor set];
    UIRectFill(frame);
    // Set the waveform line color
    [(UIColor*)self.color set];
    //

    if (_plotType == EZPlotTypeBuffer) {
        for(NSUInteger i=0;i<numOfColumnsBuffer;i++) {
            CGFloat columnHeight = [heightsBuffer[i] floatValue];
            CGFloat columnX = i*barChartColumnWidth;
            UIBezierPath* rectanglePath = [UIBezierPath bezierPathWithRect: CGRectMake(columnX, CGRectGetHeight(frame)-columnHeight, barChartColumnWidth, columnHeight)];
            
            NSArray *colorSet = shouldUseGrayColors? barChartGrayColors : barChartColors ;
            UIColor *color = [colorSet objectAtIndex:i%colorSet.count];
            if (_plotType == EZPlotTypeRolling) {
                color = [UIColor grayColor];
            }
            [color setFill];
            [rectanglePath fill];
        }
    }

    if (_plotType == EZPlotTypeRolling) {
        for(NSUInteger i=0;i<numOfColumnsRolling;i++) {
            CGFloat columnHeight = [heightsRolling[i] floatValue];
            CGFloat columnX = i*(rollingPlotColumnWidth+rollingPlotGapWidth)-rollingOffset;
            UIBezierPath* rectanglePath = [UIBezierPath bezierPathWithRect: CGRectMake(columnX, CGRectGetHeight(frame)-columnHeight, rollingPlotColumnWidth, columnHeight)];
            
            UIColor *color = rollingPlotColor;
            
            [color setFill];
            [rectanglePath fill];
        }

    }
    CGContextRestoreGState(ctx);
}


-(void)_refreshDisplay {
#if TARGET_OS_IPHONE
    [self setNeedsDisplay];
#elif TARGET_OS_MAC
    [self setNeedsDisplay:YES];
#endif
}


@end
