#!/usr/bin/env ruby
require 'yaml'
require 'optparse'
require 'date'
require 'nokogiri'
require 'open-uri'
require_relative 'app'

class Scraping
  @@usage = "Usage: #{$PROGRAM_NAME} apk_name"
  BASE_URL = 'https://play.google.com'
  APPS_PATH = '/store/apps'
  QUERY_STRING = '/details?id='

  private
  def download_file(apk_name)
    play_store_url = BASE_URL + APPS_PATH + QUERY_STRING + apk_name
    puts "Fetching #{play_store_url}"
    begin
      page = Nokogiri::HTML(open(play_store_url))
    rescue OpenURI::HTTPError
      puts "Error: HTTP error in the given URL: #{play_store_url}."
      exit
    rescue OpenURI::HTTPRedirect
      puts "Error: HTTP redirect error in the given URL: #{play_store_url}."
      exit
    end
  end

  def extract_features(apk_name, page)
    app = App.new(apk_name)
    app.titile = page.css('div.info-container div.document-title').text.strip
    title_arr = page.css('div.info-container .document-subtitle')
    
    app.creator = title_arr[0].text.strip
    app.creator_url = BASE_URL + title_arr[0]['href']
    date_string = page.css("div[itemprop='datePublished']").text.strip
    app.date_published = Date.strptime(date_string,"%B %d, %Y")
    app.category = page.css("span[itemprop='genre']").text.strip
    app.category_url = BASE_URL + title_arr[2]['href']
    app.ratings_count = page.css('div.reviews-stats span.reviews-num').text.strip
    app.rating =page.css('div.rating-box div.score-container div.score').text.strip
    app.description = page.css('div.show-more-content div.id-app-orig-desc').text.strip
    extended_info = page.css('div.details-section-contents div.meta-info div.content')
    app.update_date =  extended_info[0].text.strip

    app.install_size_text =  extended_info[1].text.strip
    app.downloads_count_text = extended_info[2].text.strip
    app.version =  extended_info[3].text.strip
    app.operating_systems  =  extended_info[4].text.strip
    app.content_rating = extended_info[5].text.strip
    contact_details = page.css('div.details-section div.details-section-contents div.meta-info div.content a.dev-link')
    contact_details.each do |type| 
       if (type.text.downcase.include? "website")
         app.developer_website = type['href']
       elsif(type.text.downcase.include? "email")
         app.developer_email = type["href"]
       elsif(type.text.downcase.include? "privacy")
         app.privacy_statement = type["href"]
       end
    end
    new_changes_list = page.css('div.details-section-contents div.recent-change')
    changes = []
    new_changes_list.each do |change|
      changes << change.text.strip
    end
    app.what_is_new = changes unless changes.empty? 
    serialized_app = YAML::dump(app)
    puts serialized_app
    
  end

  def start_main(apk_name)
    page = download_file(apk_name)
    extract_features(apk_name, page)
  end

  public
  def start_command_line(argv)
    begin
      opt_parser = OptionParser.new do |opts|
        opts.banner = @@usage
        opts.on('-h','--help', 'Show this help message and exit.') do
          puts opts
          exit
        end
      end
      opt_parser.parse!
    rescue OptionParser::AmbiguousArgument
      puts "Error: illegal command line argument."
      puts opt_parser.help()
      exit
    rescue OptionParser::InvalidOption
      puts "Error: illegal command line option."
      puts opt_parser.help()
      exit
    end
    if(argv[0].nil?)
      puts "Error: apk name is not specified."
      abort(@@usage)
    end
    start_main(argv[0])
  end
end

if __FILE__ ==$PROGRAM_NAME
  scraping = Scraping.new
  scraping.start_command_line(ARGV)
end
