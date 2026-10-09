module Jedi
  module Exchange
    # Retrieves one quotation from configured Web providers without persisting it.
    #
    # QuoteFetcher deliberately depends only on QuoteTarget. It can therefore be
    # used both by QuoteUpdater for a registered Security and by
    # `quote get <isin>` for an unregistered security.
    class QuoteFetcher
      record QuoteData,
        mode : String,
        website : String,
        date : Time,
        price : Float64,
        variation : Float64

      record ProviderData,
        website : String,
        date : Time,
        price : Float64,
        variation : Float64

      record ProviderQuote,
        timestamp : Time,
        price : Float64,
        variation_pct : Float64

      def initialize(@target : QuoteTarget)
        # @target.validate!
        @diagnostics = QuoteDiagnosticContext.new(@target)
      end

      def call(*, option_mode : String? = nil) : QuoteData
        modes = ModeResolver.new(cfg_market_data).resolve(option_mode)
        last_error : Exception? = nil

        modes.each do |mode|
          @diagnostics.set(:mode, value: mode)

          begin
            quote = fetch_quote_for_mode(mode)
            return QuoteData.new(
              mode: mode,
              website: quote.website,
              date: quote.date,
              price: quote.price,
              variation: quote.variation)
          rescue ex
            # Mode-alternative boundary: try the next configured mode while
            # preserving the original exception for diagnostics.
            last_error = ex
          end
        end

        raise LowLevelError.new(
          "Unable to retrieve quotation",
          kind: LowLevelError::Kind::Technical,
          log_context: @diagnostics.to_log_context(last_error),
          cause: last_error)
      end

      def diagnostic_log_context(ex : Exception? = nil) : Hash(Symbol, String)
        @diagnostics.to_log_context(ex)
      end

      private def fetch_quote_for_mode(mode : String) : ProviderData
        case mode
        when "live"
          quote = ScrapingQuoteProvider.new(@target, @diagnostics, cfg_market_data).fetch
        when "eod"
          quote = ApiQuoteProvider.new(@target, @diagnostics, cfg_market_data).fetch("eod")
        else
          raise LowLevelError.new(
            "Invalid quotation mode: #{mode}",
            kind: LowLevelError::Kind::Technical,
            log_context: @diagnostics.to_log_context)
        end

        quote
      end

      private def cfg_market_data : YAML::Any
        App.config["market_data"]
      end
    end

    # -------------------------------------------------------------------------
    # Diagnostic context
    # -------------------------------------------------------------------------

    class QuoteDiagnosticContext
      def initialize(@target : QuoteTarget)
        @values = {} of Symbol => String
      end

      def set(stage : Symbol, **values) : Nil
        @values.clear
        @values[:stage] = stage.to_s
        @values[:source] = Core::Utils.source(__FILE__, __LINE__)

        values.each do |key, value|
          @values[key] = "#{value}"
        end
      end

      def set(stage : Symbol, values : Hash(Symbol, String)) : Nil
        @values.clear
        @values[:stage] = stage.to_s
        @values[:source] = Core::Utils.source(__FILE__, __LINE__)

        values.each do |key, value|
          @values[key] = value
        end
      end

      def add(**values) : Nil
        values.each do |key, value|
          @values[key] = "#{value}"
        end
      end

      def to_log_context(ex : Exception? = nil) : Hash(Symbol, String)
        context = @target.log_context
        context[:last_error] = describe_exception(ex)

        @values.each do |key, value|
          context[key] = value
        end

        context
      end

      private def describe_exception(ex : Exception?) : String
        ex ? "#{ex.class}: #{ex.message}" : ""
      end
    end

    # -------------------------------------------------------------------------
    # Mode resolution
    # -------------------------------------------------------------------------

    class ModeResolver
      VALID_MODES = {"live", "eod"}

      def initialize(@market_data : YAML::Any)
      end

      def resolve(option_mode : String?) : Array(String)
        return normalize([option_mode]) unless option_mode.nil?

        raw = @market_data["mode_order"]?
        return ["live"] if raw.nil? || raw.raw.nil?

        modes =
          case raw.raw
          when String
            [raw.as_s]
          when Array
            raw.as_a.map(&.as_s)
          else
            raise LowLevelError.new(
              "Invalid market_data.mode_order configuration",
              kind: LowLevelError::Kind::Technical,
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          end

        normalize(modes)
      end

      private def normalize(modes : Array(String)) : Array(String)
        normalized = modes.map(&.downcase).uniq
        invalid = normalized.reject { |mode| VALID_MODES.includes?(mode) }

        unless invalid.empty?
          raise LowLevelError.new(
            "Invalid quotation mode(s): #{invalid.join(", ")}",
            kind: LowLevelError::Kind::Technical,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        normalized.empty? ? ["live"] : normalized
      end
    end

    # -------------------------------------------------------------------------
    # Regex config parser
    # -------------------------------------------------------------------------

    enum RegexConfigState
      Missing
      Disabled
      Provided
    end

    record RegexConfig,
      state : RegexConfigState,
      patterns : Array(Regex)

    class RegexConfigParser
      def initialize(@diagnostics : QuoteDiagnosticContext)
      end

      def required_patterns(cfg : YAML::Any, key : String) : Array(Regex)
        rc = read_list(cfg, key)

        case rc.state
        in RegexConfigState::Missing
          @diagnostics.set(:regex_config, key: key)
          raise LowLevelError.new(
            "Missing regex configuration: #{key}",
            kind: LowLevelError::Kind::Technical,
            log_context: @diagnostics.to_log_context)
        in RegexConfigState::Disabled
          @diagnostics.set(:regex_config, key: key)
          raise LowLevelError.new(
            "Required regex configuration is null: #{key}",
            kind: LowLevelError::Kind::Technical,
            log_context: @diagnostics.to_log_context)
        in RegexConfigState::Provided
          if rc.patterns.empty?
            @diagnostics.set(:regex_config, key: key)
            raise LowLevelError.new(
              "Required regex configuration is empty: #{key}",
              kind: LowLevelError::Kind::Technical,
              log_context: @diagnostics.to_log_context)
          end

          rc.patterns
        end
      end

      def optional_patterns(cfg : YAML::Any, key : String) : Array(Regex)?
        rc = read_list(cfg, key)

        case rc.state
        in RegexConfigState::Missing
          nil
        in RegexConfigState::Disabled
          nil
        in RegexConfigState::Provided
          rc.patterns.empty? ? nil : rc.patterns
        end
      end

      def read_list(cfg : YAML::Any, key : String) : RegexConfig
        node = cfg[key]?

        return RegexConfig.new(RegexConfigState::Missing, [] of Regex) if node.nil?
        return RegexConfig.new(RegexConfigState::Disabled, [] of Regex) if node.raw.nil?

        RegexConfig.new(RegexConfigState::Provided, parse_patterns(node, key))
      end

      private def parse_patterns(node : YAML::Any, key : String) : Array(Regex)
        case node.raw
        when String
          [Regex.new(node.as_s)]
        when Array
          patterns = [] of Regex

          node.as_a.each_with_index do |item, index|
            case item.raw
            when String
              patterns << Regex.new(item.as_s)
            when Array
              parts = item.as_a.map_with_index do |part, subindex|
                unless part.raw.is_a?(String)
                  @diagnostics.set(
                    :regex_config,
                    key: key,
                    index: "#{index}",
                    subindex: "#{subindex}")

                  raise LowLevelError.new(
                    "Invalid regex configuration element for #{key} at #{index}:#{subindex}",
                    kind: LowLevelError::Kind::Technical,
                    log_context: @diagnostics.to_log_context)
                end

                part.as_s
              end

              patterns << Regex.new(parts.join)
            else
              @diagnostics.set(:regex_config, key: key, index: "#{index}")
              raise LowLevelError.new(
                "Invalid regex configuration type for #{key} at index #{index}",
                kind: LowLevelError::Kind::Technical,
                log_context: @diagnostics.to_log_context)
            end
          end

          patterns
        else
          @diagnostics.set(:regex_config, key: key)
          raise LowLevelError.new(
            "Invalid regex configuration type for #{key}",
            kind: LowLevelError::Kind::Technical,
            log_context: @diagnostics.to_log_context)
        end
      end
    end

    # -------------------------------------------------------------------------
    # Scraping key generation
    # -------------------------------------------------------------------------

    class ScrapingKeyBuilder
      def initialize(@target : QuoteTarget, @diagnostics : QuoteDiagnosticContext)
      end

      def build(site_name : String, site_cfg : YAML::Any) : Array(String)
        if (key_exceptions = site_cfg["key_exceptions"]?) && !key_exceptions.raw.nil?
          if isin = @target.value("isin")
            exceptions = key_exceptions.as_h
            if exceptions.has_key?(isin)
              return [exceptions[isin].as_s]
            end
          end
        end

        key_strategy = site_cfg["key_strategy"]?
        if key_strategy.nil? || key_strategy.raw.nil?
          @diagnostics.set(:key_strategy, site: site_name)
          raise LowLevelError.new(
            "Missing scraping key strategy for #{site_name}",
            kind: LowLevelError::Kind::Technical,
            log_context: @diagnostics.to_log_context)
        end

        candidates = key_strategy["candidates"].as_a
        keys = [] of String

        candidates.each do |candidate|
          template = candidate["template"].as_s
          ctx = base_context
          usable = true

          if (vars = candidate["vars"]?) && !vars.raw.nil?
            vars.as_h.each do |var_name_any, spec_any|
              var_name = var_name_any.as_s
              spec = spec_any
              from = spec["from"].as_s

              val = ctx[from]?
              if val.nil?
                usable = false
                break
              end

              ctx[var_name] = apply_ops(val, spec["ops"]?)
            end
          end

          next unless usable

          if key = expand_template(template, ctx)
            keys << key unless key.empty?
          end
        end

        keys.uniq
      end

      private def base_context : Hash(String, String)
        ctx = {} of String => String

        {"isin", "ticker", "name"}.each do |field|
          if value = @target.value(field)
            ctx[field] = value
          end
        end

        ctx
      end

      private def expand_template(tpl : String, ctx : Hash(String, String)) : String?
        expanded = tpl
        ctx.each do |key, value|
          expanded = expanded.gsub("{#{key}}", value)
        end

        # A remaining placeholder means that this candidate requires a target
        # attribute that is not available (typically ticker or name for `quote get`).
        expanded =~ /\{[^}]+\}/ ? nil : expanded
      end

      private def apply_ops(value : String, ops_any : YAML::Any?) : String
        return value unless ops_any && !ops_any.raw.nil?

        result = value

        ops_any.as_a.each do |op_any|
          case op_any.raw
          when String
            case op_any.as_s
            when "trim"     then result = result.strip
            when "upcase"   then result = result.upcase
            when "downcase" then result = result.downcase
            else
              @diagnostics.set(:key_operator, operator: op_any.as_s)
              raise LowLevelError.new(
                "Unknown scraping key operator: #{op_any.as_s}",
                kind: LowLevelError::Kind::Technical,
                log_context: @diagnostics.to_log_context)
            end
          else
            h = op_any.as_h
            if (gsub_cfg = h["gsub"]?) && !gsub_cfg.raw.nil?
              pattern = gsub_cfg["pattern"].as_s
              replace = gsub_cfg["replace"].as_s
              result = result.gsub(Regex.new(pattern), replace)
            else
              @diagnostics.set(:key_operator, operator: "#{op_any}")
              raise LowLevelError.new(
                "Unknown scraping key operator mapping: #{op_any}",
                kind: LowLevelError::Kind::Technical,
                log_context: @diagnostics.to_log_context)
            end
          end
        end

        result
      end
    end

    # -------------------------------------------------------------------------
    # Scraping response validation
    # -------------------------------------------------------------------------

    class ScrapingResponseValidator
      def initialize(@diagnostics : QuoteDiagnosticContext,
                     @regex_parser : RegexConfigParser)
      end

      def validate!(site_name : String,
                    site_cfg : YAML::Any,
                    key : String,
                    url : String,
                    res : HTTP::Client::Response) : Nil
        status = res.status_code
        body = res.body

        @diagnostics.set(
          :http_status,
          {
            :site         => site_name,
            :key          => key,
            :url          => url,
            :status       => "#{status}",
            :body_excerpt => body_excerpt(body),
          })

        handle_http_status!(site_name, status, body)

        @diagnostics.set(
          :http_content,
          {
            :site         => site_name,
            :key          => key,
            :url          => url,
            :status       => "#{status}",
            :body_excerpt => body_excerpt(body),
          })

        detect_http_error_page!(site_name, site_cfg, status, body)
        detect_javascript_redirect!(site_name, key, url, status, body)
        validate_response_size!(site_name, site_cfg, key, url, status, body)
      end

      private def handle_http_status!(name : String, status : Int32, body : String) : Nil
        return if status >= 200 && status < 300

        if status == 429
          raise LowLevelError.new(
            "HTTP 429 from quote provider #{name}",
            kind: LowLevelError::Kind::Technical,
            log_context: @diagnostics.to_log_context)
        end

        raise LowLevelError.new(
          "HTTP #{status} from quote provider #{name}",
          kind: LowLevelError::Kind::Technical,
          log_context: @diagnostics.to_log_context)
      end

      # Only inspect the beginning of the response for generic HTTP-page markers.
      # Searching the full body is too noisy on financial websites: values like
      # "404" can legitimately appear in prices, volumes, JavaScript bundles, etc.
      private def detect_http_error_page!(name : String, site_cfg : YAML::Any,
                                          status : Int32, body : String) : Nil
        diagnostic_scope = http_error_diagnostic_scope(body)

        cfg_http_error_patterns(site_cfg).each do |pattern|
          next unless diagnostic_scope =~ pattern

          @diagnostics.set(
            :http_content,
            {
              :site            => name,
              :status          => "#{status}",
              :matched_pattern => pattern.inspect,
              :body_excerpt    => body_excerpt(diagnostic_scope),
            })

          raise LowLevelError.new(
            "Error page returned by quote provider #{name} (HTTP #{status})",
            kind: LowLevelError::Kind::Technical,
            log_context: @diagnostics.to_log_context)
        end
      end

      private def cfg_http_error_patterns(site_cfg : YAML::Any) : Array(Regex)
        rc = @regex_parser.read_list(site_cfg, "http_error_patterns")

        case rc.state
        in RegexConfigState::Missing
          default_http_error_patterns
        in RegexConfigState::Disabled
          [] of Regex
        in RegexConfigState::Provided
          rc.patterns
        end
      end

      private def default_http_error_patterns : Array(Regex)
        [
          /<title>[^<]*(?:404|not[[:space:]]+found|page[[:space:]]+introuvable|page[[:space:]]+non[[:space:]]+trouvée)[^<]*<\/title>/i,
          /<h1[^>]*>[^<]*(?:404|not[[:space:]]+found|page[[:space:]]+introuvable|page[[:space:]]+non[[:space:]]+trouvée)[^<]*<\/h1>/i,
          /\A[[:space:]]*(?:404|erreur[[:space:]]*404|not[[:space:]]+found|page[[:space:]]+introuvable|page[[:space:]]+non[[:space:]]+trouvée)\b/i,
        ]
      end

      private def http_error_diagnostic_scope(body : String) : String
        # First lines only, capped to avoid accidental matches deep in a normal page.
        lines = body.lines.first(20)
        scope = lines.join("\n")
        scope.size > 2000 ? scope[0, 2000] : scope
      end

      private def detect_javascript_redirect!(site_name : String,
                                              key : String,
                                              url : String,
                                              status : Int32,
                                              body : String) : Nil
        redirect = javascript_redirect_location(body)
        return if redirect.nil?

        @diagnostics.set(
          :http_content,
          {
            :site              => site_name,
            :key               => key,
            :url               => url,
            :status            => "#{status}",
            :redirect_location => redirect,
            :body_chars        => "#{body.size}",
            :body_lines        => "#{body.lines.size}",
            :body_excerpt      => body_excerpt(body),
          })

        raise LowLevelError.new(
          "Unexpected JavaScript redirect from #{site_name}",
          kind: LowLevelError::Kind::Technical,
          log_context: @diagnostics.to_log_context)
      end

      private def javascript_redirect_location(body : String) : String?
        first_line = body.lines.first?.try(&.strip)
        return nil if first_line.nil? || first_line.empty?

        # Restrict to a compact script-only first line. A normal page may contain
        # unrelated JavaScript redirects later in the body.
        return nil unless first_line.starts_with?("<script>")
        return nil unless first_line.ends_with?("</script>")

        if match = first_line.match(/location\.href[[:space:]]*=[[:space:]]*['"](?<href>[^'"]+)['"]/i)
          return match["href"]
        end

        nil
      end

      private def validate_response_size!(site_name : String,
                                          site_cfg : YAML::Any,
                                          key : String,
                                          url : String,
                                          status : Int32,
                                          body : String) : Nil
        min_chars = cfg_min_body_chars(site_cfg)
        min_lines = cfg_min_body_lines(site_cfg)
        body_chars = body.size
        body_lines = body.lines.size

        too_short = min_chars > 0 && body_chars < min_chars
        too_few_lines = min_lines > 0 && body_lines < min_lines

        return unless too_short || too_few_lines

        @diagnostics.set(
          :http_content,
          {
            :site           => site_name,
            :key            => key,
            :url            => url,
            :status         => "#{status}",
            :body_chars     => "#{body_chars}",
            :body_lines     => "#{body_lines}",
            :min_body_chars => "#{min_chars}",
            :min_body_lines => "#{min_lines}",
            :body_excerpt   => body_excerpt(body),
          })

        raise LowLevelError.new(
          "Response from #{site_name} is too short",
          kind: LowLevelError::Kind::Technical,
          log_context: @diagnostics.to_log_context)
      end

      private def cfg_min_body_chars(site_cfg : YAML::Any) : Int32
        node = site_cfg["min_body_chars"]? || site_cfg["min_response_chars"]?
        return 100 if node.nil? || node.raw.nil?
        node.as_i
      end

      private def cfg_min_body_lines(site_cfg : YAML::Any) : Int32
        node = site_cfg["min_body_lines"]? || site_cfg["min_response_lines"]?
        return 0 if node.nil? || node.raw.nil?
        node.as_i
      end

      private def body_excerpt(body : String, limit = 240) : String
        compact = body.gsub(/\s+/, " ").strip
        compact.size > limit ? "#{compact[0, limit]}..." : compact
      end
    end

    # -------------------------------------------------------------------------
    # Live scraping provider
    # -------------------------------------------------------------------------

    class ScrapingQuoteProvider
      def initialize(@target : QuoteTarget,
                     @diagnostics : QuoteDiagnosticContext,
                     @market_data : YAML::Any)
        @regex_parser = RegexConfigParser.new(@diagnostics)
        @key_builder = ScrapingKeyBuilder.new(@target, @diagnostics)
        @response_validator = ScrapingResponseValidator.new(@diagnostics, @regex_parser)
      end

      def fetch : QuoteFetcher::ProviderData
        websites = cfg_websites
        names = cfg_website_order
        names = websites.keys.map(&.as_s) if names.empty?

        last_error : Exception? = nil

        names.each do |website_name|
          website_cfg = lookup_cfg(websites, website_name)
          next unless website_cfg

          @diagnostics.set(:live_website, website: website_name)

          begin
            quote = quote_from_scraping(website_name, website_cfg)
            return QuoteFetcher::ProviderData.new(
              website: website_name,
              date: quote.timestamp,
              price: quote.price,
              variation: quote.variation_pct)
          rescue ex
            # Website-alternative boundary.
            last_error = ex
          end
        end

        raise last_error || LowLevelError.new(
          "No live quote provider succeeded",
          kind: LowLevelError::Kind::Technical,
          log_context: @diagnostics.to_log_context)
      end

      private def quote_from_scraping(site_name : String,
                                      site_cfg : YAML::Any) : QuoteFetcher::ProviderQuote
        url_tpl = site_cfg["url"].as_s
        keys = @key_builder.build(site_name, site_cfg)

        if keys.empty?
          @diagnostics.set(:scraping_keys, site: site_name)
          raise LowLevelError.new(
            "No scraping key generated for #{site_name}",
            kind: LowLevelError::Kind::Technical,
            log_context: @diagnostics.to_log_context)
        end

        price_patterns = @regex_parser.required_patterns(site_cfg, "regex_price")
        variation_patterns = @regex_parser.optional_patterns(site_cfg, "regex_variation")
        last_error : Exception? = nil

        keys.each do |key|
          url = url_tpl.gsub("{key}", URI.encode_path(key))
          @diagnostics.set(:scraping_key, site: site_name, key: key, url: url)

          begin
            res = get_scraping_response(site_name, site_cfg, key, url)
            price, variation = extract_scraped_quote!(
              site_name: site_name,
              key: key,
              url: url,
              status: res.status_code,
              body: res.body,
              price_patterns: price_patterns,
              variation_patterns: variation_patterns)

            return QuoteFetcher::ProviderQuote.new(
              timestamp: Time.local,
              price: price,
              variation_pct: variation)
          rescue ex
            # Key-alternative boundary.
            last_error = ex
          end
        end

        raise last_error || LowLevelError.new(
          "Unable to retrieve a quote from #{site_name}",
          kind: LowLevelError::Kind::Technical,
          log_context: @diagnostics.to_log_context)
      end

      private def get_scraping_response(site_name : String,
                                        site_cfg : YAML::Any,
                                        key : String,
                                        url : String) : HTTP::Client::Response
        @diagnostics.set(:http_request, site: site_name, key: key, url: url)
        res = HTTP::Client.get(url)
        @response_validator.validate!(site_name, site_cfg, key, url, res)
        res
      end

      private def extract_scraped_quote!(*,
                                         site_name : String,
                                         key : String,
                                         url : String,
                                         status : Int32,
                                         body : String,
                                         price_patterns : Array(Regex),
                                         variation_patterns : Array(Regex)?) : Tuple(Float64, Float64)
        @diagnostics.set(
          :scraping_response,
          {
            :site         => site_name,
            :key          => key,
            :url          => url,
            :status       => "#{status}",
            :body_excerpt => body_excerpt(body),
          })

        begin
          price = extract_number_from_patterns!(site_name, body, price_patterns, "price")
          variation =
            if variation_patterns.nil?
              0.0
            else
              extract_number_from_patterns!(site_name, body, variation_patterns, "variation")
            end

          {price, variation}
        rescue ex
          @diagnostics.set(
            :scraping_response,
            {
              :site         => site_name,
              :key          => key,
              :url          => url,
              :status       => "#{status}",
              :body_excerpt => body_excerpt(body),
              :parser_error => "#{ex.class}: #{ex.message}",
            })

          raise LowLevelError.new(
            "Unable to parse scraping response from #{site_name}",
            kind: LowLevelError::Kind::Technical,
            log_context: @diagnostics.to_log_context(ex),
            cause: ex)
        end
      end

      private def extract_number_from_patterns!(site_name : String,
                                                body : String,
                                                patterns : Array(Regex),
                                                kind : String) : Float64
        last_error : Exception? = nil
        patterns.each do |pattern|
          @diagnostics.set(:regex_match, site: site_name, kind: kind, pattern: pattern.inspect)

          begin
            return extract_number!(site_name, body, pattern, kind)
          rescue ex
            # Regex-alternative boundary.
            last_error = ex
          end
        end

        raise LowLevelError.new(
          "No #{kind} pattern matched for #{site_name}",
          kind: LowLevelError::Kind::Technical,
          log_context: @diagnostics.to_log_context(last_error),
          cause: last_error)
      end

      private def extract_number!(name : String, body : String,
                                  re : Regex, label : String) : Float64
        if (m = re.match(body))
          s = m[label]
          s = s.gsub("&nbsp;", " ").strip
          s = s.gsub("&#x2B;", "+")
          s = s.gsub("&#x2D;", "-")
          s = s.gsub(",", ".")
          return s.to_f
        end

        raise LowLevelError.new(
          "Regex did not match #{label} for #{name}",
          kind: LowLevelError::Kind::Technical,
          log_context: @diagnostics.to_log_context)
      end

      private def cfg_websites : Hash(YAML::Any, YAML::Any)
        @market_data["websites"]?.try(&.as_h?) || {} of YAML::Any => YAML::Any
      end

      private def cfg_website_order : Array(String)
        @market_data["website_order"]?.try(&.as_a.map(&.as_s)) || [] of String
      end

      private def lookup_cfg(map : Hash(YAML::Any, YAML::Any), name : String) : YAML::Any?
        map.each do |key, value|
          return value if key.as_s == name
        end

        nil
      end

      private def body_excerpt(body : String, limit = 240) : String
        compact = body.gsub(/\s+/, " ").strip
        compact.size > limit ? "#{compact[0, limit]}..." : compact
      end
    end

    # -------------------------------------------------------------------------
    # EOD/API provider
    # -------------------------------------------------------------------------

    class ApiQuoteProvider
      def initialize(@target : QuoteTarget,
                     @diagnostics : QuoteDiagnosticContext,
                     @market_data : YAML::Any)
      end

      def fetch(mode : String) : QuoteFetcher::ProviderData
        providers = cfg_api_providers
        names = cfg_api_order
        names = providers.keys.map(&.as_s) if names.empty?

        last_error : Exception? = nil

        names.each do |provider_name|
          provider_cfg = lookup_cfg(providers, provider_name)
          next unless provider_cfg

          @diagnostics.set(:eod_provider, provider: provider_name)

          begin
            quote = quote_from_api(provider_name, provider_cfg, mode)
            return QuoteFetcher::ProviderData.new(
              website: provider_name,
              date: quote.timestamp,
              price: quote.price,
              variation: quote.variation_pct)
          rescue ex
            # Provider-alternative boundary.
            last_error = ex
          end
        end

        raise last_error || LowLevelError.new(
          "No EOD quote provider succeeded",
          kind: LowLevelError::Kind::Technical,
          log_context: @diagnostics.to_log_context)
      end

      private def quote_from_api(name : String,
                                 api_cfg : YAML::Any,
                                 mode : String) : QuoteFetcher::ProviderQuote
        quote_cfg = api_cfg["quote"]
        api_key = api_cfg["api_key"].as_s

        candidates =
          if api_cfg["symbol_candidates"]?
            api_symbol_candidates(api_cfg)
          else
            [@target.primary_symbol]
          end

        last_error : Exception? = nil

        candidates.each do |symbol|
          @diagnostics.set(:api_symbol, provider: name, symbol: symbol)

          begin
            return quote_from_api_symbol(name, quote_cfg, api_key, symbol, mode)
          rescue ex
            # Symbol-alternative boundary.
            last_error = ex
          end
        end

        raise last_error || LowLevelError.new(
          "No valid API quote returned by #{name}",
          kind: LowLevelError::Kind::Technical,
          log_context: @diagnostics.to_log_context)
      end

      private def quote_from_api_symbol(name : String,
                                        quote_cfg : YAML::Any,
                                        api_key : String,
                                        symbol : String,
                                        mode : String) : QuoteFetcher::ProviderQuote
        uri = build_uri(
          base_url: quote_cfg["base_url"].as_s,
          path: quote_cfg["path"].as_s,
          query_any: quote_cfg["query"].as_h,
          api_key: api_key,
          symbol: symbol,
          q: @target.value("isin") || "")

        @diagnostics.set(:api_http_request, provider: name, symbol: symbol, uri: "#{uri}")
        res = HTTP::Client.get(uri)

        @diagnostics.set(
          :api_http_status,
          {
            :provider     => name,
            :symbol       => symbol,
            :uri          => "#{uri}",
            :status       => "#{res.status_code}",
            :body_excerpt => body_excerpt(res.body),
          })

        handle_http_status!(name, res.status_code)

        @diagnostics.set(:json_parse, provider: name, symbol: symbol, uri: "#{uri}")
        json = JSON.parse(res.body)

        if json["Note"]? || json["Information"]?
          @diagnostics.set(:api_response, provider: name, symbol: symbol, uri: "#{uri}", body_excerpt: body_excerpt(res.body))
          raise LowLevelError.new(
            "Quote API #{name} is throttled",
            kind: LowLevelError::Kind::Technical,
            log_context: @diagnostics.to_log_context)
        end

        global_quote = json["Global Quote"]?
        if global_quote.nil? || global_quote.as_h.empty?
          @diagnostics.set(:api_response, provider: name, symbol: symbol, uri: "#{uri}", body_excerpt: body_excerpt(res.body))
          raise LowLevelError.new(
            "Empty quote returned by #{name} for #{symbol}",
            kind: LowLevelError::Kind::Technical,
            log_context: @diagnostics.to_log_context)
        end

        price = as_f64(dig_json(json, quote_cfg["price_path"].as_a.map(&.as_s)))
        prev = as_f64(dig_json(json, quote_cfg["prev_close_path"].as_a.map(&.as_s)))

        variation_pct =
          if (change_percent_path = quote_cfg["change_percent_path"]?) && !change_percent_path.raw.nil?
            change_percent = dig_json(json, change_percent_path.as_a.map(&.as_s)).as_s
            change_percent = change_percent.gsub("%", "") if quote_cfg["change_percent_strip_percent"]?.try(&.as_bool) == true
            change_percent.to_f
          else
            ((price - prev) / prev) * 100.0
          end

        timestamp =
          if mode == "eod"
            if (trading_day_path = quote_cfg["trading_day_path"]?) && !trading_day_path.raw.nil?
              day = dig_json(json, trading_day_path.as_a.map(&.as_s)).as_s
              Time.parse_local("#{day} 00:00:00", "%F %T")
            else
              Time.local.at_beginning_of_day
            end
          else
            Time.local
          end

        QuoteFetcher::ProviderQuote.new(
          timestamp: timestamp,
          price: price,
          variation_pct: variation_pct)
      end

      private def handle_http_status!(name : String, status : Int32) : Nil
        return if status >= 200 && status < 300

        if status == 429
          raise LowLevelError.new(
            "HTTP 429 from quote provider #{name}",
            kind: LowLevelError::Kind::Technical,
            log_context: @diagnostics.to_log_context)
        end

        raise LowLevelError.new(
          "HTTP #{status} from quote provider #{name}",
          kind: LowLevelError::Kind::Technical,
          log_context: @diagnostics.to_log_context)
      end

      private def api_symbol_candidates(api_cfg : YAML::Any) : Array(String)
        symbol_candidates_cfg = api_cfg["symbol_candidates"]
        mode = symbol_candidates_cfg["mode"]?.try(&.as_s) || "ticker"

        # Suffix strategies are ticker strategies. `quote get` provides only
        # an ISIN, so use it as-is instead of manufacturing symbols such as
        # "FR...PAR" or "FR....PA".
        ticker = @target.value("ticker")
        return [@target.primary_symbol] if ticker.nil?

        base = ticker
        return [base] if base.includes?('.') || base.includes?(':')

        case mode
        when "ticker_plus_suffixes"
          suffixes = symbol_candidates_cfg["suffixes"]?.try(&.as_a.map(&.as_s)) || [""]
          suffixes.map { |suffix| suffix.empty? ? base : "#{base}#{suffix}" }.uniq
        else
          [base]
        end
      end

      private def build_uri(base_url : String,
                            path : String,
                            query_any : Hash(YAML::Any, YAML::Any),
                            api_key : String,
                            symbol : String,
                            q : String) : URI
        uri = URI.parse("#{base_url}#{path}")
        parts = [] of String

        query_any.each do |key_any, value_any|
          key = key_any.as_s
          value = value_any.as_s
          value = value.gsub("{api_key}", api_key)
          value = value.gsub("{symbol}", symbol)
          value = value.gsub("{q}", q)
          parts << "#{URI.encode_path(key)}=#{URI.encode_path(value)}"
        end

        uri.query = parts.join("&")
        uri
      end

      private def dig_json(json : JSON::Any, path : Array(String)) : JSON::Any
        cur = json
        path.each do |part|
          if part =~ /^\d+$/
            cur = cur.as_a[part.to_i]
          else
            cur = cur.as_h[part]
          end
        end
        cur
      end

      private def as_f64(v : JSON::Any) : Float64
        case v.raw
        when Int64   then v.as_i64.to_f
        when Float64 then v.as_f
        when String  then v.as_s.strip.gsub(",", ".").to_f
        else
          v.to_s.to_f
        end
      end

      private def cfg_api_providers : Hash(YAML::Any, YAML::Any)
        @market_data["api_providers"]?.try(&.as_h?) || {} of YAML::Any => YAML::Any
      end

      private def cfg_api_order : Array(String)
        @market_data["api_order"]?.try(&.as_a.map(&.as_s)) || [] of String
      end

      private def lookup_cfg(map : Hash(YAML::Any, YAML::Any), name : String) : YAML::Any?
        map.each do |key, value|
          return value if key.as_s == name
        end

        nil
      end

      private def body_excerpt(body : String, limit = 240) : String
        compact = body.gsub(/\s+/, " ").strip
        compact.size > limit ? "#{compact[0, limit]}..." : compact
      end
    end
  end
end
