require 'requestmanager'
require 'linkedinparser'
require 'generalscraper'

require 'selenium-webdriver'
require 'pry'

class LinkedinCrawler
  def initialize(search_terms, retry_limit, requests, requests_google, requests_google2, solver_details, cm_hash)
    @search_terms = search_terms
    @output = Array.new
    
    @retry_limit = retry_limit
    @retry_count = 0
    
    @requests = requests
    @requests_google = requests_google
    @requests_google2 = requests_google2
    @solver_details = solver_details

    # Handle crawler manager info
    @cm_url = cm_hash[:crawler_manager_url] if cm_hash
    @selector_id = cm_hash[:selector_id] if cm_hash
  end

  # Run search terms and get results
  def search

    begin
      # Run Google search
    g = GeneralScraper.new("site:linkedin.com/pub -site:linkedin.com/pub/dir/", @search_terms, @requests_google, @solver_details, nil)
    urls = g.getURLs
   
    # Look for new LI urls
    g2 = GeneralScraper.new("site:linkedin.com/in", @search_terms, @requests_google2, @solver_details, nil)
    urls = JSON.parse(urls) + JSON.parse(g2.getURLs)
    rescue Exception
      binding.pry
    end
    
    # Scrape each resulting LinkedIn page
    urls.each do |profile|
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
        report_results(parsed_profile, profile_url)
      end
      
    else # It succeeded!
      report_results(parsed_profile, profile_url)
    end
  end

  # Figure out how to report results
  def report_results(results, link)
    if @cm_url
      report_incremental(results, link)
    else
      save_and_continue(results)
    end
  end

  # Report results back to Harvester incrementally
  def report_incremental(results, link)
    curl_url = @cm_url+"/relay_results"
    @retry_count = 0
    c = Curl::Easy.http_post(curl_url,
                             Curl::PostField.content('selector_id', @selector_id),
                             Curl::PostField.content('status_message', "Collected " + link),
                             Curl::PostField.content('results', JSON.pretty_generate(results)))
  end

  # Print output in JSON
  def gen_json
    JSON.pretty_generate(@output)
  end
end

