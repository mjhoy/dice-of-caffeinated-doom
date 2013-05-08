.PHONY: all clean

all: public/zepto.js public/underscore.js public/raphael.js public/backbone.js

public/zepto.js:
	wget http://zeptojs.com/zepto.js -O public/zepto.js

public/raphael.js:
	wget http://github.com/DmitryBaranovskiy/raphael/raw/master/raphael-min.js -O public/raphael.js

public/underscore.js:
	wget http://underscorejs.org/underscore.js -O public/underscore.js

public/backbone.js:
	wget http://backbonejs.org/backbone.js -O public/backbone.js

