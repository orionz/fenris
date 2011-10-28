require 'restclient'
require 'json'
require 'openssl'
require 'uri'
require 'eventmachine'

module Fenris
  class Client
    def initialize(url)
      @url = url
      @url = URI.parse(url) unless url.is_a? URI
      @quiet = false
    end

    def config_dir
      ENV["FENRIS_CONFIG"] || "#{ENV["HOME"]}/.fenris"
    end

    def verify_private_key
      if key = read_config_file("#{user_name}.key")
        log "using existing key    #{digest key}"
      else
        key = OpenSSL::PKey::RSA.new(2048)
        write key
        log "new rsa key generated #{digest key}"
      end
    end

    def verify_cert(cn)
      if cert = read_cert(cn)
        log "existing cert         #{digest cert} :: #{cert.not_after} :: #{cn}"
      else
        cert = OpenSSL::X509::Certificate.new(RestClient.post("#{@url}cert", :csr => generate_csr(cn)))
        write cert
        log "new cert received     #{digest cert} :: #{cert.not_after} :: #{cn}"
      end
    end

    def read_cert cn
      if cert = read_config_file("#{cn}.crt")
        if cert.not_after > Time.now
          cert
        else
          log "cert expired          #{digest cert} :: #{cert.not_after} :: #{cn}"
          nil
        end
      end
    end

    def my_cert
      read_config_file "#{user_name}.crt"
    end

    def my_key
      read_config_file "#{user_name}.key"
    end

    def cert(name)
      read_config_file "#{user_name}:#{name}.crt"
    end

    def cert_path(name)
      "#{config_dir}/#{user_name}:#{name}.crt"
    end

    def my_cert_path
      "#{config_dir}/#{user_name}.crt"
    end

    def my_key_path
      "#{config_dir}/#{user_name}.key"
    end

    def write_cert(cert)
      write_config_file "#{get_cn(cert)}.crt", cert
    end

    def write_config_file name, data
      File.umask 0077
      Dir.mkdir config_dir unless Dir.exists? config_dir
      File.open("#{config_dir}/#{name}","w") { |f| f.write(data) }
    end

    def read_config_file name
      path = "#{config_dir}/#{name}"
      if not File.exists? path
        nil
      elsif name =~ /[.]json$/
        JSON.parse File.read(path)
      elsif name =~ /[.]crt$/
        OpenSSL::X509::Certificate.new File.read(path)
      elsif name =~ /[.]key$/
        OpenSSL::PKey::RSA.new File.read(path)
      else
        File.read name
      end
    end

    def write object
      if object.is_a? OpenSSL::X509::Certificate
        write_config_file "#{get_cn(object)}.crt", object.to_pem
      elsif object.is_a? OpenSSL::PKey::RSA
        write_config_file "#{user_name}.key", object.to_pem
      else
        write_config_file "#{user_name}.json", object.to_json
      end
    end

    def quiet= val
      @quiet = val
    end

    def debug(message)
      puts "DEBUG: #{message}" if ENV['DEBUG'] and !@quiet
    end

    def log(message)
      puts "LOG: #{message}" if not @quiet
    end

    def post_location(location)
      RestClient.put("#{@url}", { :location => location }, :content_type => :json, :accept => :json)
    end
  
    def user
       @user ||= read_config_file "config.json"
    end

    def ssl?
      @url.scheme == "https"
    end

    def update_user_config
      @user = JSON.parse RestClient.get("#{@url}", :content_type => :json, :accept => :json)
      write user
    end

    def update_config
      log "updating config in #{config_dir}"
      update_user_config
      log "have update user config"
      write_config_file "root.crt", RestClient.get("#{@url}cert") ## TODO find a way to get this out of the connection info
      verify_private_key
      verify_cert user_name
      providers.each do |p|
        verify_cert "#{user_name}:#{p["name"]}"
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
      user["subusers"]
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

    def generate_csr(cn)
      subject = OpenSSL::X509::Name.parse "/DC=org/DC=fenris/CN=#{cn}"
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
      consumer_cn,provider_cn = cert_cn.split ":"
      provider_cn_ok = !!user_name
      consumer_cn_ok = !!valid_peer_names.detect { |name| name == consumer_cn }
      cert_ok = !!consumer_cert.verify(root.public_key)
      log "Consumer Cert CN '#{cert_cn}' displays correct provider? #{provider_cn_ok}"
      log "Consumer Cert CN '#{cert_cn}' in allowed_list? #{consumer_cn_ok}"
      log "Consumer Cert Signed By Broker? '#{cert_ok}'"
      result = consumer_cn_ok and provider_cn_ok and cert_ok
      unless result
        log "Certificate verification failed.  connection closed [#{consumer_cn_ok}] [#{provider_cn_ok}] [#{cert_ok}]"
        peer_connection.close_connection if peer_connection
      end
      result
    end

    def root
      read_config_file "root.crt"
    end

    def key
      read_config_file "#{user_name}.key"
    end
  end
end
