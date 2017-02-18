require 'requestmanager'
require 'linkedinparser'
require 'generalscraper'

require 'selenium-webdriver'
require 'pry'
require 'headless'

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
    @cm_hash = cm_hash
    @cm_url = cm_hash[:crawler_manager_url] if cm_hash
    @selector_id = cm_hash[:selector_id] if cm_hash
  end

  # Run search terms and get results
  def search
    # Get matching profiles
    urls = google_queries
    
    # Get pages and report results
    get_pages(urls)
    report_status("Data collection completed for " + @search_terms.to_s)
  end

  # Run queries on google
  def google_queries
    begin
      # Run Google search
      g = GeneralScraper.new("site:linkedin.com/pub -site:linkedin.com/pub/dir/", @search_terms, @requests_google, @solver_details, @cm_hash)
      urls = g.getURLs

      # Look for new LI urls
      g2 = GeneralScraper.new("site:linkedin.com/in", @search_terms, @requests_google2, @solver_details, @cm_hash)
      urls = JSON.parse(urls) + JSON.parse(g2.getURLs)
    rescue => e
      report_status("Error running Google Crawler from LinkedIn Crawler: " +e.to_s)
      binding.pry
    end
    return urls
  end

  # Get each page itself
  def get_pages(urls)
    profiles = urls.select{|u| check_right_page(u)}
    t = TranslatePage.new(profiles, @requests)
    parsed_profiles = t.translate
    parsed_profiles.each do |profile|
      parse_and_report(profile[:url], profile[:html])
    end
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

  # Parse each page
  def parse_and_report(profile_url, profile_html)
    # Parse profile
    l = LinkedinParser.new(profile_html, profile_url, {timestamp: Time.now, search_terms: @search_terms})
    parsed_profile = JSON.parse(l.results_by_job)

    # Check if it failed or succeeded
    if profile_parsing_failed?(parsed_profile)
      report_status("Profile parsing failed for "+profile_url.to_s+". Moving on.")
      report_results(parsed_profile, profile_url)
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

  # Report Harvester status message
  def report_status(status_msg)
    if @cm_url
      curl_url = @cm_url+"/update_status"
      c = Curl::Easy.http_post(curl_url,
                               Curl::PostField.content('selector_id', @selector_id),
                               Curl::PostField.content('status_message', status_msg))
    end
  end

  # Print output in JSON
  def gen_json
    JSON.pretty_generate(@output)
  end
end

