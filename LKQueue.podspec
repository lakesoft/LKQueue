Pod::Spec.new do |s|
  s.name         = "LKQueue"
  s.version      = "1.1.1"
  s.summary      = "Queue library"
  s.description  = <<-DESC
Queue library.
                   DESC
  s.homepage     = "https://github.com/lakesoft/LKQueue"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { "Hiroshi Hashiguchi" => "xcatsan@mac.com" }
  s.source       = { :git => "https://github.com/lakesoft/LKQueue.git", :tag => s.version.to_s }

  s.platform     = :ios, '7.0'
  s.requires_arc = true

  s.source_files = 'Classes/*'

 end

