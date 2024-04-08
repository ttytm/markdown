/*
V wrapper for MD4C: Markdown parser for C (http://github.com/mity/md4c).

Copyright (c) 2016-2019 Martin Mitáš
Copyright (c) 2020 Ned Palacios (V bindings)
Copyright (c) 2020-2024 The V Programming Language

License: MIT
Source: https://github.com/vlang/markdown
*/
module markdown

fn test_render() ! {
	mut pt := PlaintextRenderer{}
	text := '# Hello World\nhello **bold**'
	out := render(text, mut pt)!
	assert out.len != 0
	assert out == 'Hello World\nhello bold'
}
