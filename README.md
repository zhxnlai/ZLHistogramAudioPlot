ZLHistogramAudioPlot
====================

A hardware-accelerated audio visualization view using EZAudio, inspired by [AudioCopy](https://itunes.apple.com/us/app/audiocopy/id719137307?mt=8).

Preview
---

###Buffer
![preview buffer](Previews/ZLHistogramAudioPlotBuffer.gif)

###Rolling
![preview rolling](Previews/ZLHistogramAudioPlotRolling.gif)


CocoaPods
---
You can install `ZLHistogramAudioPlot` through CocoaPods adding the following to your Podfile:

    pod 'ZLHistogramAudioPlot'

Usage
---
Checkout the [demo app](https://github.com/zhxnlai/ZLHistogramAudioPlot/tree/master/EZAudioRecordExample) for an example.

Customizable attributes:
~~~objective-c
/// The upper bound of the frequency range the audio plot will process. Default: 10000Hz
@property (nonatomic) float maxFrequency;

/// The lower bound of the frequency range the audio plot will process. Default: 1200Hz
@property (nonatomic) float minFrequency;

/// The number of bins in the audio plot. Default: 30
@property (nonatomic) NSUInteger numOfBins;

/// The padding of the bins in percent. Default: 0.1
@property (nonatomic) CGFloat padding;

/// The gain applied to the heights of bins. Default: 10
@property (nonatomic) CGFloat gain;

/// A float that specifies the vertical gravitational acceleration applied to bins in the audio plot. Default: 10 pixel/s^2
@property (nonatomic) float gravity;

/// The color of bins in the audio plot
@property (strong,nonatomic) UIColor *color;

/// An array of color objects defining the color of each bin in the audio plot. If not set, the color attribute will be used instead. Currently not supported by Buffer type.
@property (strong,nonatomic) NSArray *colors;
~~~

Dependencies
---
- ZLHistogramAudioPlot is a subclass of `EZAudioPlot`. It requires [EZAudio](https://github.com/syedhali/EZAudio).
- It also requires [Accelerate](https://developer.apple.com/library/ios/documentation/Accelerate/Reference/AccelerateFWRef/_index.html) framework for hardware acceleration.

Compatibilty
---
`ZLHistogramAudioPlot` uses the following interface provided by [EZAudio](https://github.com/syedhali/EZAudio) to get audio data:
~~~objective-c
- (void)updateBuffer:(float *)buffer withBufferSize:(UInt32)bufferSize;
~~~
It can be easily modified to work with [Audio Unit](https://developer.apple.com/library/mac/documentation/MusicAudio/Conceptual/AudioUnitProgrammingGuide/Introduction/Introduction.html) and [Core Audio](https://developer.apple.com/library/mac/documentation/MusicAudio/Conceptual/CoreAudioOverview/Introduction/Introduction.html).

Requirements
---
- iOS 6 or higher.
- Automatic Reference Counting (ARC).

License
---
ZLHistogramAudioPlot is available under the MIT license. See the LICENSE file for more info.
