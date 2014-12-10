Pod::Spec.new do |s|
  s.name         = "ZLHistogramAudioPlot"
  s.version      = "0.0.1"
  s.summary      = "A hardware-accelerated audio visualization view using EZAudio, inspired by AudioCopy."
  s.description  = <<-DESC
  A hardware-accelerated audio visualization view using EZAudio, inspired by [AudioCopy](https://itunes.apple.com/us/app/audiocopy/id719137307?mt=8).
    DESC
  s.homepage     = "https://github.com/zhxnlai/ZLHistogramAudioPlot"
  s.screenshots  = "https://raw.githubusercontent.com/zhxnlai/ZLHistogramAudioPlot/master/Previews/ZLHistogramAudioPlotBuffer.gif"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "Zhixuan Lai" => "zhxnlai@gmail.com" }
  s.platform     = :ios, "6.0"
  s.source       = { :git => "https://github.com/zhxnlai/ZLHistogramAudioPlot.git", :tag => "0.0.1" }
  s.source_files = "ZLHistogramAudioPlot/*.{h,m}"
  s.frameworks   = "UIKit", "Accelerate"
  s.requires_arc = true
  s.dependency "EZAudio"
end
