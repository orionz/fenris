require 'restclient'
require 'json'
require 'openssl'

module Chairman
  class Client
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

    def cert
      @cert ||= get_cert
    end

    def get_cert
      OpenSSL::X509::Certificate.new RestClient.post("#{@url}cert", :csr => generate_csr)
    end

    def key
      @key ||= generate_key
    end

    def generate_key
      puts "Generating RSA key...."
      OpenSSL::PKey::RSA.new(2048)
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

    def broker_cert
      @broker_cert ||= OpenSSL::X509::Certificate.new RestClient.get("#{@url}cert")
    end
  end
end
