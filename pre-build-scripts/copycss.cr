#!/usr/bin/env crystal

# A pre-build script that generates css.js.

css_to_copy = File.read("content/global.css").partition(
  "/* Everything after this point will be copied to css.js - see the copycss.cr pre-build script. */\n")[2]
File.write("js/css.js", "import {css} from 'lit-element';\nexport const styles = css`#{css_to_copy}`;")
