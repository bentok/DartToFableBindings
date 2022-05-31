A sample command-line application with an entrypoint in `bin/`, library code
in `lib/`, and example unit test in `test/`.
# DartToFableBindings


## Example

From the package dir you want to generate your bindings for:

```
dart run ../../../DartToFableBindings/bin/fsgen.dart \
  --exclude 'dart:async,dart:collection,dart:convert,dart:core,dart:developer,dart:io,dart:isolate,dart:math,dart:typed_data,dart,dart:ffi,dart:html,dart:js,dart:js_util' \
  --show-progress  \
#  --no-auto-include-dependencies  \
  --no-validate-links  \
  --no-verbose-warnings  \
  --no-allow-non-local-warnings \
  --no-allow-tools
```

> In the case of Flutter repo, dartdoc won't work directly. We need to create an empty project that just references it and get flutter from the packageGraph. See https://github.com/fable-compiler/Fable/issues/2878#issuecomment-1140763710