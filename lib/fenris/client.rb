require 'restclient'
require 'json'
require 'openssl'
require 'uri'
require 'eventmachine'

module Fenris
  class Client
    def initialize(url)
      @url = URI.parse(url)
    end

    def debug(message)
      puts "DEBUG: #{message}" if ENV['DEBUG']
    end

    def log(message)
      puts "LOG: #{message}"
    end

    def update(location)
      RestClient.put("#{@url}", { :location => location }, :content_type => :json, :accept => :json)
    end
  
    def user
      @user ||= JSON.parse RestClient.get("#{@url}", :content_type => :json, :accept => :json)
    end

    def ssl?
      @url.scheme == "https"
    end

    def async_connection
      @async_connection = nil if @async_connection && @async_connection.error?
      @async_connection ||= EM::Protocols::HttpClient2.connect :host => @url.host, :port => @url.port, :ssl => ssl?
    end

    def auth_string
      "Basic " + ["#{@url.user}:#{@url.password}"].pack('m').strip.gsub(/\n/,'')
    end

    def async_update(&blk)
      request = async_connection.get(:uri => "/", :authorization => auth_string )
      request.callback do |response|
        if response.status == 200
          log "Updating user info from"
          @broker ||= OpenSSL::X509::Certificate.new(async_connection.get_peer_cert) if ssl?
          @user = JSON.parse response.content
        else
          log "Error updating user info"
          debug response.status
          @async_connection = nil
        end
        blk.call if blk
      end
    end

    def consumers
      user["consumers"]
    end

    def providers
      user["providers"]
    end

    def user_name
      user["name"]
    end

    def route
      user["location"]
    end

    def remove(name)
      RestClient.delete("#{@url}consumers/#{name}");
    end

    def add(name)
      RestClient.post("#{@url}consumers", { :name => name }, :content_type => :json, :accept => :json);
    end

    def useradd(name)
      JSON.parse RestClient.post("#{@url}users", { :name => name }, :content_type => :json, :accept => :json);
    end

    def rekey
      RestClient.post("#{@url}authkeys", { }, :content_type => :json, :accept => :json);
    end

    def users
      JSON.parse RestClient.get("#{@url}users", :content_type => :json, :accept => :json)
    end

    def userdel(name)
      RestClient.delete("#{@url}users/#{name}", :content_type => :json, :accept => :json);
    end

    def bind(name, binding)
      RestClient.put("#{@url}providers/#{name}", { :binding => binding }, :content_type => :json, :accept => :json);
    end

    def digest obj
      OpenSSL::Digest::SHA1.new(obj.to_der).to_s
    end

    def generate_csr
      subject = OpenSSL::X509::Name.parse "/DC=org/DC=fenris/CN=#{user_name}"
      digest = OpenSSL::Digest::SHA1.new
      req = OpenSSL::X509::Request.new
      req.version = 0
      req.subject = subject
      req.public_key = key.public_key
      req.sign(key, digest)
      log "generating csr        #{digest req} #{subject}"
      req
    end

    def get_cn(cert)
      cert.subject.to_a.detect { |a,b,c| a == "CN" }[1] rescue nil
    end

    def validate_peer(pem, peer_connection = nil, peer_name = nil)
      consumer_cert = OpenSSL::X509::Certificate.new(pem)
      cert_cn = get_cn(consumer_cert)
      valid_peer_names = [ peer_name ] if peer_name
      valid_peer_names ||= consumers.map { |c| c["name"] }
      cn_ok = !!valid_peer_names.detect { |name| name == cert_cn }
      cert_ok = !!consumer_cert.verify(broker.public_key)
      log "Consumer Cert CN '#{cert_cn}' in allowed_list? #{cn_ok}"
      log "Consumer Cert Signed By Broker? '#{cert_ok}'"
      result = cn_ok and cert_ok
      unless result
        log "Certificate verification failed.  connection closed [#{cn_ok}] [#{cert_ok}]"
        peer_connection.close_connection if peer_connection
      end
      result
    end

    def cleanup
      providers.each do |provider|
        log "Deleting socket '#{provider["binding"]}'."
        File.delete provider["binding"] if File.exists? provider["binding"]
      end
      [ cert_path, key_path ].each do |f|
        if File.exists? f
          log "Deleting file #{f}"
          File.delete f
        end
      end
    end

    def save_keys
      File.open(cert_path,"w") { |f| f.write cert.to_pem } unless File.exists? cert_path
      File.open(key_path,"w") { |f| f.write key.to_pem } unless File.exists? key_path
    end

    def gen_cert
      cert = OpenSSL::X509::Certificate.new(RestClient.post("#{@url}cert", :csr => generate_csr))
      log "new cert received     #{digest cert}"
      cert
    end

    def gen_key
      key = OpenSSL::PKey::RSA.new(2048)
      log "new rsa key generated #{digest key}"
      key
    end

    def get_broker
      cert = OpenSSL::X509::Certificate.new(RestClient.get("#{@url}cert"))
      log "got cert from broker #{digest cert} #{cert.subject}"
      cert
    end

    def broker
      @broker ||= OpenSSL::X509::Certificate.new(RestClient.get("#{@url}cert"))
    end

    def cert
      @cert ||= OpenSSL::X509::Certificate.new(File.read(cert_path)) rescue nil
      @cert ||= gen_cert
    end

    def key
      @key ||= OpenSSL::PKey::RSA.new(File.read(key_path)) rescue nil
      @key ||= gen_key
    end

    def cert_path
      ".#{user_name}.cert"
    end

    def key_path
      ".#{user_name}.key"
    end
  end
end
