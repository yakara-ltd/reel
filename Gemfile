source 'https://rubygems.org'

ruby '>= 3.3.0'

gem 'jruby-openssl' if defined? JRUBY_VERSION

# Use master branch of http_parser.rb for better Ruby 3.3+ compatibility
gem 'http_parser.rb', git: 'https://github.com/tmm1/http_parser.rb.git', branch: 'master'

# Specify your gem's dependencies in reel.gemspec
gemspec

group :development do
  gem 'guard-rspec'
end

group :development, :test do
  gem 'pry'
end

group :test do
  gem 'certificate_authority'
  gem 'websocket_parser', '>= 0.1.6'
  gem 'rake'
  gem 'rspec'
  gem 'coveralls', require: false
end
