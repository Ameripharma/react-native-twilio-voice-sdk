require 'json'

spec = JSON.load(File.read(File.expand_path("./package.json", __dir__)))

Pod::Spec.new do |s|
  s.name         = "RNTwilioVoiceSDK"
  s.version      = spec['version']
  s.summary      = spec['description']
  s.authors      = spec['author']['name']
  s.homepage     = spec['homepage']
  s.license      = spec['license']
  s.platform     = :ios, "8.1"

  s.source_files = [ "ios/RNTwilioVoiceSDK/*.h", "ios/RNTwilioVoiceSDK/*.m"]
  s.source = {:path => "./RNTwilioVoiceSDK"}
  s.resources = 'ios/Assets/*'
  s.dependency 'React'
  s.dependency 'TwilioVoice', '~> 4.1'
end