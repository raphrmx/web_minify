## 1.0.0

- Initial release.
- `minify` minifies a whole file: an HTML page goes through in one piece, inline `<style>` and
  `<script>` blocks included.
- `minifyHtml`, `minifyCss` and `minifyJs` name a language outright.
- `HtmlMinifier`, `CssMinifier` and `JsMinifier` carry the options.
- `detectMinifyLanguage` works the language out from a path or from the content.
- `web_minify` command line front end.
