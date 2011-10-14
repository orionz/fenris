require 'restclient'
require 'json'
require 'openssl'

module Chairman
  class Client
    def debug(message)
      puts "DEBUG: #{message}" if ENV['DEBUG']
    end

    def log(message)
      puts "LOG: #{message}"
    end

    def initialize(url)
      @url = url
    end

    def update(ip, port)
      RestClient.put("#{@url}", { :ip => ip, :port => port }, :content_type => :json, :accept => :json)
    end
  
    def user
      @user ||= JSON.parse RestClient.get("#{@url}", :content_type => :json, :accept => :json)
    end

    def consumers
      @consumers ||= JSON.parse RestClient.get("#{@url}consumers", :content_type => :json, :accept => :json);
    end

    def providers
      @providers ||= JSON.parse RestClient.get("#{@url}providers", :content_type => :json, :accept => :json);
    end

    def user_name
      user["name"]
    end

    def route
      "#{user["ip"]}:#{user["port"]}" if user["ip"]
    end

    def remove(name)
      RestClient.delete("#{@url}consumers/#{name}");
    end

    def add(name)
      RestClient.post("#{@url}consumers", { :name => name }, :content_type => :json, :accept => :json);
    end

    def bind(name, binding)
      RestClient.put("#{@url}providers/#{name}", { :binding => binding }, :content_type => :json, :accept => :json);
    end

    def digest obj
      OpenSSL::Digest::SHA1.new(obj.to_der).to_s
    end

    def generate_csr
      subject = OpenSSL::X509::Name.parse "/DC=org/DC=chairman/CN=#{user_name}"
      digest = OpenSSL::Digest::SHA1.new
      req = OpenSSL::X509::Request.new
      req.version = 0
      req.subject = subject
      req.public_key = key.public_key
      req.sign(key, digest)
      log "generating csr        #{digest req} #{subject}"
      req
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
