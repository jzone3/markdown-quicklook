# Third-Party Licenses

**markdown-quicklook** is licensed under the MIT License (see [`LICENSE`](LICENSE)).
It builds on the following third-party components. Each is used in compliance with
its license. None of the GPL-licensed projects listed under "Studied, not used"
contributed any code to this repository.

---

## Bundled / vendored assets (redistributed in this repo)

These files are committed under
`Sources/MarkdownRenderer/Resources/` and shipped inside the app.

### github-markdown-css — MIT
- Source: https://github.com/sindresorhus/github-markdown-css
- Version: 5.5.1
- File: `github-markdown.css`
- License: MIT, Copyright (c) Sindre Sorhus

### highlight.js — BSD-3-Clause
- Source: https://github.com/highlightjs/highlight.js
- Version: 11.9.0
- Files: `highlight.min.js`, `highlight-github.css` (GitHub light theme),
  `highlight-github-dark.css` (GitHub dark theme)
- License: BSD-3-Clause, Copyright (c) 2006, Ivan Sagalaev

```
Copyright (c) 2006, Ivan Sagalaev. All rights reserved.
Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright notice, this
  list of conditions and the following disclaimer in the documentation and/or
  other materials provided with the distribution.
* Neither the name of the copyright holder nor the names of its contributors may
  be used to endorse or promote products derived from this software without
  specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
```

---

## Swift package dependencies (fetched at build time, not vendored)

### swift-markdown — Apache-2.0
- Source: https://github.com/swiftlang/swift-markdown
- Version: 0.8.0
- License: Apache License 2.0, © Apple Inc. and the Swift project authors
- Used unmodified as a SwiftPM dependency (Markdown parsing).

### swift-cmark (cmark-gfm) — transitive dependency of swift-markdown
- Source: https://github.com/swiftlang/swift-cmark
- Version: 0.8.0
- License: BSD-2-Clause (cmark) with additional permissive notices; see the
  upstream repository. Pulled in transitively by swift-markdown.

---

## Studied, NOT used (no code copied)

### QLMarkdown — GPL-3.0
- Source: https://github.com/sbarex/QLMarkdown
- Reviewed for architecture/approach only. Because it is GPL-3.0, **no code was
  copied** so this project can remain MIT-licensed.

---

## Build tooling (not distributed with the app)

### XcodeGen — MIT
- Source: https://github.com/yonaskolb/XcodeGen
- Used to generate `MarkdownQuickLook.xcodeproj` from `project.yml`. Not part of
  the shipped product.
