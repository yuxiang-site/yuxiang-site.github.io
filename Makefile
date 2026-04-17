# NOTE: phony targets will always be executed, even if a file with the same name exists.
.PHONY: site site-init site-index site-notes clean

site: site-init site-index

site-init:
	mkdir -p site/notes site/static site/css
	cp -R static/. site/static/
	cp -R css/. site/css/
	cp google1a0adb827ad679a9.html site/
	
site-index:
	pandoc \
		--wrap=none \
		--template=templates/index.html \
		--citeproc \
		--lua-filter=bold_me_in_bib.lua \
		--output=site/index.html \
		--csl=citation_order.csl \
		index.md

# site-notes:
# 	pandoc \
# 		--wrap=none \
# 		--template=templates/note.html \
# 		--output=site/notes/readings.html \
# 		notes/readings.md

clean:
	rm -r site
