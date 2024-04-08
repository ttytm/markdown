/*
V markdown is a wrapper for MD4C: Markdown parser for C (http://github.com/mity/md4c).

Copyright (c) 2016-2019 Martin Mitáš
Copyright (c) 2020 Ned Palacios (V bindings)
Copyright (c) 2020-2024 The V Programming Language

License: MIT
Source: https://github.com/vlang/markdown
*/
module markdown

import strings

struct PlaintextRenderer {
mut:
	writer strings.Builder = strings.new_builder(200)
}

fn (mut pt PlaintextRenderer) str() string {
	return pt.writer.str()
}

fn (mut pt PlaintextRenderer) enter_block(typ BlockKind, detail voidptr) ? {
	// TODO Remove, functions can't have two args with name `_`
	_ = typ
	_ = detail
}

fn (mut pt PlaintextRenderer) leave_block(typ BlockKind, _ voidptr) ? {
	if typ !in [.doc, .hr, .html] {
		pt.writer.write_u8(`\n`)
	}
}

fn (mut pt PlaintextRenderer) enter_span(typ SpanKind, detail voidptr) ? {
	// TODO Remove, functions can't have two args with name `_`
	_ = typ
	_ = detail
}

fn (mut pt PlaintextRenderer) leave_span(typ SpanKind, detail voidptr) ? {
	// TODO Remove, functions can't have two args with name `_`
	_ = typ
	_ = detail
}

fn (mut pt PlaintextRenderer) text(typ TextKind, text string) ? {
	match typ {
		.null_char {}
		.html {}
		.br, .softbr {
			pt.writer.write_u8(`\n`)
		}
		else {
			pt.writer.write_string(text)
		}
	}
}

fn (mut pt PlaintextRenderer) debug_log(msg string) {
	unsafe { msg.free() }
}

pub fn to_plain(input string) string {
	mut pt_renderer := PlaintextRenderer{}
	out := render(input, mut pt_renderer) or { '' }
	return out
}
