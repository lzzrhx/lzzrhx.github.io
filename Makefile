run:
	firefox http://localhost:4000; bundle exec jekyll serve
build:
	sudo pacman -S ruby rubygems ruby-default-gems && gem install jekyll bundler && bundle install