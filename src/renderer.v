/*
V wrapper for MD4C: Markdown parser for C (http://github.com/mity/md4c).

Copyright (c) 2016-2019 Martin Mitáš
Copyright (c) 2020 Ned Palacios (V bindings)
Copyright (c) 2020-2024 The V Programming Language

License: MIT
Source: https://github.com/vlang/markdown
*/
module markdown

// Renderer represents an entity that accepts incoming data and renders the content.
pub interface Renderer {
mut:
	str() string
	enter_block(typ BlockKind, detail voidptr) ?
	leave_block(typ BlockKind, detail voidptr) ?
	enter_span(typ SpanKind, detail voidptr) ?
	leave_span(typ SpanKind, detail voidptr) ?
	text(typ TextKind, content string) ?
	debug_log(msg string)
}

fn renderer_handle_error(err IError) int {
	if err.code() != 0 {
		return err.code()
	} else {
		return 1
	}
}

fn renderer_enter_block_cb(typ BlockKind, detail voidptr, mut renderer Renderer) int {
	renderer.enter_block(typ, detail) or { return renderer_handle_error(err) }
	return 0
}

fn renderer_leave_block_cb(typ BlockKind, detail voidptr, mut renderer Renderer) int {
	renderer.leave_block(typ, detail) or { return renderer_handle_error(err) }
	return 0
}

fn renderer_enter_span_cb(typ SpanKind, detail voidptr, mut renderer Renderer) int {
	renderer.enter_span(typ, detail) or { return renderer_handle_error(err) }
	return 0
}

fn renderer_leave_span_cb(typ SpanKind, detail voidptr, mut renderer Renderer) int {
	renderer.leave_span(typ, detail) or { return renderer_handle_error(err) }
	return 0
}

fn renderer_text_cb(typ TextKind, text &char, size u32, mut renderer Renderer) int {
	renderer.text(typ, unsafe { text.vstring_with_len(int(size)) }) or {
		return renderer_handle_error(err)
	}
	return 0
}

fn renderer_debug_log_cb(msg &char, mut renderer Renderer) {
	renderer.debug_log(unsafe { msg.vstring() })
}

// render parses and renders a given markdown string based on the renderer.
pub fn render(src string, mut renderer Renderer) !string {
	parser := new(u32(C.MD_DIALECT_GITHUB), renderer_enter_block_cb, renderer_leave_block_cb,
		renderer_enter_span_cb, renderer_leave_span_cb, renderer_text_cb, renderer_debug_log_cb)

	err_code := parse(src.str, u32(src.len), &parser, &renderer)
	if err_code != 0 {
		return error_with_code('Something went wrong while parsing.', err_code)
	}

	return renderer.str().trim_space()
}
