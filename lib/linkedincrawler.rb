require 'requestmanager'
require 'linkedinparser'
require 'generalscraper'

require 'selenium-webdriver'
require 'pry'

class LinkedinCrawler
  def initialize(search_terms, retry_limit, proxy_list, request_time)
    @search_terms = search_terms
    @output = Array.new
    @retry_limit = retry_limit
    @retry_count = 0
    @proxy_list = proxy_list
    @requests = RequestManager.new(@proxy_list, request_time, 5)
  end

  # Run search terms and get results
  def search
    # Run Google search
    g = GeneralScraper.new("site:linkedin.com/pub -site:linkedin.com/pub/dir/", @search_terms, @proxy_list)
    
    # Scrape each resulting LinkedIn page
    JSON.parse(g.getURLs).each do |profile|
      if profile.include?(".linkedin.") && !profile.include?("/search")
        scrape(profile)
      end
    end

    # Close all the browsers
    @requests.close_all_browsers
  end

  # Check that it is actually a LinkedIn profile page
  def check_right_page(profile_url)
    return !profile_url.include?("www.google") &&
           !profile_url.include?("linkedin.com/pub/dir") &&
           !profile_url.include?("/search") &&
           @retry_count < @retry_limit
  end

  # Scrape each page
  def scrape(profile_url)
    # Get profile page
    profile_html = @requests.get_page(profile_url)

    # Parse profile and add to output
    begin
      l = LinkedinParser.new(profile_html, profile_url, {timestamp: Time.now})
      @output += JSON.parse(l.results_by_job)
      @retry_count = 0
    rescue
      # If proxy doesn't work, try another a few times
      if check_right_page(profile_url)
        @requests.restart_browser
        @retry_count += 1
        scrape(profile_url)
      end
    end
  end

  # Print output in JSON
  def gen_json
    JSON.pretty_generate(@output)
  end
end
