#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint rust_lib_app.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'rust_lib_app'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter FFI plugin project.'
  s.description      = <<-DESC
A new Flutter FFI plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  # This will ensure the source files in Classes/ are included in the native
  # builds of apps using this FFI plugin. Podspec does not support relative
  # paths, so Classes contains a forwarder C file that relatively imports
  # `../src/*` so that the C sources can be shared among all target platforms.
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'

  s.script_phases = [
    {
      :name => 'Build Rust library',
      :script => 'sh "$PODS_TARGET_SRCROOT/../cargokit/build_pod.sh" ../../rust rust_lib_app',
      :execution_position => :before_compile,
      :input_files => ['${BUILT_PRODUCTS_DIR}/cargokit_phony'],
      :output_files => ["${PODS_CONFIGURATION_BUILD_DIR}/${PRODUCT_NAME}/librust_lib_app.a"],
    },
    {
      :name => 'Embed Rust library into framework',
      :script => 'cp "${PODS_CONFIGURATION_BUILD_DIR}/${PRODUCT_NAME}/librust_lib_app.a" "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_PATH}"',
      :execution_position => :after_compile,
      :input_files => ["${PODS_CONFIGURATION_BUILD_DIR}/${PRODUCT_NAME}/librust_lib_app.a"],
    },
  ]
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # Flutter.framework does not contain a i386 slice.
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }
end