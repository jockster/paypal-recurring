test:
	@set -e
	@./node_modules/.bin/mocha \
	--reporter spec \
	-t 10000 \
	-r coffee-script \
	--compilers coffee:coffee-script \
	--globals request \
	--bail $(ARGS)

demo:
	npm install express
	@./node_modules/.bin/coffee ./examples/express

lint:
	@./node_modules/.bin/coffeelint -f .coffeelint.json -r ./lib
		
		
.PHONY: test lint demo