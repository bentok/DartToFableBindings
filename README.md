A sample command-line application with an entrypoint in `bin/`, library code
in `lib/`, and example unit test in `test/`.
# DartToFableBindings


## Example

From the package dir you want to generate your bindings for:

```
dart run ../../../DartToFableBindings/bin/fsgen.dart \
  --exclude 'dart:async,dart:collection,dart:convert,dart:core,dart:developer,dart:io,dart:isolate,dart:math,dart:typed_data,dart,dart:ffi,dart:html,dart:js,dart:ui,dart:js_util' \
  --show-progress  \
  --no-auto-include-dependencies  \
  --no-validate-links  \
  --no-verbose-warnings  \
  --no-allow-non-local-warnings \
  --no-allow-tools
```