import { createLowlight } from 'lowlight'
import bash from 'highlight.js/lib/languages/bash'
import css from 'highlight.js/lib/languages/css'
import diff from 'highlight.js/lib/languages/diff'
import dockerfile from 'highlight.js/lib/languages/dockerfile'
import go from 'highlight.js/lib/languages/go'
import javascript from 'highlight.js/lib/languages/javascript'
import json from 'highlight.js/lib/languages/json'
import markdown from 'highlight.js/lib/languages/markdown'
import python from 'highlight.js/lib/languages/python'
import ruby from 'highlight.js/lib/languages/ruby'
import rust from 'highlight.js/lib/languages/rust'
import sql from 'highlight.js/lib/languages/sql'
import typescript from 'highlight.js/lib/languages/typescript'
import xml from 'highlight.js/lib/languages/xml'
import yaml from 'highlight.js/lib/languages/yaml'

/** Syntax highlighting for code blocks: a curated set rather than all ~190 languages. */
export const lowlight = createLowlight({
  bash, css, diff, dockerfile, go, javascript, json, markdown, python, ruby, rust, sql, typescript, xml, yaml,
})
lowlight.registerAlias({ javascript: ['js', 'vue'], typescript: ['ts'], ruby: ['rb', 'erb'], bash: ['sh', 'shell', 'zsh'], xml: ['html'], yaml: ['yml'] })
