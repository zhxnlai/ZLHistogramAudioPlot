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
const float heightsUpdateInterval = 1/60.0;

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
    
    
    float *heightsBuffer;
    
}

@property (strong,nonatomic) NSMutableArray *heightsRolling;


@property (nonatomic) NSUInteger numOfColumnsBuffer;
@property (nonatomic) NSUInteger numOfColumnsRolling;


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
@synthesize barChartColumnWidth;
@synthesize numOfColumnsBuffer;

@synthesize rollingPlotColor;
@synthesize rollingPlotSelectedColor;
@synthesize rollingPlotColumnWidth;
@synthesize rollingPlotGapWidth;
@synthesize numOfColumnsRolling;

@synthesize heightsRolling;

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
    
    NSArray* barChartGrayColors = @[
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
    
    
    heightsBuffer = (float *)calloc(sizeof(float), numOfColumnsBuffer);
    
    heightsRolling = [NSMutableArray arrayWithCapacity:numOfColumnsRolling];
    for (int i=0; i<numOfColumnsRolling; i++) {
        heightsRolling[i] = [NSNumber numberWithFloat:0];
    }
    
    self.maxFrequency = 10000;
    self.minFrequency = 1200;
    
    [self realFFTSetup];
    
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
    
    heightDecendingAcceleration = 0.1/0.01*heightsUpdateInterval;
    if (self.heightDescendTimer == nil) {
        self.heightDescendTimer = [NSTimer scheduledTimerWithTimeInterval:heightsUpdateInterval target:self selector:@selector(updateHeights) userInfo:nil repeats:YES];
    }
}
-(void)dealloc {
    [self.heightDescendTimer invalidate];
    self.heightDescendTimer = nil;
    if( plotData ){
        free(plotData);
    }
}

void printFloatArray(float * array, int length, NSString *prefix) {
    NSMutableString *str = [NSMutableString string];
    for (int i=0; i<length; i++) {
        [str appendFormat:@"%f ", array[i]];
    }
    NSLog(@"%@ %@", prefix, str);
}

-(void)updateHeights {
    if (heightsBuffer && _plotType == EZPlotTypeBuffer) {
        vDSP_vsadd(heightDecendingTimes, 1, &heightsUpdateInterval, heightDecendingTimes, 1, numOfColumnsBuffer);
        
        static const float timeMin = 1.5, timeMax = 10;
        vDSP_vclip(heightDecendingTimes, 1, &timeMin, &timeMax, heightDecendingTimes, 1, numOfColumnsBuffer);
        
        vDSP_vsma(heightDecendingTimes, 1, &heightDecendingAcceleration, heightDecendingSpeeds, 1, heightDecendingSpeeds, 1, numOfColumnsBuffer);
        
        
        float *tSqrt = (float *)calloc(sizeof(float), numOfColumnsBuffer);
        vDSP_vsq(heightDecendingTimes, 1, tSqrt, 1, numOfColumnsBuffer);
        float *vt = (float *)calloc(sizeof(float), numOfColumnsBuffer);
        vDSP_vmul(heightDecendingSpeeds, 1, heightDecendingTimes, 1, vt, 1, numOfColumnsBuffer);
        
        float aOver2 = heightDecendingAcceleration/2;
        float *deltaHeight = (float *)calloc(sizeof(float), numOfColumnsBuffer);
        vDSP_vsma(tSqrt, 1, &aOver2, vt, 1, deltaHeight, 1, numOfColumnsBuffer);
        vDSP_vneg(deltaHeight, 1, deltaHeight, 1, numOfColumnsBuffer);
        
        vDSP_vadd(heightsBuffer, 1, deltaHeight, 1, heightsBuffer, 1, numOfColumnsBuffer);
        
        free(tSqrt);
        free(vt);
        free(deltaHeight);
    }
}

-(void)setSampleData:(float *)data
              length:(int)length {
    int requiredTickes = 1; // Alter this to draw more or less often
    tick = (tick+1)%requiredTickes;
    
    if (_plotType == EZPlotTypeBuffer) {
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
            Float32 one = 1;
            
            // counvert to dB
            vDSP_vsq(dataBuffer, 1, dataBuffer, 1, inNumberFrames);
            vDSP_vsadd(dataBuffer, 1, &kAdjust0DB, dataBuffer, 1, inNumberFrames);
            vDSP_vdbcon(dataBuffer, 1, &one, dataBuffer, 1, inNumberFrames, 0);
            
            float mul = (sampleRate/bufferCapacity)/2;
            int minFrequencyIndex = self.minFrequency/mul;
            int maxFrequencyIndex = self.maxFrequency/mul;
            int numDataPointsPerColumn = (maxFrequencyIndex-minFrequencyIndex)/numOfColumnsBuffer;
            
            for(NSUInteger i=0;i<numOfColumnsBuffer;i++) {
                float avg = 0;
                vDSP_meanv(dataBuffer+minFrequencyIndex+i*numDataPointsPerColumn, 1, &avg, numDataPointsPerColumn);
                
                CGFloat columnHeight = MIN(avg*10, CGRectGetHeight(self.bounds));
                CGFloat previousHeight = heightsBuffer[i];
                
                CGFloat newHeight = MAX(columnHeight, previousHeight);
                if (columnHeight>previousHeight) {
                    heightDecendingSpeeds[i] = 0;
                    heightDecendingTimes[i] = 0;
                }
                
                heightsBuffer[i] = newHeight;
            }
            
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
            
            // TODO: convert to dB
            CGFloat columnHeight = MIN(newHeight, CGRectGetHeight(self.bounds));
            
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
    
    if (_plotType == EZPlotTypeBuffer) {
        for(NSUInteger i=0;i<numOfColumnsBuffer;i++) {
            CGFloat columnHeight = heightsBuffer[i];
            CGFloat columnX = i*barChartColumnWidth;
            UIBezierPath* rectanglePath = [UIBezierPath bezierPathWithRect: CGRectMake(columnX, CGRectGetHeight(frame)-columnHeight, barChartColumnWidth, columnHeight)];
            
            NSArray *colorSet = barChartColors ;
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
