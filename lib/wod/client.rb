require 'mechanize'
require 'wod/helpers'
require 'wod/version'

module Wod
  class DevCenterPage
    attr_reader :page
    
    def initialize page
      @page = page
    end
    
    def logged_in?
      (page.title =~ /sign in/i) == nil && (page.search("span").find {|s| s.text == "Log in"}) == nil
    end
    
    def team_selection_page?
      (page.title =~ /select.*team/i)
    end
    
    def search arg
      @page.search arg
    end
    
    def form arg
      @page.form arg
    end
  end
  

  class Client
    include Wod::Helpers
  
    attr_reader :name
    attr_accessor :team
  
    def initialize username, password, team
      @username = username
      @password = password
      @team = team
    end
  
    def cookies_file
      "#{home_directory}/.wod/cookie_jar"
    end
    
    def create_agent
      agent = Mechanize.new
      agent.cookie_jar.load cookies_file if File.exists?(cookies_file)
      agent
    end
  
    def agent
      @agent ||= create_agent
    end
    
    def login_at page
      puts "Creating session"
      
      login_page = page.page.links.find { |l| l.text == 'Log in'}.click

      f = login_page.form("appleConnectForm")
      f.theAccountName = @username
      f.theAccountPW = @password
      f.submit
    end
    
    def select_team_at page
      raise NoTeamSelected.new(page.search("select[name='memberDisplayId'] option").map{|o| {:name => o.text, :value => o[:value]} }) unless self.team
      f = page.page.form("saveTeamSelection")
      select_list = f.fields.first
      select_list.value = self.team
      
      DevCenterPage.new f.click_button f.button_with(:value => /continue/i)
    end
    
    def login_and_reopen url
      page = DevCenterPage.new agent.get("https://developer.apple.com/devcenter/ios/index.action")

      unless page.logged_in?
        login_at page
        page = DevCenterPage.new agent.get url
      end
      
      if page.team_selection_page?
        select_team_at page
        page = DevCenterPage.new agent.get url
      end
      
      raise InvalidCredentials unless page.logged_in?
      raise NoTeamSelected.new(page.search("select[name='memberDisplayId'] option").map{|o| {:name => o.text, :value => o[:value]} }) if page.team_selection_page?
      agent.cookie_jar.save_as cookies_file
      page
    end

    def get url
      page = DevCenterPage.new agent.get(url)
      page = login_and_reopen(url) unless page.logged_in?
      page
    end
    
    def logged_in?
      page = get "https://developer.apple.com/devcenter/ios/index.action"
      page.logged_in? && !page.team_selection_page?
    end
  
  end
end