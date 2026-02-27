# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.4](https://github.com/dungle-scrubs/nimoy/compare/v0.1.3...v0.1.4) (2026-02-27)


### Maintenance

* **ci:** remove macOS-only jobs and heavy release build ([#10](https://github.com/dungle-scrubs/nimoy/issues/10)) ([e8096de](https://github.com/dungle-scrubs/nimoy/commit/e8096de45ce6f1d2a18841c9e5f55d5237f5e432))

## [0.1.3](https://github.com/dungle-scrubs/nimoy/compare/v0.1.2...v0.1.3) (2026-02-24)


### Fixed

* **ci:** use macos-15 runners for Swift 5.12 compatibility ([#6](https://github.com/dungle-scrubs/nimoy/issues/6)) ([55f505c](https://github.com/dungle-scrubs/nimoy/commit/55f505ccb3cf3fd87faf5499175447fe4b3866b2))

## [0.1.2](https://github.com/dungle-scrubs/nimoy/compare/v0.1.1...v0.1.2) (2026-02-24)


### Added

* add Homebrew cask release workflow and install docs ([#4](https://github.com/dungle-scrubs/nimoy/issues/4)) ([4bd14b1](https://github.com/dungle-scrubs/nimoy/commit/4bd14b1a8a96169598665a114348bb8a37d24c64))


### Maintenance

* **deps:** bump actions/checkout from 4 to 6 ([#3](https://github.com/dungle-scrubs/nimoy/issues/3)) ([4a4e30b](https://github.com/dungle-scrubs/nimoy/commit/4a4e30b48fde4eafd953d8ad3c2945f116e71bc6))
* **deps:** bump github/codeql-action from 3 to 4 ([#2](https://github.com/dungle-scrubs/nimoy/issues/2)) ([64d048b](https://github.com/dungle-scrubs/nimoy/commit/64d048b97843e4818c6ea49f70aa7d754e3cf865))

## [0.1.1](https://github.com/dungle-scrubs/nimoy/compare/v0.1.0...v0.1.1) (2026-02-19)


### Added

* Add ⌘G document generation overlay ([2451a2a](https://github.com/dungle-scrubs/nimoy/commit/2451a2a2ab414eb6ba2e81d227102539900a0749))
* Add animated loading dots and warning icon for missing values ([ffdead8](https://github.com/dungle-scrubs/nimoy/commit/ffdead838258d1ea04ca7ccc12671757ab49e53b))
* Add comprehensive logging and error handling to MLXProvider ([75afba0](https://github.com/dungle-scrubs/nimoy/commit/75afba0646e3cd449a9f6a044a03c5d4a63e5d90))
* Add Excel export with formulas ([50299da](https://github.com/dungle-scrubs/nimoy/commit/50299daefabed4994c27da77df6da96523e49a04))
* Add Groq API service for LLM completions ([40cc93c](https://github.com/dungle-scrubs/nimoy/commit/40cc93c3a7d7b9624665f5c09aa6837d1f62f235))
* Add isAggregate flag to EvaluationResult ([f379c66](https://github.com/dungle-scrubs/nimoy/commit/f379c66a83988942fc4998012174dace71fa4cf2))
* Add LLM prompt templates for Nimoy syntax ([d66eeae](https://github.com/dungle-scrubs/nimoy/commit/d66eeae73c1bea3307a58707ad2491aabf8325f0))
* Add LLM provider selection to Action Palette ([f2aef28](https://github.com/dungle-scrubs/nimoy/commit/f2aef28f959e87715da968a401de487b56e7c927))
* Add logging to LLMManager for provider routing ([7c91691](https://github.com/dungle-scrubs/nimoy/commit/7c916917c75c3f3c5eeb92ba32b32c4cdc8dad1c))
* Add native MLX provider and smart crypto formatting ([c4a6042](https://github.com/dungle-scrubs/nimoy/commit/c4a60428888ea95b1cac6eca3a48a6f18309e9a9))
* Add optional LLM provider with local model support ([c9891f8](https://github.com/dungle-scrubs/nimoy/commit/c9891f8417f30adee6bd3fe0691683a10f36fad4))
* AI-powered suggestions for missing values ([fd5d1cc](https://github.com/dungle-scrubs/nimoy/commit/fd5d1cc58de15fdc72f0a5a84fccd14c36543c67))
* Expand crypto support to top 50 tokens by market cap ([ad889a9](https://github.com/dungle-scrubs/nimoy/commit/ad889a94fdab8563df8dc2af47089ef781bc0a2e))
* Remember last opened page on app restart ([3310e52](https://github.com/dungle-scrubs/nimoy/commit/3310e52c73e3e9ae6c665328cfb1ff7d8a01e558))
* Synchronized scrolling with ghost text autocomplete ([4682dd7](https://github.com/dungle-scrubs/nimoy/commit/4682dd7629a67686386ada9be7ec8f027843f9c5))
* **syntax:** support thousands separators in number highlighting ([2f53702](https://github.com/dungle-scrubs/nimoy/commit/2f53702c851dae0abc160283da59bf18bb1bbdd8))
* **ui:** add collapsible sidebar with animated drawer ([2b36b07](https://github.com/dungle-scrubs/nimoy/commit/2b36b07dad225813ace9e1a26a33d3a30be87e28))
* **ui:** add responsive floating sidebar for narrow windows ([875949b](https://github.com/dungle-scrubs/nimoy/commit/875949b66323fc61b283b75c5af71f9c4eef4861))
* **ui:** add sidebar view for page navigation ([7a9cb5d](https://github.com/dungle-scrubs/nimoy/commit/7a9cb5dee781d26a3d840d0c13f20551f32876b6))


### Fixed

* Add crypto currency support for sum/average conversions ([aacd12a](https://github.com/dungle-scrubs/nimoy/commit/aacd12a0489d19e338ea488283afb9631c9d30ef))
* Add fallback crypto prices and reduce API rate ([b094202](https://github.com/dungle-scrubs/nimoy/commit/b094202f92c0be35f414c364fd55873c71eb7dfd))
* Disable app sandbox for MLX shell command support ([4e7ed05](https://github.com/dungle-scrubs/nimoy/commit/4e7ed05a20da6f2032c61826106c22cc147cf35d))
* Excel export - don't overwrite variable references ([f82c0f1](https://github.com/dungle-scrubs/nimoy/commit/f82c0f1c22b2d574e6e3b54f86348ab31344c822))
* harden evaluator state, page persistence, and MLX process IO ([de1cc86](https://github.com/dungle-scrubs/nimoy/commit/de1cc860962464a0bf5345de443b115375bd6a00))
* Improve Excel export with proper column structure ([d8e9cfd](https://github.com/dungle-scrubs/nimoy/commit/d8e9cfdaf709c25d0fa07b8967eceb124a6afda3))
* Improve pre-commit build check to catch type errors ([d134779](https://github.com/dungle-scrubs/nimoy/commit/d13477976cfd6621a46a5935790329c268980995))
* Reduce window corner radius and fix resize alignment ([143b297](https://github.com/dungle-scrubs/nimoy/commit/143b2973f45e72de9c5280b9f249c3e4c332851a))
* Restore toolbar icons by removing problematic window style changes ([cb9fc48](https://github.com/dungle-scrubs/nimoy/commit/cb9fc4828d25d74dd8f53d0c3432b071f3467a1e))
* Simplify SyntaxHighlighter paragraph style ([cf0aa6a](https://github.com/dungle-scrubs/nimoy/commit/cf0aa6a60f0b7b5d7420cea6d2b38fdbd08a3851))
* Simplify warning icon - remove AI suggestion feature ([4106ed5](https://github.com/dungle-scrubs/nimoy/commit/4106ed583b0922db90a876804affad5b746bed0b))
* **ui:** enable sidebar item interactivity ([4592d58](https://github.com/dungle-scrubs/nimoy/commit/4592d5875d573c12ddd56745124417bf80ba4b00))


### Changed

* **window:** migrate to AppKit for transparent titlebar control ([41c88d1](https://github.com/dungle-scrubs/nimoy/commit/41c88d1370e6918f86b62de08bc2ad1a6fa4df02))


### Maintenance

* Add .generated-images to gitignore ([92f47b0](https://github.com/dungle-scrubs/nimoy/commit/92f47b0bd298af20ad0ef211ae15ce4de0db1111))
* Add app icon assets ([fb2411c](https://github.com/dungle-scrubs/nimoy/commit/fb2411cca04bff826bfe91a3f4eb7b505b53c500))
* Add MLXProviderTests ([bba3e69](https://github.com/dungle-scrubs/nimoy/commit/bba3e69bf35cee7031c8c1ebd4b0298ddc12fdff))
* Add pre-commit hooks for linting and formatting ([4129b26](https://github.com/dungle-scrubs/nimoy/commit/4129b269a7d4da7a20b8010253d242d7d4b00367))
* add public-release docs, templates, and automation ([27adfb4](https://github.com/dungle-scrubs/nimoy/commit/27adfb47bbe808799d449b18e283c5be3fdee45a))
* Add Swift version file ([1fdbc28](https://github.com/dungle-scrubs/nimoy/commit/1fdbc28fcff2b9992d2a2efe7e02e5e3ff93c69a))
* **ci:** add CodeQL workflow for Swift ([06b3ab1](https://github.com/dungle-scrubs/nimoy/commit/06b3ab16a4878816ac5be8105845301712bc7cc6))
* **ci:** switch secret scan from gitleaks to trufflehog ([464ad39](https://github.com/dungle-scrubs/nimoy/commit/464ad39e5a00dee2a30765280719c0b64788c29d))
* Fix EvaluatorTests for 4-param EvaluationResult ([2938eca](https://github.com/dungle-scrubs/nimoy/commit/2938ecab4d217bdaf18d8069d772d729f11f7676))
* **hooks:** add trufflehog pre-push secret scan ([e5c1f05](https://github.com/dungle-scrubs/nimoy/commit/e5c1f05902082b57b476ac6dbd58c611a9a1f3de))
* Update Xcode project with new files ([11d5c80](https://github.com/dungle-scrubs/nimoy/commit/11d5c80c152646dfaf37b90b98c4a8ea5a37bb79))

## 0.1.0 - 2026-02-19

### Added

- Initial public release baseline.
