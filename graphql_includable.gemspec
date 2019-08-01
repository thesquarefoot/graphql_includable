Gem::Specification.new do |s|
  s.name = 'graphql_includable'
  s.version = '0.2.13'
  s.licenses = ['MIT']
  s.summary = 'An ActiveSupport::Concern for GraphQL Ruby to eager-load query data'
  s.authors = ['Dan Rouse', 'Josh Vickery', 'Jordan Hamill']
  s.email = ['dan.rouse@squarefoot.com', 'jvickery@squarefoot.com', 'jordan@squarefoot.com']
  s.files = Dir['lib/**/*'].keep_if { |file| File.file?(file) }
  s.homepage = 'https://github.com/thesquarefoot/graphql_includable'

  s.add_development_dependency 'activerecord', '~> 4.0.0'
  s.add_development_dependency 'sqlite3'
end
