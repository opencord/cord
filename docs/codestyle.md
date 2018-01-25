# CORD code style guide

## Documentation

Use the [markdown](https://daringfireball.net/projects/markdown/syntax) format
for documentation.

Check your code with
[markdownlint](https://github.com/markdownlint/markdownlint).  In
`cord/build/docs` there is a `make lint` target that will run this with the
CORD-specific style settings.

When making fenced code blocks (triple backtick surround), specify the code
language per the [hightlight.js language
list](https://github.com/isagalaev/highlight.js/tree/master/src/languages).

## Python code

Code to the [PEP8](https://www.python.org/dev/peps/pep-0008/) style guide.

Check your code with the [flake8](http://flake8.pycqa.org/en/latest/) style
checker.

If you need to reformat existing code, use the
[autopep8](https://pypi.python.org/pypi/autopep8) tool to do this.  One
invocation that will restyle code in-place is `autopep8 -aaa -i <file>.py`.
Take care when using this tool.

## Ignoring the style guide for imported or generated code

If you've imported or generated code, add it to the `.styleignore` files at the
root directory.  This will cause most of the toolsets to


