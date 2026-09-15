# Contributing

Contributions are welcome — issues, bug reports and pull requests alike. It's a small
project, so there's no heavy process.

## Before you open a pull request

Please make sure the test suite passes:

```bash
xcodebuild -project HydroHomie.xcodeproj -scheme HydroHomie \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Match the surrounding code style. New Swift files need the SPDX header that every
other source file carries:

```swift
// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later
```

## Licence grant — please read

HydroHomie is dual licensed: GPL-3.0-or-later for everyone, plus commercial licences
for parties who cannot accept the GPL's terms (see
[COMMERCIAL-LICENSING.md](COMMERCIAL-LICENSING.md)).

That arrangement only holds while a single party can licence the whole codebase. By
default you own the copyright in your own contributions, which would make that
impossible.

**So: by opening a pull request, you agree that your contribution is licensed under
GPL-3.0-or-later, and you grant the project maintainer a perpetual, worldwide,
irrevocable, royalty-free right to relicense your contribution — including under
commercial terms — as part of HydroHomie.**

You keep the copyright in your work. You are granting a licence, not signing it away.
If you're not comfortable with that, please open an issue instead and describe the
change — that costs you nothing and is genuinely useful.
