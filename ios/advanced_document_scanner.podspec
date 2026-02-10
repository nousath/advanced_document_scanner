Pod::Spec.new do |s|
  s.name             = 'advanced_document_scanner'
  s.version          = '0.0.1'
  s.summary          = 'Camera-based document scanner with editor and export presets.'
  s.description      = <<-DESC
Camera-based document scanner for Flutter with a built-in editor (highlight, crop/cut, rotate) and export options (JPG/PNG/GIF + presets).
DESC
  s.homepage         = 'https://github.com/nousath/advanced_document_scanner'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'NH97' => 'contact@nh97.co.in' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  // VisionKit document scanner requires iOS 13+
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'
end
