module Padrino
  ##
  # Run the Padrino apps as a self-hosted server using: thin, mongrel, webrick 
  # in that order.
  #
  # ==== Examples
  #
  #   Padrino.run! 
  # ... will start server at localhost on port 3000 using the first found handler.
  #
  #   Padrino.run!(:Host => "localhost", :Port => "4000", :server => "mongrel")
  # ... will start server at localhost on port 4000 using mongrel handler.
  # 
  def self.run!(options={})
    Server.start(options)
  end
  
  ##
  # Extended and kickin-ass implementation of <tt>Rack::Server</tt> which  
  # handles eg. default configuration, padrino-related middleware stack, 
  # exceptions and so on...  
  #
  class Server < Rack::Server
    
    # Raised when specified server handler has not been found. 
    class HandlerNotFoundError < ::LoadError; end

    # List of server handlers supported by automaticaly detection.
    SUPPORTED_HANDLERS = %w[thin mongrel webrick] 

    ##
    # Prepares if necessery, and returns middleware stack for all environments.
    #
    # TODO: this stack should be changed with padrino-related stuff (eg. there
    # should be changed logger, and showexceptions. 
    #
    def self.middleware
      @middleware ||= begin
        middleware = Hash.new {|h,k| h[k] = []}
        middleware["production"].concat([lambda {|server| server.server.name =~ /CGI/ ? nil : [Rack::CommonLogger, $stderr]}])
        middleware["development"].concat(middleware["production"]+[[Rack::ShowExceptions], [Rack::Lint]])
        middleware
      end
    end
    
    def initialize(options={})
      @options = default_options.merge(self.options).merge(options)
      @options[:Port] = @options.delete(:port) if @options[:port]
      @options[:Host] = @options.delete(:host) if @options[:host]
    end
  
    ##
    # Returns racked up application.
    #
    def app
      @app ||= File.exist?(options[:config]) ? rackup_config_file : rackup_padrino_app
    end
    
    ##
    # It is racking up Padrino application! This method should never be called 
    # directly. It's used only by Rack::Server via <tt>Rack::Server#start</tt>
    # class method.  
    #
    def start
      say "Booting #{Padrino.env} environment", "32;1"
      
      enable_debug if options[:debug]                        # Start debug mode if enabled...
      $-w = true if options[:warn]                           # Display warnings if enabled...
      includes = options[:include] and $:.unshift(*includes) # Append given patsh to LOAD_PATH...
      library = options[:require] and require library        # Require given library...
      daemonize_app if options[:daemonize]                   # Run in backgraund if enabled...
      write_pid if options[:pid]                             # Write pid to given file if enabled...
      
      server.run wrapped_app, options do                     # Run padrino application within specified server...
        register_signal_traps
        say "Padrino/v#{Padrino.version} has taken port 3000", "32;1"
      end
    rescue HandlerNotFoundError => err
      say err.message, "31;1", "!!"
    rescue RuntimeError => err
      err.message =~ /no acceptor/ ? raise(Errno::EADDRINUSE) : raise(err)
    rescue Errno::EADDRINUSE
      say "Someone has taken port #{options[:Port]} already", "31;1", "!!"
    end
    
    ##
    # It returns server handler given in configuration, or detects one among 
    # the supported handlers.  
    #
    def server
      @_server ||= begin
        handlers, handler = ((s = options[:server]) ? [s] : SUPPORTED_HANDLERS), nil
        handlers.each { |name| break if handler = Rack::Handler.get(name.downcase) rescue nil }
        handler or raise HandlerNotFoundError, "None of following rack handlers found: #{handlers.join(', ')}"
      end
    end
    
    ##
    # It displays eye-candy, colorized messages. Kids will love it xD.  
    #
    def say(text, color="30;1", prefix="**")
      puts "\e[#{color}m#{prefix}\e[0m #{text}"
    end
    
    private
    
    def default_options
      super.merge(
        :config    => "config.ru",
        :Host      => "127.0.0.1",
        :Port      => 3000,
        :daemonize => false
      )
    end

    def register_signal_traps
      [:INT, :TERM].each do
        trap(:INT) do 
          puts; say "Padrino has been brutally killed!", "35;1", "**" unless server.name =~ /cgi/i
          server.respond_to?(:shutdown) ? server.shutdown : exit(0)
        end
      end
    end
    
    def enable_debug
      $DEBUG = true
      require 'pp'
      p options[:server]
      pp wrapped_app
      pp app
    end
    
    def rackup_config_file
      say "Racking up configuration from #{options[:config]}", "32;1"
      app, opts = Rack::Builder.parse_file(self.options[:config], opt_parser)
      options.merge!(opts)
      app
    end
    
    def rackup_padrino_app
      say "Racking up default Padrino application", "32;1"
      load Padrino.root("config/boot.rb") rescue LoadError
    rescue LoadError
      # nothing to do... it's allowed to ommit config/boot file...
    ensure
      Padrino.application
    end
    
  end # Server
end # Padrino
