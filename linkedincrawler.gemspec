Gem::Specification.new do |s|
  s.name        = 'linkedincrawler'
  s.version     = '0.0.1'
  s.date        = '2015-11-01'
  s.summary     = 'Crawls public LinkedIn profiles'
  s.description = 'Crawls public LinkedIn profiles via Google'
  s.authors     = ['M. C. McGrath']
  s.email       = 'shidash@shidash.com'
  s.files       = ["lib/linkedin_crawler.rb"]
  s.homepage    =
    'https://github.com/TransparencyToolkit/linkedincrawler'
  s.license       = 'GPL'

  s.add_dependency 'linkedinparser'
  s.add_dependency 'generalscraper'
  s.add_dependency 'selenium-webdriver'
end
