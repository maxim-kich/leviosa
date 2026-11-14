# Licenses & Acknowledgements

LeviOsa uses the following open-source components, macOS technologies and owner-authored code.

## LeviOsa

LeviOsa’s own source is licensed under [MIT](LICENSE). Third-party components retain their terms and notices below.

The project’s own code and artwork are covered by the main MIT license. See the [provenance record](docs/licenses/provenance.md) for the distinction between project code, third-party dependencies and system components.

## Sparkle — in-app updates

LeviOsa bundles [Sparkle 2.10.1](https://github.com/sparkle-project/Sparkle/tree/2.10.1) and its helper tools for checking, downloading, verifying and installing updates.

Sparkle and its included components retain their copyright and license notices. Read the [complete Sparkle license and third-party notices](docs/licenses/Sparkle-LICENSE.txt). A copy is bundled in the app. About → Licenses opens this page on GitHub.

## macOS technologies

LeviOsa uses Swift and system frameworks including AppKit, Foundation, Carbon, CoreGraphics, QuartzCore and Security. Its raw-input adapter loads macOS’s private MultitouchSupport interface at runtime; it does not bundle that Apple framework.

System fonts and SF Symbols are provided by macOS. Apple system components are not covered by LeviOsa’s MIT grant. Apple’s logo and an SF Symbols font are not bundled.

## Artwork and build tools

The app icon is rendered from the project’s editable [SVG](assets/icon.svg). Build tools include Apple’s developer tools, Python and WebKit for icon export. These tools are not included as separate copies in the installed app. The optional documentation renderer uses markdown-it-py.

Product names and trademarks belong to their owners. These acknowledgements do not imply endorsement or affiliation.
