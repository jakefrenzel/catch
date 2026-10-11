# Catch

A native iOS idea-capture app (SwiftUI, iOS 17+). The design spec lives in
[`design_handoff_catch_ios/`](design_handoff_catch_ios/README.md).

## Building (macOS)

The Xcode project is generated from `project.yml` and isn't checked in.

```sh
brew install xcodegen
xcodegen generate
open Catch.xcodeproj
```

Run `xcodegen generate` again after adding or removing files.

Debug runs from Xcode pass `-seedSampleData`, which fills an empty database with
the prototype's demo items and projects. To start over, delete the app from the
simulator.

CI builds and runs the tests on every push to `main` and on pull requests
(`.github/workflows/ci.yml`).
