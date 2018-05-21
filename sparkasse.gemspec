Gem::Specification.new do |s|
  s.name        = 'sparkasse'
  s.version     = '0.0.1'
  s.date        = '2018-06-25'
  s.summary     = 'Sparkasse Scrapper'
  s.description = 'A gem to interact with sparkasse.at'
  s.authors     = ['Patrick Gansterer']
  s.email       = 'paroga@paroga.com'
  s.files       = ['lib/sparkasse.rb']
  s.homepage    =
    'https://github.com/paroga/ruby-sparkasse'
  s.license       = 'MIT'

  s.add_dependency 'mechanize'
end
