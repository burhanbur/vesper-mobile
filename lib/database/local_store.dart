// Keep native FFI dependencies out of browser compilation.
export 'local_store_native.dart'
    if (dart.library.js_interop) 'local_store_web.dart';
