DINO_LOG_LEVEL = ENV['DINO_LOG_LEVEL'] unless defined?(DINO_LOG_LEVEL)

module Dino
  
  def self.logger
    Dino::Logger.setup! if Thread.current[:dino_logger].nil?
    Thread.current[:dino_logger]
  end

  def self.logger=(value)
    Thread.current[:dino_logger] = value
  end

  class Logger

    attr_accessor :level
    attr_accessor :auto_flush
    attr_reader   :buffer
    attr_reader   :log
    attr_reader   :init_args
    attr_accessor :log_static

    Levels = {
      :fatal =>  7,
      :error =>  6,
      :warn  =>  4,
      :info  =>  3,
      :debug =>  0,
      :devel => -1,
    } unless const_defined?(:Levels)

    @@mutex = {}

    Config = {
      :production  => { :log_level => :warn,  :stream => :to_file },
      :development => { :log_level => :debug, :stream => :stdout },
      :test        => { :log_level => :debug, :stream => :null }
    }

    # Embed in a String to clear all previous ANSI sequences.
    CLEAR      = "\e[0m"
    # The start of an ANSI bold sequence.
    BOLD       = "\e[1m"
    # Set the terminal's foreground ANSI color to black.
    BLACK      = "\e[30m"
    # Set the terminal's foreground ANSI color to red.
    RED        = "\e[31m"
    # Set the terminal's foreground ANSI color to green.
    GREEN      = "\e[32m"
    # Set the terminal's foreground ANSI color to yellow.
    YELLOW     = "\e[33m"
    # Set the terminal's foreground ANSI color to blue.
    BLUE       = "\e[34m"
    # Set the terminal's foreground ANSI color to magenta.
    MAGENTA    = "\e[35m"
    # Set the terminal's foreground ANSI color to cyan.
    CYAN       = "\e[36m"
    # Set the terminal's foreground ANSI color to white.
    WHITE      = "\e[37m"

    # Colors for levels
    ColoredLevels = {
      :fatal => [BOLD, RED],
      :error => [RED],
      :warn  => [YELLOW],
      :info  => [GREEN],
      :debug => [CYAN],
      :devel => [MAGENTA]
    } unless defined?(ColoredLevels)

    def self.setup!
      config_level = (DINO_LOG_LEVEL || :test).to_sym # need this for DINO_LOG_LEVEL
      config = Config[config_level]
      stream = case config[:stream]
        when :to_file
          log_file = File.join(File.dirname(__FILE__), ['..', 'log', "#{config_level}.log"])
          FileUtils.mkdir_p(File.dirname(log_file)) unless File.exists?(File.dirname(log_file))
          File.new(log_file, 'a+')
        when :null   then StringIO.new
        when :stdout then $stdout
        when :stderr then $stderr
        else config[:stream] # return itself, probabilly is a custom stream.
      end
      Thread.current[:dino_logger] = Dino::Logger.new(config.merge(:stream => stream))
    end

    def initialize(options={})
      @buffer            = []
      @auto_flush        = options.has_key?(:auto_flush) ? options[:auto_flush] : true
      @level             = options[:log_level] ? Levels[options[:log_level]] : Levels[:debug]
      @log               = options[:stream]  || $stdout
      @log.sync          = true
      @mutex             = @@mutex[@log] ||= Mutex.new
      @format_datetime   = options[:format_datetime] || "%d/%b/%Y %H:%M:%S"
      @format_message    = options[:format_message]  || "%s - [%s] \"%s\""
      @log_static        = options.has_key?(:log_static) ? options[:log_static] : false
    end

    def colored_level(level)
      style = ColoredLevels[level.to_s.downcase.to_sym].join("")
      "#{style}#{level.to_s.upcase.rjust(7)}#{CLEAR}"
    end

    def set_color(string, color, bold=false)
      color = self.class.const_get(color.to_s.upcase) if color.is_a?(Symbol)
      bold  = bold ? BOLD : ""
      "#{bold}#{color}#{string}#{CLEAR}"
    end

    def flush      
      return unless @buffer.size > 0
      @mutex.synchronize do
        @log.write(@buffer.slice!(0..-1).join(''))
      end
    end

    def close
      flush
      @log.close if @log.respond_to?(:close) && !@log.tty?
      @log = nil
    end

    def push(message = nil, level = nil)
      self << @format_message % [colored_level(level), set_color(Time.now.strftime(@format_datetime), :yellow), message.to_s.strip]
    end

    def <<(message = nil)
      message << "\n" unless message[-1] == ?\n
      @buffer << message
      flush if @auto_flush
      message
    end
    alias :write :<<

    Levels.each_pair do |name, number|
      class_eval <<-LEVELMETHODS, __FILE__, __LINE__

      # Appends a message to the log if the log level is at least as high as
      # the log level of the logger.
      #
      # ==== Parameters
      # message:: The message to be logged. Defaults to nil.
      #
      # ==== Returns
      # self:: The logger object for chaining.
      def #{name}(message = nil)
        if #{number} >= level
          message = block_given? ? yield : message
          self.push(message, :#{name}) if #{number} >= level
        end
        self
      end

      # Appends a message to the log if the log level is at least as high as
      # the log level of the logger. The bang! version of the method also auto
      # flushes the log buffer to disk.
      #
      # ==== Parameters
      # message:: The message to be logged. Defaults to nil.
      #
      # ==== Returns
      # self:: The logger object for chaining.
      def #{name}!(message = nil)
        if #{number} >= level
          message = block_given? ? yield : message
          self.push(message, :#{name}) if #{number} >= level
          flush if #{number} >= level
        end
        self
      end

      # ==== Returns
      # Boolean:: True if this level will be logged by this logger.
      def #{name}?
        #{number} >= level
      end
      LEVELMETHODS
    end

    ##
    # Dino::Loggger::Rack forwards every request to an +app+ given, and
    # logs a line in the Apache common log format to the +logger+, or
    # rack.errors by default.
    #
    class Rack
      ##
      # Common Log Format: http://httpd.apache.org/docs/1.3/logs.html#common
      # "lilith.local - - GET / HTTP/1.1 500 -"
      #  %{%s - %s %s %s%s %s - %d %s %0.4f}
      #
      FORMAT = %{%s (%0.4fms) %s - %s %s%s%s %s - %d %s}

      def initialize(app, uri_root)
        @app = app
        @uri_root = uri_root.sub(/\/$/,"")
      end

      def call(env)
        env['rack.logger'] = Dino.logger
        env['rack.errors'] = Dino.logger.log
        began_at = Time.now
        status, header, body = @app.call(env)
        log(env, status, header, began_at)
        [status, header, body]
      end

      private
        def log(env, status, header, began_at)
          now = Time.now
          length = extract_content_length(header)

          return if env['sinatra.static_file'] and !logger.log_static

          logger.debug FORMAT % [
            env["REQUEST_METHOD"],
            now - began_at,
            env['HTTP_X_FORWARDED_FOR'] || env["REMOTE_ADDR"] || "-",
            env["REMOTE_USER"] || "-",
            @uri_root || "",
            env["PATH_INFO"],
            env["QUERY_STRING"].empty? ? "" : "?" + env["QUERY_STRING"],
            env["HTTP_VERSION"],
            status.to_s[0..3],
            length]
        end

        def extract_content_length(headers)
          headers.each do |key, value|
            if key.downcase == 'content-length'
              return value.to_s == '0' ? '-' : value
            end
          end
          '-'
        end
    end
  end
end

module Kernel

  def logger
    Dino.logger
  end
end