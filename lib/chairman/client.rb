require 'restclient'
require 'json'
require 'openssl'

module Chairman
  class Client
    def debug(message)
      puts "DEBUG: #{message}" if ENV['DEBUG']
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

    def generate_csr
      subject = OpenSSL::X509::Name.parse "/DC=org/DC=chairman/CN=#{user[:name]}"
      digest = OpenSSL::Digest::SHA1.new
      req = OpenSSL::X509::Request.new
      req.version = 0
      req.subject = subject
      req.public_key = key.public_key
      req.sign(key, digest)
      req
    end

    def cleanup
      providers.each do |provider|
        puts "Deleting socket '#{provider["binding"]}'."
        File.delete provider["binding"] if File.exists? provider["binding"]
      end
      File.delete cert_path if File.exists? cert_path
      File.delete key_path  if File.exists? key_path
    end

    def save_keys
      File.open(cert_path,"w") { |f| f.write cert.to_pem } unless File.exists? cert_path
      File.open(key_path,"w") { |f| f.write key.to_pem } unless File.exists? key_path
    end

    def broker
      @broker ||= OpenSSL::X509::Certificate.new(RestClient.get("#{@url}cert"))
    end

    def cert
      @cert ||= OpenSSL::X509::Certificate.new(File.read(cert_path)) rescue nil
      @cert ||= OpenSSL::X509::Certificate.new(RestClient.post("#{@url}cert", :csr => generate_csr))
    end

    def key
      @key ||= OpenSSL::PKey::RSA.new(File.read(key_path)) rescue nil
      @key ||= OpenSSL::PKey::RSA.new(2048)
    end

    def cert_path
      ".chairman.cert"
    end

    def key_path
      ".chairman.key"
    end
  end
end
