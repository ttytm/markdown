/*
V wrapper for MD4C: Markdown parser for C (http://github.com/mity/md4c).

Copyright (c) 2016-2019 Martin Mitáš
Copyright (c) 2020 Ned Palacios (V bindings)
Copyright (c) 2020-2024 The V Programming Language

License: MIT
Source: https://github.com/vlang/markdown
*/
module markdown

import encoding.html
import strings
import datatypes { Stack }

pub type ParentType = BlockKind | SpanKind

// HtmlTransformer transforms converted HTML elements (limited
// to attribute and content for now) from markdown before incorporated
// into the final output.
//
// When implementing an HtmlTransformer, escaping the content is up
// to you. However, it is best to wrap the values you don't need with
// `markdown.default_html_transformer.transform_{attribute|content}`
pub interface HtmlTransformer {
	transform_attribute(parent ParentType, name string, value string) string
	transform_content(parent ParentType, text string) string
mut:
	config_set(key string, value string)
}

pub struct DefaultHtmlTransformer {}

pub fn (t &DefaultHtmlTransformer) transform_attribute(parent ParentType, name string, value string) string {
	return html.escape(value)
}

pub fn (t &DefaultHtmlTransformer) transform_content(parent ParentType, text string) string {
	return html.escape(text, quote: false)
}

pub fn (mut t DefaultHtmlTransformer) config_set(key string, val string) {}

pub const default_html_transformer = &DefaultHtmlTransformer{}

pub type AttrTransformerFn = fn (ParentType, string, string) string

pub fn (t AttrTransformerFn) transform_attribute(parent ParentType, name string, value string) string {
	val := t(parent, name, value)
	return val
}

pub fn (t AttrTransformerFn) transform_content(parent ParentType, text string) string {
	return markdown.default_html_transformer.transform_content(parent, text)
}

pub fn (mut t AttrTransformerFn) config_set(key string, val string) {}

pub type ContentTransformerFn = fn (ParentType, string) string

pub fn (t ContentTransformerFn) transform_attribute(parent ParentType, name string, value string) string {
	return markdown.default_html_transformer.transform_attribute(parent, name, value)
}

pub fn (t ContentTransformerFn) transform_content(parent ParentType, text string) string {
	return t(parent, text)
}

pub fn (mut t ContentTransformerFn) config_set(key string, val string) {}

const ignored_blocks = [BlockKind.doc, .html]

fn tos_attribute(attr &C.MD_ATTRIBUTE, mut wr strings.Builder) {
	for i := 0; unsafe { attr.substr_offsets[i] } < attr.size; i++ {
		typ := unsafe { MD_TEXTTYPE(attr.substr_types[i]) }
		off := unsafe { attr.substr_offsets[i] }
		size := unsafe { attr.substr_offsets[i + 1] - off }
		text := unsafe { (attr.text + off).vstring_with_len(size) }

		match typ {
			.md_text_null_char {
				wr.write_string(html.unescape('&#0'))
			}
			.md_text_entity {
				if text == '&lt;' || text == '&gt;' {
					wr.write_string(text)
				} else {
					wr.write_string(html.unescape(text, all: true))
				}
			}
			else {
				wr.write_string(html.escape(text))
			}
		}
	}
}

pub struct HtmlRenderer {
pub mut:
	transformer HtmlTransformer = markdown.default_html_transformer
mut:
	parent_stack        Stack[ParentType]
	content_writer      strings.Builder = strings.new_builder(200)
	writer              strings.Builder = strings.new_builder(200)
	image_nesting_level int
}

fn (mut ht HtmlRenderer) str() string {
	return ht.writer.str()
}

fn (mut ht HtmlRenderer) render_opening_attribute(key string, with_str_opening bool) {
	ht.writer.write_byte(` `)
	ht.writer.write_string(key)
	if with_str_opening {
		ht.writer.write_string('="')
	}
}

fn (mut ht HtmlRenderer) render_closing_attribute() {
	ht.writer.write_byte(`"`)
}

@[params]
struct MdAttributeConfig {
	prefix      string
	suffix      string
	setting_key string
}

fn (mut ht HtmlRenderer) render_md_attribute(key string, attr &C.MD_ATTRIBUTE, cfg MdAttributeConfig) {
	if attr == 0 || attr.text == 0 {
		return
	}
	ht.content_writer.write_string(cfg.prefix)
	tos_attribute(attr, mut ht.content_writer)
	ht.content_writer.write_string(cfg.suffix)
	transformed := if parent := ht.parent_stack.peek() {
		ht.transformer.transform_attribute(parent, key, ht.content_writer.str())
	} else {
		html.escape(ht.content_writer.str())
	}
	if cfg.setting_key.len != 0 {
		tos_attribute(attr, mut ht.content_writer)
		ht.transformer.config_set(cfg.setting_key, ht.content_writer.str())
	}
	ht.render_opening_attribute(key, true)
	ht.writer.write_string(transformed)
	ht.render_closing_attribute()
}

fn (mut ht HtmlRenderer) render_attribute(key string, value string) {
	ht.render_opening_attribute(key, value.len != 0)
	if value.len != 0 {
		transformed := if parent := ht.parent_stack.peek() {
			ht.transformer.transform_attribute(parent, key, value)
		} else {
			value
		}

		ht.writer.write_string(transformed)
		ht.render_closing_attribute()
	}
}

fn (mut ht HtmlRenderer) render_content() {
	if ht.content_writer.len == 0 {
		return
	}

	if parent := ht.parent_stack.peek() {
		transformed := ht.transformer.transform_content(parent, ht.content_writer.str())
		ht.writer.write_string(transformed)
	} else {
		ht.writer.write_string(ht.content_writer.str())
	}
}

fn (mut ht HtmlRenderer) enter_block(typ BlockKind, detail voidptr) ? {
	ht.parent_stack.push(ParentType(typ))
	if typ !in markdown.ignored_blocks {
		ht.writer.write_byte(`<`)
		tag_name := match typ {
			.code { 'pre' }
			.quote { 'blockquote' }
			else { typ.str() }
		}
		ht.writer.write_string(tag_name)
	}
	match typ {
		.h {
			level := unsafe { &C.MD_BLOCK_H_DETAIL(detail) }.level
			ht.writer.write_string('${level}')
		}
		.ol {
			details := unsafe { &C.MD_BLOCK_OL_DETAIL(detail) }
			if details.start > 1 {
				ht.render_attribute('start', '${details.start}')
			}
		}
		.li {
			details := unsafe { &C.MD_BLOCK_LI_DETAIL(detail) }
			if details.is_task {
				ht.render_attribute('class', 'task-list-item')
			}
		}
		.th, .td {
			details := unsafe { &C.MD_BLOCK_TD_DETAIL(detail) }
			align := match details.align {
				.md_align_left { 'left' }
				.md_align_center { 'center' }
				.md_align_right { 'right' }
				else { '' }
			}
			if align.len != 0 {
				ht.render_attribute('align', align)
			}
		}
		else {}
	}
	if typ !in markdown.ignored_blocks {
		if typ == .hr {
			ht.writer.write_byte(` `)
			ht.writer.write_byte(`/`)
		}
		ht.writer.write_byte(`>`)
	}

	// Extra HTML for li/code items
	if typ == .code {
		details := unsafe { &C.MD_BLOCK_CODE_DETAIL(detail) }
		ht.writer.write_string('<code')
		ht.render_md_attribute('class', details.lang,
			prefix: 'language-'
			setting_key: 'code_language'
		)
		ht.writer.write_byte(`>`)
	} else if typ == .li {
		details := unsafe { &C.MD_BLOCK_LI_DETAIL(detail) }
		if !details.is_task {
			return
		}
		ht.writer.write_string('<input')
		ht.render_attribute('type', 'checkbox')
		ht.render_attribute('class', 'task-list-item-checkbox')
		ht.render_attribute('disabled', '')
		if details.task_mark == `x` || details.task_mark == `X` {
			ht.render_attribute('checked', '')
		}
		ht.writer.write_byte(`>`)
	}
}

fn (mut ht HtmlRenderer) leave_block(typ BlockKind, detail voidptr) ? {
	ht.render_content()
	ht.parent_stack.pop() or {}
	if typ == .hr {
		return
	}
	if typ == .code {
		ht.writer.write_string('</code>')
	}
	if typ !in markdown.ignored_blocks {
		ht.writer.write_byte(`<`)
		ht.writer.write_byte(`/`)
		tag_name := match typ {
			.code { 'pre' }
			.quote { 'blockquote' }
			else { typ.str() }
		}
		ht.writer.write_string(tag_name)
		defer {
			ht.writer.write_byte(`>`)
		}
	}
	if typ == .h {
		level := unsafe { &C.MD_BLOCK_H_DETAIL(detail) }.level
		ht.writer.write_string('${level}')
	}
}

fn (mut ht HtmlRenderer) enter_span(typ SpanKind, detail voidptr) ? {
	if ht.image_nesting_level > 0 {
		return
	}
	ht.parent_stack.push(ParentType(typ))
	ht.writer.write_byte(`<`)
	ht.writer.write_string(typ.str())
	match typ {
		.a {
			a_details := unsafe { &C.MD_SPAN_A_DETAIL(detail) }
			ht.render_md_attribute('href', a_details.href)
			ht.render_md_attribute('title', a_details.title)
		}
		.img {
			img_details := unsafe { &C.MD_SPAN_IMG_DETAIL(detail) }
			ht.render_md_attribute('src', img_details.src)
			ht.render_opening_attribute('alt', true)
			ht.image_nesting_level++
			return
		}
		.latexmath_display {
			ht.render_attribute('type', 'display')
		}
		.wikilink {
			wikilink_details := unsafe { &C.MD_SPAN_WIKILINK_DETAIL(detail) }
			ht.render_md_attribute('data-target', wikilink_details.target)
		}
		else {}
	}
	ht.writer.write_byte(`>`)
}

fn (mut ht HtmlRenderer) leave_span(typ SpanKind, detail voidptr) ? {
	if ht.image_nesting_level > 0 {
		if ht.image_nesting_level == 1 && typ == .img {
			ht.render_closing_attribute()
			img_details := unsafe { &C.MD_SPAN_IMG_DETAIL(detail) }
			ht.render_md_attribute('title', img_details.title)
			ht.writer.write_string(' />')
			ht.image_nesting_level--
			ht.parent_stack.pop() or {}
		}
		return
	}
	ht.render_content()
	ht.parent_stack.pop() or {}
	ht.writer.write_byte(`<`)
	ht.writer.write_byte(`/`)
	ht.writer.write_string(typ.str())
	ht.writer.write_byte(`>`)
}

fn (mut ht HtmlRenderer) text(typ TextKind, text string) ? {
	match typ {
		.null_char {
			ht.writer.write_string('&#0')
		}
		.softbr {
			if ht.image_nesting_level > 0 {
				ht.writer.write_byte(` `)
			}
		}
		.br {
			ht.writer.write_string('<br />')
		}
		.entity {
			ht.writer.write_string(html.unescape(text, all: true))
		}
		.html {
			ht.writer.write_string(text)
		}
		else {
			if ht.image_nesting_level == 0 {
				if parent := ht.parent_stack.peek() {
					// Special code for code blocks
					if parent is BlockKind && parent == .code {
						ht.content_writer.write_string(text)
						return
					}
				}
			}
			ht.writer.write_string(html.escape(text, quote: false))
		}
	}
}

fn (mut ht HtmlRenderer) debug_log(msg string) {
	unsafe { msg.free() }
}

pub fn to_html_experimental(input string) string {
	mut renderer := HtmlRenderer{}
	out := render(input, mut renderer) or { '' }
	return out
}
