require 'requestmanager'
require 'linkedinparser'
require 'generalscraper'

require 'selenium-webdriver'
require 'pry'

class LinkedinCrawler
  def initialize(search_terms, retry_limit, requests, requests_google, solver_details)
    @search_terms = search_terms
    @output = Array.new
    
    @retry_limit = retry_limit
    @retry_count = 0
    
    @requests = requests
    @requests_google = requests_google
    @solver_details = solver_details
  end

  # Run search terms and get results
  def search
    # Run Google search
    g = GeneralScraper.new("site:linkedin.com/pub -site:linkedin.com/pub/dir/", @search_terms, @requests_google, @solver_details)
    urls = g.getURLs

    # Scrape each resulting LinkedIn page
    JSON.parse(urls).each do |profile|
      if check_right_page(profile)
        scrape(profile)
      end
    end

    # Close all the browsers when done
    @requests.close_all_browsers
  end

  # Check that it is actually a LinkedIn profile page
  def check_right_page(profile_url)
    return !profile_url.include?("www.google") &&
           profile_url.include?(".linkedin.") &&
           !profile_url.include?("linkedin.com/pub/dir") &&
           !profile_url.include?("/search") &&
           @retry_count < @retry_limit
  end

  # Add the parsed profile to output, reset the retry count, and continue
  def save_and_continue(parsed_profile)
    @output += parsed_profile if parsed_profile != nil && !parsed_profile.empty?
    @retry_count = 0
  end

  # Check if profile parsed successfully
  def profile_parsing_failed?(parsed_profile)
    return (parsed_profile == nil) || parsed_profile.empty? || parsed_profile.first["parsing_failed"]
  end

  # Scrape each page
  def scrape(profile_url)
    # Get profile page
    profile_html = @requests.get_page(profile_url)

    # Parse profile
    l = LinkedinParser.new(profile_html, profile_url, {timestamp: Time.now, search_terms: @search_terms})
    parsed_profile = JSON.parse(l.results_by_job)

    # Check if it failed or succeeded
    if profile_parsing_failed?(parsed_profile)
      # Handle something wrong- restart in case it is blocked and rescrape
      if @retry_count < @retry_limit
        @requests.restart_browser
        @retry_count += 1
        scrape(profile_url)
      else # Just save it and move on
        save_and_continue(parsed_profile)
      end
      
    else # It succeeded!
      save_and_continue(parsed_profile)
    end
  end

  # Print output in JSON
  def gen_json
    JSON.pretty_generate(@output)
  end
end
