module Jedi
  module Tools
    class Scoring
      getter conn_main : DB::Connection
      getter conn_memory : DB::Connection
      getter quote_input : MarketData::QuoteHistoryInput
      getter! quote_history : QuoteHistory
      property scaletype : String = ""
      property selected : String = ""
      property scale_builder : String = ""
      property predefined_key = ""

      alias Result = ScoringResult

      getter evaluated_results : Array(Result) = [] of Result
      getter preferred_results : Array(ScoringPreference) = [] of ScoringPreference
      getter parameter_impacts : Array(ScoringParameterImpact) = [] of ScoringParameterImpact
      getter search_summary : ScoringSearchSummary? = nil
      getter preference_policy : ScoringPreferencePolicy
      getter search_policy : ScoringSearchPolicy

      def initialize(
        @conn_main : DB::Connection,
        @conn_memory : DB::Connection,
        filename : String,
        @builder : String? = nil,
        @preference_policy : ScoringPreferencePolicy = ScoringPreferencePolicy.new,
        @search_policy : ScoringSearchPolicy = ScoringSearchPolicy.new,
        @progress_io : IO = STDERR,
      )
        @quote_input = MarketData::FileQuoteHistoryInput.new(filename)
      end

      def initialize(
        @conn_main : DB::Connection,
        @conn_memory : DB::Connection,
        @quote_input : MarketData::QuoteHistoryInput,
        @builder : String? = nil,
        @preference_policy : ScoringPreferencePolicy = ScoringPreferencePolicy.new,
        @search_policy : ScoringSearchPolicy = ScoringSearchPolicy.new,
        @progress_io : IO = STDERR,
      )
      end

      def filename : String
        quote_input.description
      end

      def run(
        option_sort : Int32 = 1,
        option_records : String? = nil,
        option_date : String? = nil,
        option_ranking : String = "raw",
        option_search : String = "adaptive",
        option_budget : Int32? = nil,
        option_display : String = "compact",
      ) : String
        validate_ranking!(option_ranking)
        validate_search!(option_search, option_budget)
        validate_display!(option_display)
        reset_run_state

        @quote_history = QuoteHistory.new(
          quote_input,
          option_records,
          option_date,
        )

        selection = I18n.t("tools.score.run.selection")
        self.selected = option_records.nil? ? selection : option_records

        specs = search_specs
        candidate_groups = specs.map do |spec|
          {spec, decode_candidates(spec.builder, spec.family)}
        end
        configure_search_description(specs)

        include_behavior = option_ranking != "raw"
        objective = ScoringObjective.new(option_sort)
        cache = {} of String => Result
        results = [] of Result
        exploration_count = 0
        refinement_count = 0
        available_count = 0
        candidate_groups.each { |entry| available_count += entry[1].size }

        if option_search == "adaptive"
          requested_budget = option_budget || search_policy.default_budget
          budgets = allocate_family_budgets(candidate_groups, requested_budget)
          progress_total = 0
          budgets.each { |value| progress_total += value }
          progress_offset = 0

          candidate_groups.each_with_index do |entry, family_index|
            spec = entry[0]
            candidates = entry[1]
            family_budget = budgets[family_index]
            next if family_budget <= 0 || candidates.empty?

            search = ScoringAdaptiveSearch.new(
              candidates,
              family_budget,
              search_policy,
            )

            exploration = search.exploration_candidates
            exploration_results = evaluate_candidates(
              exploration,
              quote_history,
              include_behavior,
              cache,
              progress_offset,
              progress_total,
            )
            results.concat(exploration_results)
            exploration_count += exploration_results.size
            progress_offset += exploration_results.size

            # This descriptive diagnostic does not drive refinement or ranking.
            if option_display == "technical"
              append_parameter_impacts(spec, exploration_results, option_sort)
            end

            refinement = search.refinement_candidates(
              exploration_results,
              objective,
            )
            refinement_results = evaluate_candidates(
              refinement,
              quote_history,
              include_behavior,
              cache,
              progress_offset,
              progress_total,
            )
            results.concat(refinement_results)
            refinement_count += refinement_results.size
            progress_offset += refinement_results.size
          end

          @search_summary = ScoringSearchSummary.new(
            "adaptive",
            available_count,
            cache.size,
            exploration_count,
            refinement_count,
            requested_budget,
          )
        else
          progress_total = available_count
          progress_offset = 0

          candidate_groups.each do |entry|
            candidates = entry[1]
            family_results = evaluate_candidates(
              candidates,
              quote_history,
              include_behavior,
              cache,
              progress_offset,
              progress_total,
            )
            results.concat(family_results)
            progress_offset += family_results.size
          end

          @search_summary = ScoringSearchSummary.new(
            "grid",
            available_count,
            cache.size,
            results.size,
            0,
          )
        end
        unhide_cursor

        objective.sort!(results)
        @evaluated_results = results

        analyzer = nil.as(ScoringPreferenceAnalyzer?)
        if option_ranking != "raw"
          analyzer = ScoringPreferenceAnalyzer.new(results, preference_policy)
          preliminary = analyzer.analyze
          temporal = ScoringTemporalValidator.new(
            conn_main,
            conn_memory,
            quote_history,
            preference_policy,
          ).validate(preliminary)
          enriched = preliminary.map do |preference|
            if metrics = temporal[preference.result.candidate.key]?
              preference.with_temporal(metrics)
            else
              preference
            end
          end
          @preferred_results = analyzer.rank(enriched)
        end

        output = render_output(
          option_ranking,
          option_display,
          option_sort,
          results,
          analyzer,
        )

        if option_display == "technical"
          summary = search_summary
          if summary && summary.adaptive?
            search_report = ScoringSearchReporter.new(summary, parameter_impacts).render
            return "#{output}\n#{search_report}"
          end
        end

        output
      end

      private def reset_run_state : Nil
        @evaluated_results = [] of Result
        @preferred_results = [] of ScoringPreference
        @parameter_impacts = [] of ScoringParameterImpact
        @search_summary = nil
        self.predefined_key = ""
        self.scale_builder = ""
        self.scaletype = ""
      end

      private def search_specs : Array(ScoringSearchSpec)
        value = @builder
        if value.nil? || value.not_nil!.strip.empty?
          ScoringSearchPresets.all
        else
          [explicit_search_spec(value.not_nil!)]
        end
      end

      private def explicit_search_spec(value : String) : ScoringSearchSpec
        if preset = ScoringSearchPresets.resolve(value)
          return preset
        end

        if value =~ /^p[1-9]+$/i
          raise LowLevelError.new(
            "unknown scoring preset '#{value.upcase}'",
            key: "tools.score.decode.key_not_found",
            kind: LowLevelError::Kind::UserInput,
            context: {:predefkey => value.upcase},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end

        ScoringSearchPresets.custom(value)
      end

      private def configure_search_description(specs : Array(ScoringSearchSpec)) : Nil
        if specs.size > 1
          self.predefined_key = "ALL"
          self.scale_builder = specs.map(&.key).join(" + ")
          self.scaletype = "I + II"
        else
          spec = specs.first
          self.predefined_key = spec.family == ScoringSearchFamily::Custom ? "" : spec.key
          self.scale_builder = spec.builder
          case spec.family
          in ScoringSearchFamily::FreeCoefficients
            self.scaletype = I18n.t("tools.score.decode.score_1")
          in ScoringSearchFamily::RegularGeometric
            self.scaletype = I18n.t("tools.score.decode.score_2")
          in ScoringSearchFamily::FlexibleGeometric
            self.scaletype = I18n.t("tools.score.decode.score_3")
          in ScoringSearchFamily::Custom
            # decode_candidates already inferred the type from the builder.
          end
        end
      end

      private def allocate_family_budgets(
        groups : Array(Tuple(ScoringSearchSpec, Array(ScoringCandidate))),
        requested_budget : Int32,
      ) : Array(Int32)
        budgets = Array(Int32).new(groups.size, 0)
        remaining = requested_budget

        while remaining > 0
          added = false
          groups.each_with_index do |entry, index|
            break if remaining <= 0
            next if budgets[index] >= entry[1].size

            budgets[index] += 1
            remaining -= 1
            added = true
          end
          break unless added
        end

        budgets
      end

      private def append_parameter_impacts(
        spec : ScoringSearchSpec,
        exploration_results : Array(Result),
        option_sort : Int32,
      ) : Nil
        impacts = ScoringImpactAnalyzer.new(
          exploration_results,
          search_policy,
          option_sort,
        ).analyze

        impacts.each do |impact|
          @parameter_impacts << ScoringParameterImpact.new(
            "#{spec.key}.#{impact.feature}",
            impact.impact_ratio,
            impact.median_span,
            impact.distinct_values,
            impact.sample_count,
          )
        end
      end

      private def render_output(
        ranking : String,
        display : String,
        option_sort : Int32,
        results : Array(Result),
        analyzer : ScoringPreferenceAnalyzer?,
      ) : String
        if display == "compact"
          return "#{readable_header(ranking, option_sort)}\n#{render_compact(ranking, results)}"
        end
        if display == "study"
          return "#{readable_header(ranking, option_sort)}\n#{render_study(ranking, results)}"
        end

        case ranking
        when "raw"
          list(results)
        when "jedi"
          "#{list_header}\n#{technical_preference_report(analyzer)}"
        when "both"
          "#{list(results)}\n#{technical_preference_report(analyzer)}"
        else
          raise LowLevelError.new(
            "unexpected scoring ranking '#{ranking}' after validation",
            kind: LowLevelError::Kind::Technical,
            log_context: {
              :ranking => ranking,
              :source  => Core::Utils.source(__FILE__, __LINE__),
            },
          )
        end
      end

      private def readable_header(ranking : String, option_sort : Int32) : String
        String.build do |io|
          io << I18n.t("tools.score.context.security", {
            :name   => quote_history.name,
            :ticker => quote_history.ticker,
            :isin   => quote_history.isin,
          }) << '\n'
          io << I18n.t("tools.score.context.period", {
            :first => quote_history.date_first.to_s("%Y-%m-%d"),
            :last  => quote_history.date_last.to_s("%Y-%m-%d"),
            :days  => quote_history.num_trading_days.to_s,
          }) << '\n'
          io << I18n.t("tools.score.context.opening_amount", {
            :amount => "%.2f" % App.initial_investment.to_f,
          }) << '\n'

          if summary = search_summary
            io << I18n.t("tools.score.context.search", {
              :strategy  => summary.strategy,
              :evaluated => summary.evaluated_candidates.to_s,
              :available => summary.available_candidates.to_s,
            })
            if budget = summary.requested_budget
              io << I18n.t("tools.score.context.budget", {:budget => budget.to_s})
            end
            io << '\n'
            # A simulation can be reused by candidates from different families.
            # Coverage is measured on results, not on distinct cached backtests.
            if evaluated_results.size < summary.available_candidates
              io << I18n.t("tools.score.context.partial_search") << '\n'
            end
          end

          io << I18n.t("tools.score.context.ranking", {
            :ranking => I18n.t("tools.score.context.rankings.#{ranking}"),
          }) << '\n'
          sort = case option_sort
                 when 2 then "activity"
                 when 3 then "investment"
                 else        "fitness"
                 end
          sort_key = ranking == "jedi" ? "search_order" : "raw_order"
          io << I18n.t("tools.score.context.#{sort_key}", {
            :order => I18n.t("tools.score.context.orders.#{sort}"),
          }) << '\n'
        end
      end

      private def render_compact(
        ranking : String,
        results : Array(Result),
      ) : String
        case ranking
        when "raw"
          ScoringCompactReporter.new(
            results,
            "tools.score.compact.raw_title",
            20,
          ).render
        when "jedi"
          ScoringCompactReporter.new(
            preferred_results.map(&.result),
            "tools.score.compact.title",
            5,
          ).render
        when "both"
          raw = ScoringCompactReporter.new(
            results,
            "tools.score.compact.raw_title",
            20,
            false,
          ).render
          jedi = ScoringCompactReporter.new(
            preferred_results.map(&.result),
            "tools.score.compact.title",
            5,
          ).render
          "#{raw}\n#{jedi}"
        else
          raise LowLevelError.new(
            "unexpected scoring ranking '#{ranking}' after validation",
            kind: LowLevelError::Kind::Technical,
            log_context: {
              :ranking => ranking,
              :source  => Core::Utils.source(__FILE__, __LINE__),
            },
          )
        end
      end

      private def render_study(
        ranking : String,
        results : Array(Result),
      ) : String
        case ranking
        when "raw"
          ScoringStudyReporter.new(
            results,
            "tools.score.study.raw_title",
            20,
          ).render
        when "jedi"
          recommended = ScoringStudyReporter.new(
            preferred_results.map(&.result),
            "tools.score.study.title",
            20,
            false,
          ).render
          evaluated = ScoringStudyReporter.new(
            results,
            "tools.score.study.evaluated_title",
            20,
          ).render
          "#{recommended}\n#{evaluated}"
        when "both"
          raw = ScoringStudyReporter.new(
            results,
            "tools.score.study.raw_title",
            20,
            false,
          ).render
          jedi = ScoringStudyReporter.new(
            preferred_results.map(&.result),
            "tools.score.study.title",
            20,
          ).render
          "#{raw}\n#{jedi}"
        else
          raise LowLevelError.new(
            "unexpected scoring ranking '#{ranking}' after validation",
            kind: LowLevelError::Kind::Technical,
            log_context: {
              :ranking => ranking,
              :source  => Core::Utils.source(__FILE__, __LINE__),
            },
          )
        end
      end

      private def technical_preference_report(
        analyzer : ScoringPreferenceAnalyzer?,
      ) : String
        value = analyzer.not_nil!
        ScoringPreferenceReporter.new(
          preferred_results,
          preference_policy,
          value.behaviorally_redundant_count,
          value.insignificant_count,
          value.inoperable_count,
          value.inactive_count,
        ).render
      end

      private def validate_ranking!(value : String) : Nil
        return if value.in?(["raw", "jedi", "both"])

        raise LowLevelError.new(
          "invalid scoring ranking '#{value}'",
          key: "tools.score.preference.invalid_ranking",
          kind: LowLevelError::Kind::UserInput,
          context: {:value => value},
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
        )
      end

      private def validate_search!(value : String, budget : Int32?) : Nil
        unless value.in?(["grid", "adaptive"])
          raise LowLevelError.new(
            "invalid scoring search strategy '#{value}'",
            key: "tools.score.search.invalid_strategy",
            kind: LowLevelError::Kind::UserInput,
            context: {:value => value},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end

        return if budget.nil?
        return if budget > 0

        raise LowLevelError.new(
          "invalid scoring search budget '#{budget}'",
          key: "tools.score.search.invalid_budget",
          kind: LowLevelError::Kind::UserInput,
          context: {:value => budget.to_s},
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
        )
      end

      private def validate_display!(value : String) : Nil
        return if value.in?(["compact", "technical", "study"])

        raise LowLevelError.new(
          "invalid scoring display mode '#{value}'",
          key: "tools.score.display.invalid_mode",
          kind: LowLevelError::Kind::UserInput,
          context: {:value => value},
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
        )
      end

      private def evaluate_candidates(
        candidates : Array(ScoringCandidate),
        history : QuoteHistory,
        include_behavior : Bool,
        cache : Hash(String, Result),
        offset : Int32,
        total_count : Int32,
      ) : Array(Result)
        results = [] of Result

        candidates.each_with_index do |candidate, index|
          if cached = cache[candidate.key]?
            results << Result.new(
              history.isin,
              candidate,
              cached.fitness,
              cached.num_avg_oper_month,
              cached.maximum_investment_ratio,
              cached.coverage,
              cached.behavior_signature,
              cached.operability,
              cached.activity,
              cached.performance,
            )
          else
            simulation = evaluate(candidate, history)
            result = if include_behavior
                       behavior = ScoringBehaviorAnalyzer.analyze(simulation)
                       operability = ScoringOperabilityAnalyzer.analyze(
                         simulation,
                         preference_policy.minimum_order_quantity,
                       )
                       activity = ScoringActivityAnalyzer.analyze(
                         simulation,
                         preference_policy.activity_rolling_months,
                       )
                       Result.new(
                         history.isin,
                         candidate,
                         simulation.gross_fitness,
                         simulation.average_operations_per_month,
                         simulation.maximum_investment_ratio,
                         behavior.coverage,
                         behavior.signature,
                         operability,
                         activity,
                         ScoringPerformance.from(simulation),
                       )
                     else
                       Result.new(
                         history.isin,
                         candidate,
                         simulation.gross_fitness,
                         simulation.average_operations_per_month,
                         simulation.maximum_investment_ratio,
                         performance: ScoringPerformance.from(simulation),
                       )
                     end
            cache[candidate.key] = result
            results << result
          end

          completed = offset + index + 1
          percent = completed.to_f / total_count.to_f * 100.0
          @progress_io.print "\r\033[K"
          @progress_io.print "#{percent.round(1)}% #{completed}/#{total_count}\r"
        end

        results
      end

      private def evaluate(
        candidate : ScoringCandidate,
        history : QuoteHistory,
      ) : BacktestResult
        BacktestEngine.new(
          conn_main: conn_main,
          conn_memory: conn_memory,
          quote_history: history,
          scaledef: candidate.scaledef,
          money: nil,
          sizing_policy: FixedAmountSizingPolicy.new(App.initial_investment.to_f),
          execution_policy: BacktestExecutionPolicy.new,
        ).run
      end

      # Public compatibility API. Historically decode returned pairs
      # {scaledef, scalebuild}; keep that contract for specs and callers.
      # P1/P2/P3 are now internal code presets rather than configuration keys.
      def decode(args : String) : Array({String, String})
        spec = explicit_search_spec(args)
        self.predefined_key = spec.family == ScoringSearchFamily::Custom ? "" : spec.key
        decode_candidates(spec.builder, spec.family).map do |candidate|
          {candidate.scaledef, candidate.scalebuild}
        end
      end

      # Internal API carrying the search-family metadata required by S3.
      private def decode_candidates(
        args : String,
        family : ScoringSearchFamily,
      ) : Array(ScoringCandidate)
        # Process the builder directly. Named presets have already been resolved
        # by ScoringSearchPresets and no longer depend on App.config.
        builder = TradingRules::Scale::Builder.new(args)
        vars = builder.vars
        self.scale_builder = args
        scaledefs = [] of ScoringCandidate
        type_key = KEYWORDS.select { |i| i.in?(vars.keys.sort) }
        case type_key.join(",")
        when "kc,ki,kb,kd,mg"
          # Generated scales = Type One canonical, ks optimized

          self.scaletype = I18n.t("tools.score.decode.score_1")
          kc_groups = groups(vars["kc"].as(Array).map &.as(Float64), vars["mg"].as(Int32))
          # TODO Test if kc_groups empty ! TODO
          kc_groups.each do |kc|
            get_float_array(vars, "ki").each do |ki|
              get_int_array(vars, "kb").each do |kb|
                get_float_array(vars, "kd").each do |kd|
                  work_scale_builder = String.build do |io|
                    io << "kc:" << kc.join(",")
                    io << ", ki:" << Core::Utils.to_pct(ki)
                    io << ", kb:" << kb
                    io << ", kd:" << kd
                  end
                  score_builder = TradingRules::Scale::Builder.new(work_scale_builder)
                  built_scale = score_builder.canonical_scale
                  unless built_scale.check[:valid] == false
                    scaledefs << ScoringCandidate.new(
                      built_scale.definition,
                      built_scale.builder,
                      work_scale_builder,
                      family: family,
                      scale_type: 1,
                    )
                  end
                end
              end
            end
          end
        when "vr,np,nn,ki,kb,kd"
          # Generated scales = Type Two canonical, ks optimized
          self.scaletype = I18n.t("tools.score.decode.score_2")
          get_float_array(vars, "vr").each do |vr|
            get_int_array(vars, "np").each do |np|
              get_int_array(vars, "nn").each do |nn|
                get_float_array(vars, "ki").each do |ki|
                  get_int_array(vars, "kb").each do |kb|
                    get_float_array(vars, "kd").each do |kd|
                      work_scale_builder = String.build do |io|
                        io << "vr:"
                        io << Core::Utils.to_pct(vr)
                        io << ", np:" << np
                        io << ", nn:" << nn
                        io << ", ki:" << Core::Utils.to_pct(ki)
                        io << ", kb:" << kb
                        io << ", kd:" << kd
                      end

                      score_builder = TradingRules::Scale::Builder.new(work_scale_builder)
                      # ## XXX Compiler error on canonical_scale call XXX ###
                      built_scale = score_builder.canonical_scale
                      unless built_scale.check[:valid] == false
                        scaledefs << ScoringCandidate.new(
                          built_scale.definition,
                          built_scale.builder,
                          work_scale_builder,
                          family: family,
                          scale_type: 2,
                        )
                      end
                    end
                  end
                end
              end
            end
          end
        when "vr,np,nn,ki,kb,kd,mg"
          # Generated scales = Type One canonical, ks optimized
          self.scaletype = I18n.t("tools.score.decode.score_3")
          unless (np = vars["np"]).is_a?(Int32)
            raise LowLevelError.new(
              "scoring builder requires 'np' to be scalar",
              key: "tools.score.invalid_builder",
              kind: LowLevelError::Kind::UserInput,
              context: {:scale_builder => scale_builder},
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
            )
          end
          unless (nn = vars["nn"]).is_a?(Int32)
            raise LowLevelError.new(
              "scoring builder requires 'nn' to be scalar",
              key: "tools.score.invalid_builder",
              kind: LowLevelError::Kind::UserInput,
              context: {:scale_builder => scale_builder},
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
            )
          end
          get_float_array(vars, "vr").each do |vr|
            kc_list = [] of Float64
            1.upto(np) do |n|
              kc_list << ((1 + vr.as(Float64)) ** n).round(2)
            end
            1.upto(nn) do |n|
              kc_list << ((1 - vr.as(Float64)) ** n).round(2)
            end
            kc_list.sort!.reverse!
            kc_groups = groups(kc_list, vars["mg"].as(Int32))
            kc_groups.each do |kc|
              get_float_array(vars, "ki").each do |ki|
                get_int_array(vars, "kb").each do |kb|
                  get_float_array(vars, "kd").each do |kd|
                    work_scale_builder = String.build do |io|
                      io << "kc:" << kc.join(',')
                      io << ", ki:" << Core::Utils.to_pct(ki)
                      io << ", kb:" << kb
                      io << ", kd:" << kd
                    end
                    score_builder = TradingRules::Scale::Builder.new(work_scale_builder)
                    built_scale = score_builder.canonical_scale
                    unless built_scale.check[:valid] == false
                      scaledefs << ScoringCandidate.new(
                        built_scale.definition,
                        built_scale.builder,
                        work_scale_builder,
                        extra_features: {
                          "vr" => vr.to_f,
                          "np" => np.to_f,
                          "nn" => nn.to_f,
                        } of String => Float64,
                        family: family,
                        scale_type: 1,
                      )
                    end
                  end
                end
              end
            end
          end
        else
          raise LowLevelError.new(
            "invalid scoring scale builder '#{scale_builder}'",
            key: "tools.score.invalid_builder",
            kind: LowLevelError::Kind::UserInput,
            context: {:scale_builder => scale_builder},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end
        deduplicate_candidates(scaledefs)
      end

      private def deduplicate_candidates(
        candidates : Array(ScoringCandidate),
      ) : Array(ScoringCandidate)
        seen = {} of String => Bool
        candidates.select do |candidate|
          if seen.has_key?(candidate.key)
            false
          else
            seen[candidate.key] = true
            true
          end
        end
      end

      # private def get_array(vars, x)
      #   if (y = vars[x]).is_a?(Array)
      #     y
      #   else
      #     [y]
      #   end
      # end

      private def get_float_array(vars, key : String) : Array(Float64)
        case value = vars[key]
        in Array(Float64)
          value
        in Float64
          [value]
        in Array(Int32)
          raise LowLevelError.new(
            "expected Float64 or Array(Float64) for scoring builder '#{key}', got #{value}",
            key: "tools.score.invalid_builder",
            kind: LowLevelError::Kind::UserInput,
            context: {:scale_builder => scale_builder},
            log_context: {
              :key    => key,
              :value  => value.to_s,
              :source => Core::Utils.source(__FILE__, __LINE__),
            },
          )
        in Int32
          raise LowLevelError.new(
            "expected Float64 or Array(Float64) for scoring builder '#{key}', got #{value}",
            key: "tools.score.invalid_builder",
            kind: LowLevelError::Kind::UserInput,
            context: {:scale_builder => scale_builder},
            log_context: {
              :key    => key,
              :value  => value.to_s,
              :source => Core::Utils.source(__FILE__, __LINE__),
            },
          )
        end
      end

      private def get_int_array(vars, key : String) : Array(Int32)
        case value = vars[key]
        in Array(Int32)
          value
        in Int32
          [value]
        in Array(Float64)
          raise LowLevelError.new(
            "expected Int32 or Array(Int32) for scoring builder '#{key}', got #{value}",
            key: "tools.score.invalid_builder",
            kind: LowLevelError::Kind::UserInput,
            context: {:scale_builder => scale_builder},
            log_context: {
              :key    => key,
              :value  => value.to_s,
              :source => Core::Utils.source(__FILE__, __LINE__),
            },
          )
        in Float64
          raise LowLevelError.new(
            "expected Int32 or Array(Int32) for scoring builder '#{key}', got #{value}",
            key: "tools.score.invalid_builder",
            kind: LowLevelError::Kind::UserInput,
            context: {:scale_builder => scale_builder},
            log_context: {
              :key    => key,
              :value  => value.to_s,
              :source => Core::Utils.source(__FILE__, __LINE__),
            },
          )
        end
      end

      def groups(values, min_group = 2, threshold = 1.0)
        greater = values.select { |v| v > threshold }
        lower = values.select { |v| v < threshold }
        greater_groups = make_groups(greater, min_group)
        lower_groups = make_groups(lower, min_group)
        flat = [] of Array(Float64)
        greater_groups.each do |g_up|
          lower_groups.each do |g_down|
            flat << (g_up + g_down)
          end
        end
        flat
      end

      def make_groups(kc_lnp, min_group_size = 2)
        result = [] of Array(Float64)
        return result if kc_lnp.size < min_group_size
        min_group_size.upto(kc_lnp.size) do |window_size|
          0.upto(kc_lnp.size - window_size) do |start|
            result << kc_lnp[start, window_size]
          end
        end
        result
      end

      def hide_cursor
        @progress_io.print "\033[?25l" # hide cursor
      end

      def unhide_cursor
        @progress_io.print "\r\033[K"
        @progress_io.print "\033[?25h" # display cursor
      end

      private def list_header : String
        indicators = Tools::Indicators.new(quote_history)
        volatility = indicators.volatility
        regression_slope = indicators.regression_slope
        regression_trend = indicators.normalized_regression_slope_percent

        String.build do |str|
          str << I18n.t("tools.score.list.scales") << "\n"
          str << I18n.t("tools.score.list.type") << scaletype << "\n\n"
          str << I18n.t("tools.score.list.isin") << quote_history.isin << "\n"
          str << I18n.t("tools.score.list.ticker") << quote_history.ticker << "\n"
          str << I18n.t("tools.score.list.name") << quote_history.name << "\n"
          str << I18n.t("tools.score.list.first_date") << quote_history.date_first.to_s(%(%d-%m-%Y)) << "\n"
          str << I18n.t("tools.score.list.last_date") << quote_history.date_last.to_s(%(%d-%m-%Y)) << "\n"
          str << I18n.t("tools.score.list.selected") << selected << "\n"
          str << I18n.t("tools.score.list.trading_days") << quote_history.num_trading_days << "\n\n"
          str << I18n.t("tools.score.list.volatility") << (volatility * 100).round(2) << "%\n"
          str << I18n.t("tools.score.list.regression_slope") << regression_slope.round(6) << "\n"
          str << I18n.t("tools.score.list.regression_trend") << regression_trend.round(4) << "%\n\n"
          str << I18n.t("tools.score.list.scale_builder")
          if predefined_key.empty?
            str << scale_builder << "\n"
          else
            str << "(" << predefined_key << ") => " << scale_builder << "\n"
          end
          if summary = search_summary
            str << I18n.t("tools.score.list.search") << summary.strategy
            if summary.adaptive?
              str << " (" << summary.evaluated_candidates
              str << "/" << summary.available_candidates << ")"
            end
            str << "\n"
          end
        end
      end

      def list(results : Array(Result)) : String
        String.build do |str|
          str << list_header << "\n"
          str << I18n.t("tools.score.list.fields_hdr") << "\n"
          results.each { |result| str << result }
        end
      end
    end
  end
end
