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

  s.script_phase = {
    :name => 'Build Rust library',
    # First argument is relative path to the `rust` folder, second is name of rust library
    :script => 'sh "$PODS_TARGET_SRCROOT/../cargokit/build_pod.sh" ../../rust rust_lib_app',
    :execution_position => :before_compile,
    :input_files => ['${BUILT_PRODUCTS_DIR}/cargokit_phony'],
    # Let XCode know that the static library referenced in -force_load below is
    # created by this build step.
    :output_files => ["${BUILT_PRODUCTS_DIR}/librust_lib_app.a"],
  }
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # Flutter.framework does not contain a i386 slice.
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
<<<<<<< HEAD
    'OTHER_LDFLAGS' => '-Wl,-u,frb_pde_ffi_dispatcher_primary -Wl,-u,frb_pde_ffi_dispatcher_sync -Wl,-u,frb_dart_fn_deliver_output -Wl,-u,frb_get_rust_content_hash -Wl,-u,frb_init_frb_dart_api_dl -Wl,-u,frb_free_wire_sync_rust2dart_dco -Wl,-u,frb_free_wire_sync_rust2dart_sse -Wl,-u,frb_create_shutdown_callback -Wl,-u,frb_rust_vec_u8_new -Wl,-u,frb_rust_vec_u8_resize -Wl,-u,frb_rust_vec_u8_free -Wl,-u,frb_dart_opaque_dart2rust_encode -Wl,-u,frb_dart_opaque_rust2dart_decode -Wl,-u,frb_dart_opaque_drop_thread_box_persistent_handle -Wl,-u,store_dart_post_cobject',
=======
    'OTHER_LDFLAGS' => '-Wl,-u,_frb_pde_ffi_dispatcher_primary -Wl,-u,_frb_pde_ffi_dispatcher_sync -Wl,-u,_frb_dart_fn_deliver_output -Wl,-u,_frb_get_rust_content_hash -Wl,-u,_frb_init_frb_dart_api_dl -Wl,-u,_frb_free_wire_sync_rust2dart_dco -Wl,-u,_frb_free_wire_sync_rust2dart_sse -Wl,-u,_frb_create_shutdown_callback -Wl,-u,_frb_rust_vec_u8_new -Wl,-u,_frb_rust_vec_u8_resize -Wl,-u,_frb_rust_vec_u8_free -Wl,-u,_frb_dart_opaque_dart2rust_encode -Wl,-u,_frb_dart_opaque_rust2dart_decode -Wl,-u,_frb_dart_opaque_drop_thread_box_persistent_handle -Wl,-u,_store_dart_post_cobject',
>>>>>>> 30e5baa (fix: replace -force_load with -Wl,-u,_<symbol> flags for FRB symbols)
  }
end