require 'linkedinparser'
require 'generalscraper'
require 'selenium-webdriver'
require 'pry'

class LinkedinCrawler
  include ProxyManager
  def initialize(search_terms)
    @search_terms = search_terms
    @output = Array.new
  end

  # Run search terms and get results
  def search
    # Run Google search
    g = GeneralScraper.new("site:linkedin.com/pub", @search_terms,  "/home/shidash/proxies", false)
    
    # Scrape each resulting LinkedIn page
    gen_driver
    JSON.parse(g.getURLs).each do |profile|
      scrape(profile)
    end
  end

  # Generate driver for searches
  def gen_driver
    profile = Selenium::WebDriver::Firefox::Profile.new
    profile['intl.accept_languages'] = 'en'
    profile["javascript.enabled"] = false
    @driver = Selenium::WebDriver.for :firefox, profile: profile
  end

  # Scrape each page
  def scrape(profile_url)
    # Get profile page
    profile_html = getPage(profile_url, @driver, nil, 5, false).page_source

    # Parse profile and add to output
    begin
      l = LinkedinParser.new(profile_html, profile_url, {timestamp: Time.now})
      @output += JSON.parse(l.results_by_job)
    rescue
    end
  end

  # Print output in JSON
  def gen_json
    JSON.pretty_generate(@output)
  end
end
