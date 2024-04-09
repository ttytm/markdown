import markdown

fn test_to_html() {
	text := '# Hello World!'
	result := markdown.to_html(text)
	assert result == '<h1>Hello World!</h1>'
}

fn test_to_plain() {
	text := '# Hello World\nhello **bold**'
	out := markdown.to_plain(text)
	assert out == 'Hello World\nhello bold'
}
