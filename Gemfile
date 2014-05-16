source 'https://rubygems.org'

gemspec

gem 'rake', require: false

gem 'oj' if ENV['OJ']
gem 'ox' if ENV['OX']
gem 'nokogiri' if ENV['NOKOGIRI']

group :test do
  gem 'json-schema'
  gem 'rspec', '~> 3.0.0.beta2'
  gem 'cucumber'
  gem 'webmock'
  gem 'simplecov', require: false
end

group :docs do
  gem 'yard'
  gem 'yard-sitemap', '~> 1.0'
  gem 'rdiscount'
end

group :repl do
  gem 'pry'
end
