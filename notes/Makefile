.PHONY : all clean deploy

MD   := $(wildcard *.md) $(wildcard old/*.md) $(wildcard tutorial/*.md)
HTML := $(MD:%.md=%.html)

# Some resources for building documents with Pandoc: a nice stylesheet someone
# made for Pandoc documents, and a CDN-hosted KaTeX.
CSS_URL := https://gist.githubusercontent.com/killercup/5917178/raw/40840de5352083adb2693dc742e9f75dbb18650f/pandoc.css
KATEX_URL := https://cdnjs.cloudflare.com/ajax/libs/KaTeX/0.10.0-beta/

all: $(HTML) old/style.css tutorial/style.css

images:
	cd img && racket images.rkt

%/style.css: style.css
	# Dumb logic to copy over CSS resources.
	cp *.css $*/

clean:
	rm -f $(HTML) style.css old/*.css tutorial/*.css

# Build HTML.
PANDOC_ARGS := -f markdown -t html -s --katex=$(KATEX_URL) \
	-c style.css -c extra.css

# Specific rule for index to exclude header.
%index.html: %index.md style.css
	pandoc $(PANDOC_ARGS) $< -o $@

%.html: %.md style.css header.html footer.html
	pandoc $(PANDOC_ARGS) $< -o $@ -B header.html -A footer.html

style.css:
	curl -o $@ $(CSS_URL)

# Build PDFs, just for fun.
%.pdf: %.md
	pandoc $< -o $@

# Deployment.
RSYNCARGS := --compress --recursive --checksum --itemize-changes \
	--delete -e ssh --perms --chmod=Du=rwx,Dgo=rx,Fu=rw,Fog=r \
	--delete-excluded \
	--exclude .DS_Store --exclude Makefile
DEST := courses:coursewww/capra.cs.cornell.edu/htdocs/seashell/docs
deploy: all
	rsync $(RSYNCARGS) ./ $(DEST)
