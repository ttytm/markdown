/*
V wrapper for MD4C: Markdown parser for C (http://github.com/mity/md4c).

Copyright (c) 2016-2019 Martin Mitáš
Copyright (c) 2020 Ned Palacios (V bindings)
Copyright (c) 2020-2024 The V Programming Language

License: MIT
Source: https://github.com/vlang/markdown
*/
module markdown

#flag -I @VMODROOT/src/md4c/src
#flag @VMODROOT/src/md4c/src/md4c.o
#flag @VMODROOT/src/md4c/src/md4c-html.o
#flag @VMODROOT/src/md4c/src/entity.o
#include "md4c.h"
#include "md4c-html.h"

type BlockFn = fn (t BlockKind, d voidptr, u voidptr) int

type SpanFn = fn (t SpanKind, d voidptr, u voidptr) int

type TextFn = fn (t TextKind, tx &char, s u32, u voidptr) int

type DebugFn = fn (m &char, u voidptr)

@[deprecated: 'use BlockKind instead']
pub enum MD_BLOCKTYPE {
	md_block_doc
	md_block_quote
	md_block_ul
	md_block_ol
	md_block_li
	md_block_hr
	md_block_h
	md_block_code
	md_block_html
	md_block_p
	md_block_table
	md_block_thead
	md_block_tbody
	md_block_tr
	md_block_th
	md_block_td
}

pub enum BlockKind {
	doc   = C.MD_BLOCK_DOC
	quote = C.MD_BLOCK_QUOTE
	ul    = C.MD_BLOCK_UL
	ol    = C.MD_BLOCK_OL
	li    = C.MD_BLOCK_LI
	hr    = C.MD_BLOCK_HR
	h     = C.MD_BLOCK_H
	code  = C.MD_BLOCK_CODE
	html  = C.MD_BLOCK_HTML
	p     = C.MD_BLOCK_P
	table = C.MD_BLOCK_TABLE
	thead = C.MD_BLOCK_THEAD
	tbody = C.MD_BLOCK_TBODY
	tr    = C.MD_BLOCK_TR
	th    = C.MD_BLOCK_TH
	td    = C.MD_BLOCK_TD
}

@[deprecated: 'use TextKind instead']
pub enum MD_TEXTTYPE {
	md_text_normal
	md_text_null_char
	md_text_br
	md_text_softbr
	md_text_entity
	md_text_code
	md_text_html
	md_text_latexmath
}

pub enum TextKind {
	normal    = C.MD_TEXT_NORMAL
	null_char = C.MD_TEXT_NULLCHAR
	br        = C.MD_TEXT_BR
	softbr    = C.MD_TEXT_SOFTBR
	entity    = C.MD_TEXT_ENTITY
	code      = C.MD_TEXT_CODE
	html      = C.MD_TEXT_HTML
	latexmath = C.MD_TEXT_LATEXMATH
}

@[deprecated: 'use SpanKind instead']
pub enum MD_SPANTYPE {
	md_span_em
	md_span_strong
	md_span_a
	md_span_img
	md_span_code
	md_span_del
	md_span_latexmath
	md_span_latexmath_display
	md_span_wikilink
	md_span_u
}

pub enum SpanKind {
	em                = C.MD_SPAN_EM
	strong            = C.MD_SPAN_STRONG
	a                 = C.MD_SPAN_A
	img               = C.MD_SPAN_IMG
	code              = C.MD_SPAN_CODE
	del               = C.MD_SPAN_DEL
	latexmath         = C.MD_SPAN_LATEXMATH
	latexmath_display = C.MD_SPAN_LATEXMATH_DISPLAY
	wikilink          = C.MD_SPAN_WIKILINK
	u                 = C.MD_SPAN_U
}

pub enum Flags {
	collapse_whitespace        = C.MD_FLAG_COLLAPSEWHITESPACE // In MD_TEXT_NORMAL, collapse non-trivial whitespace into single ' '
	permissive_atx_headers     = C.MD_FLAG_PERMISSIVEATXHEADERS // Do not require space in ATX headers ( ###header )
	permissive_url_autolinks   = C.MD_FLAG_PERMISSIVEURLAUTOLINKS // Recognize URLs as autolinks even without '<', '>'
	permissive_email_autolinks = C.MD_FLAG_PERMISSIVEEMAILAUTOLINKS // Recognize e-mails as autolinks even without '<', '>' and 'mailto:'
	no_indented_code_blocks    = C.MD_FLAG_NOINDENTEDCODEBLOCKS // Disable indented code blocks. (Only fenced code works.)
	no_html_blocks             = C.MD_FLAG_NOHTMLBLOCKS // Disable raw HTML blocks.
	no_html_spans              = C.MD_FLAG_NOHTMLSPANS // Disable raw HTML (inline).
	tables                     = C.MD_FLAG_TABLES // Enable tables extension.
	strikethrough              = C.MD_FLAG_STRIKETHROUGH // Enable strikethrough extension.
	permissive_wwwa_autolinks  = C.MD_FLAG_PERMISSIVEWWWAUTOLINKS // Enable WWW autolinks (even without any scheme prefix, if they begin with 'www.')
	takslists                  = C.MD_FLAG_TASKLISTS // Enable task list extension.
	latex_math                 = C.MD_FLAG_LATEXMATHSPANS // Enable $ and $$ containing LaTeX equations.
	wikilinks                  = C.MD_FLAG_WIKILINKS // Enable wiki links extension.
	underline                  = C.MD_FLAG_UNDERLINE // Enable underline extension (and disables '_' for normal emphasis).
	hard_soft_breaks           = C.MD_FLAG_HARD_SOFT_BREAKS // Force all soft breaks to act as hard breaks.
	permissive_autolinks       = C.MD_FLAG_PERMISSIVEAUTOLINKS
	no_html                    = C.MD_FLAG_NOHTML
	/* Convenient sets of flags corresponding to well-known Markdown dialects.
 *
 * Note we may only support subset of features of the referred dialect.
 * The constant just enables those extensions which bring us as close as
 * possible given what features we implement.
 *
 * ABI compatibility note: Meaning of these can change in time as new
 * extensions, bringing the dialect closer to the original, are implemented.
 */
	dialect_commonmark         = C.MD_DIALECT_COMMONMARK
	dialect_github             = C.MD_DIALECT_GITHUB
}

@[deprecated: 'use Align instead']
pub enum MD_ALIGN {
	md_align_default = 0
	md_align_left
	md_align_center
	md_align_right
}

pub enum Align {
	default = C.MD_ALIGN_DEFAULT
	left    = C.MD_ALIGN_LEFT
	center  = C.MD_ALIGN_CENTER
	right   = C.MD_ALIGN_RIGHT
}

@[typedef]
pub struct C.MD_PARSER {
pub:
	abi_version u32
	flags       u32
	enter_block BlockFn
	leave_block BlockFn
	enter_span  SpanFn
	leave_span  SpanFn
	text        TextFn
	debug_log   DebugFn
}

@[typedef]
pub struct C.MD_ATTRIBUTE {
pub:
	text           &char
	size           u32
	substr_types   &TextKind
	substr_offsets &u32
}

@[typedef]
pub struct C.MD_BLOCK_UL_DETAIL {
pub:
	is_tight int
	mark     u8
}

@[typedef]
pub struct C.MD_BLOCK_OL_DETAIL {
pub:
	start          u32
	is_tight       int
	mark_delimiter u8
}

@[typedef]
pub struct C.MD_BLOCK_LI_DETAIL {
pub:
	is_task          bool
	task_mark        u8
	task_mark_offset u32
}

@[typedef]
pub struct C.MD_BLOCK_H_DETAIL {
pub:
	level u32
}

@[typedef]
pub struct C.MD_BLOCK_CODE_DETAIL {
pub:
	info       C.MD_ATTRIBUTE
	lang       C.MD_ATTRIBUTE
	fence_char u8
}

@[typedef]
pub struct C.MD_BLOCK_TD_DETAIL {
pub:
	align MD_ALIGN
}

@[typedef]
pub struct C.MD_SPAN_A_DETAIL {
pub:
	href  C.MD_ATTRIBUTE
	title C.MD_ATTRIBUTE
}

@[typedef]
pub struct C.MD_SPAN_IMG_DETAIL {
pub:
	src   C.MD_ATTRIBUTE
	title C.MD_ATTRIBUTE
}

@[typedef]
pub struct C.MD_SPAN_WIKILINK_DETAIL {
pub:
	target C.MD_ATTRIBUTE
}

fn C.md_parse(text &char, size u32, parser &C.MD_PARSER, userdata voidptr) int

fn parse(text &char, size u32, parser &C.MD_PARSER, userdata voidptr) int {
	return C.md_parse(text, size, parser, userdata)
}
