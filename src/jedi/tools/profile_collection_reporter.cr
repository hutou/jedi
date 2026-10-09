module Jedi
  module Tools
    class ProfileCollectionReporter
      NAME_WIDTH         =      22
      MISSING_SORT_VALUE = 1.0e308

      getter result : ProfileCollectionResult
      getter sort : ProfileCollectionSort
      getter rank_criteria : Int32
      getter limit : Int32?
      getter include_rejected : Bool
      getter policy : ProfilePolicy

      def initialize(
        @result : ProfileCollectionResult,
        @sort : ProfileCollectionSort = ProfileCollectionSort::Global,
        @limit : Int32? = nil,
        @include_rejected : Bool = false,
        @policy : ProfilePolicy = ProfilePolicy.new,
        @rank_criteria : Int32 = 7,
      )
        unless rank_criteria >= 1 && rank_criteria <= GLOBAL_SORTS.size
          raise LowLevelError.new(
            "invalid profile rank criteria count '#{rank_criteria}'",
            key: "tools.profile.collection.invalid_rank_criteria",
            kind: LowLevelError::Kind::UserInput,
            context: {:value => rank_criteria.to_s},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end
      end

      def render : String
        ranked_items = result.items.reject { |item| item.profile.rejected? }
        ranks = global_ranks(ranked_items)
        displayed = sort_items(candidate_items, ranks)
        if maximum = limit
          displayed = displayed.first(maximum)
        end

        String.build do |io|
          io << I18n.t("tools.profile.collection.title") << '\n'
          io << separator << '\n'
          line(io, "tools.profile.collection.labels.source", result.selection.database_name)
          line(io, "tools.profile.collection.labels.selection", selection_label)
          line(io, "tools.profile.collection.labels.group", result.selection.group || "-")
          line(io, "tools.profile.collection.labels.selected", result.selected_count.to_s)
          line(io, "tools.profile.collection.labels.analyzed", result.analyzed_count.to_s)
          line(io, "tools.profile.collection.labels.retained", result.retained_count.to_s)
          line(io, "tools.profile.collection.labels.rejected", result.rejected_count.to_s)
          line(io, "tools.profile.collection.labels.failures", result.failures.size.to_s)
          line(io, "tools.profile.collection.labels.displayed", displayed.size.to_s)
          line(
            io,
            "tools.profile.collection.labels.ranking_criteria",
            I18n.t(
              "tools.profile.collection.ranking_criteria_value",
              {:used => rank_criteria.to_s},
            ),
          )
          line(
            io,
            "tools.profile.collection.labels.freshness_reference",
            freshness_reference_label,
          )
          line(
            io,
            "tools.profile.collection.labels.freshness_rule",
            freshness_rule_label,
          )
          line(
            io,
            "tools.profile.collection.labels.analysis_period",
            I18n.t(
              "tools.profile.collection.analysis_period_value",
              {:count => policy.analysis_period_sessions.to_s},
            ),
          )
          line(
            io,
            "tools.profile.collection.labels.liquidity_rule",
            I18n.t(
              "tools.profile.collection.liquidity_rule_value",
              {
                :amount => compact_money(policy.minimum_median_traded_value),
                :ratio  => "%.0f" % policy.maximum_low_liquidity_ratio_pct,
              },
            ),
          )
          io << '\n'

          render_table(io, displayed, ranks)
          render_failures(io)
        end.rstrip
      end

      private def candidate_items : Array(ProfileCollectionItem)
        if include_rejected
          result.items.dup
        else
          result.items.reject { |item| item.profile.rejected? }
        end
      end

      private GLOBAL_SORTS = [
        ProfileCollectionSort::Trend,
        ProfileCollectionSort::Liquidity,
        ProfileCollectionSort::Volatility,
        ProfileCollectionSort::Oscillation,
        ProfileCollectionSort::Drawdown,
        ProfileCollectionSort::Gap,
        ProfileCollectionSort::Step,
      ]

      private def sort_items(
        items : Array(ProfileCollectionItem),
        ranks : Hash(String, Array(Int32)),
      ) : Array(ProfileCollectionItem)
        return sort_global(items, ranks) if sort.global?

        sort_by_criterion(items, sort)
      end

      private def sort_global(
        items : Array(ProfileCollectionItem),
        ranks : Hash(String, Array(Int32)),
      ) : Array(ProfileCollectionItem)
        items.sort do |left, right|
          left_ranks = ranks[left.security.isin]?
          right_ranks = ranks[right.security.isin]?

          comparison = if left_ranks && right_ranks
                         compare_global_ranks(left, right, left_ranks, right_ranks)
                       elsif left_ranks
                         -1
                       elsif right_ranks
                         1
                       else
                         left.security.ticker.downcase <=> right.security.ticker.downcase
                       end
          comparison
        end
      end

      private def compare_global_ranks(
        left : ProfileCollectionItem,
        right : ProfileCollectionItem,
        left_ranks : Array(Int32),
        right_ranks : Array(Int32),
      ) : Int32
        comparison = rank_total(left_ranks) <=> rank_total(right_ranks)
        index = 0
        while comparison == 0 && index < rank_criteria
          comparison = left_ranks[index] <=> right_ranks[index]
          index += 1
        end

        if comparison == 0
          comparison = left.security.ticker.downcase <=> right.security.ticker.downcase
        end
        comparison
      end

      private def global_ranks(
        items : Array(ProfileCollectionItem),
      ) : Hash(String, Array(Int32))
        ranks = {} of String => Array(Int32)
        items.each do |item|
          ranks[item.security.isin] = Array(Int32).new(GLOBAL_SORTS.size, 0)
        end

        GLOBAL_SORTS.each_with_index do |criterion, criterion_index|
          previous_key : Tuple(Int32, Float64)? = nil
          current_rank = 0

          sort_by_criterion(items, criterion).each_with_index do |item, item_index|
            key = criterion_rank_key(item, criterion)
            if previous_key != key
              current_rank = item_index + 1
              previous_key = key
            end
            ranks[item.security.isin][criterion_index] = current_rank
          end
        end

        ranks
      end

      private def sort_by_criterion(
        items : Array(ProfileCollectionItem),
        criterion : ProfileCollectionSort,
      ) : Array(ProfileCollectionItem)
        case criterion
        when ProfileCollectionSort::Global
          raise LowLevelError.new(
            "global profile ranking cannot rank itself",
            key: "infra.internal_error",
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        when ProfileCollectionSort::Ticker
          items.sort_by { |item| item.security.ticker.downcase }
        else
          items.sort_by do |item|
            key = criterion_rank_key(item, criterion)
            {key[0], key[1], item.security.ticker.downcase}
          end
        end
      end

      private def criterion_rank_key(
        item : ProfileCollectionItem,
        criterion : ProfileCollectionSort,
      ) : Tuple(Int32, Float64)
        profile = item.profile
        metrics = profile.metrics

        case criterion
        in ProfileCollectionSort::Trend
          value = metrics.trend_pct_per_year
          {0, value.nil? ? MISSING_SORT_VALUE : -value.not_nil!}
        in ProfileCollectionSort::Liquidity
          value = metrics.median_traded_value
          {0, value.nil? ? MISSING_SORT_VALUE : -value.not_nil!}
        in ProfileCollectionSort::Volatility
          {
            -level_rank(profile.volatility.level),
            metrics.atr_pct_20 || MISSING_SORT_VALUE,
          }
        in ProfileCollectionSort::Oscillation
          value = metrics.swings_5_per_year
          {
            -level_rank(profile.oscillation.level),
            value.nil? ? MISSING_SORT_VALUE : -value.not_nil!,
          }
        in ProfileCollectionSort::Drawdown
          {0, metrics.max_drawdown_pct || MISSING_SORT_VALUE}
        in ProfileCollectionSort::Gap
          {0, metrics.large_gap_ratio_pct_3 || MISSING_SORT_VALUE}
        in ProfileCollectionSort::Step
          {0, profile.suggested_step_pct || MISSING_SORT_VALUE}
        in ProfileCollectionSort::Global, ProfileCollectionSort::Ticker
          raise LowLevelError.new(
            "profile criterion '#{criterion}' has no criterion rank key",
            key: "infra.internal_error",
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end
      end

      private def render_table(
        io : IO,
        items : Array(ProfileCollectionItem),
        ranks : Hash(String, Array(Int32)),
      ) : Nil
        io << row_format % [
          I18n.t("tools.profile.collection.columns.global_rank"),
          I18n.t("tools.profile.collection.columns.criterion_ranks"),
          I18n.t("tools.profile.collection.columns.ticker"),
          I18n.t("tools.profile.collection.columns.name"),
          I18n.t("tools.profile.collection.columns.years"),
          I18n.t("tools.profile.collection.columns.lag"),
          I18n.t("tools.profile.collection.columns.trend"),
          I18n.t("tools.profile.collection.columns.traded_value"),
          I18n.t("tools.profile.collection.columns.atr"),
          I18n.t("tools.profile.collection.columns.range"),
          I18n.t("tools.profile.collection.columns.swings"),
          I18n.t("tools.profile.collection.columns.drawdown"),
          I18n.t("tools.profile.collection.columns.gaps"),
          I18n.t("tools.profile.collection.columns.step"),
          I18n.t("tools.profile.collection.columns.moves"),
          I18n.t("tools.profile.collection.columns.status"),
          I18n.t("tools.profile.collection.columns.warnings"),
        ] << '\n'
        io << table_separator << '\n'

        if items.empty?
          io << I18n.t("tools.profile.collection.empty") << '\n'
          return
        end

        items.each do |item|
          profile = item.profile
          metrics = profile.metrics
          item_ranks = ranks[item.security.isin]?

          io << row_format % [
            item_ranks ? rank_total(item_ranks).to_s : "-",
            item_ranks ? rank_detail(item_ranks) : "-",
            clipped(item.security.ticker, 8),
            clipped(item.security.name, NAME_WIDTH),
            decimal(metrics.history_years, 1),
            freshness_lag(profile),
            decimal(metrics.trend_pct_per_year, 1),
            compact_money(metrics.median_traded_value),
            decimal(metrics.atr_pct_20, 1),
            decimal(metrics.annual_range_pct, 0),
            decimal(metrics.swings_5_per_year, 1),
            decimal(metrics.max_drawdown_pct, 0),
            decimal(metrics.large_gap_ratio_pct_3, 1),
            decimal(profile.suggested_step_pct, 1),
            decimal(profile.estimated_moves_per_year, 1),
            status_label(profile.status),
            profile.warnings.size.to_s,
          ] << '\n'
        end
      end

      private def rank_total(ranks : Array(Int32)) : Int32
        ranks.first(rank_criteria).sum
      end

      private def rank_detail(ranks : Array(Int32)) : String
        included = ranks.first(rank_criteria).join("/")
        return included if rank_criteria == ranks.size

        excluded = ranks[rank_criteria, ranks.size - rank_criteria].join("/")
        "#{included} | #{excluded}"
      end

      private def render_failures(io : IO) : Nil
        return if result.failures.empty?

        io << '\n'
        io << I18n.t("tools.profile.collection.failure_section") << '\n'
        result.failures.each do |failure|
          io << "  - " << failure.security.ticker
          io << " (" << failure.security.isin << "): "
          io << failure.message << '\n'
        end
      end

      private def row_format : String
        "%5s %-31s %-8s %-22s %5s %4s %8s %8s %6s %7s %6s %6s %6s %6s %6s %-11s %4s"
      end

      private def table_separator : String
        "-" * 178
      end

      private def separator : String
        "-" * 72
      end

      private def line(io : IO, key : String, value : String) : Nil
        io << "%-28s %s" % [I18n.t(key), value] << '\n'
      end

      private def freshness_reference_label : String
        if result.items.any? { |item| !item.profile.freshness.nil? }
          I18n.t("tools.profile.collection.freshness_reference_value")
        else
          I18n.t("tools.profile.collection.freshness_unavailable")
        end
      end

      private def freshness_rule_label : String
        if result.items.any? { |item| !item.profile.freshness.nil? }
          I18n.t(
            "tools.profile.collection.freshness_rule_value",
            {:count => policy.maximum_quote_lag_sessions.to_s},
          )
        else
          I18n.t("tools.profile.collection.freshness_unavailable")
        end
      end

      private def freshness_lag(profile : JediProfile) : String
        profile.freshness.try(&.lag_sessions.to_s) || "-"
      end

      private def selection_label : String
        base = if dataset = result.selection.dataset
                 I18n.t(
                   "tools.profile.collection.dataset_selection",
                   {:dataset => dataset},
                 )
               elsif result.selection.securities.empty?
                 I18n.t("tools.profile.collection.all_selection")
               else
                 I18n.t(
                   "tools.profile.collection.security_selection",
                   {:count => result.selection.securities.size.to_s},
                 )
               end

        if group = result.selection.group
          I18n.t(
            "tools.profile.collection.group_selection",
            {:selection => base, :group => group},
          )
        else
          base
        end
      end

      private def decimal(value : Float64?, decimals : Int32) : String
        return "-" if value.nil?

        case decimals
        when 0
          "%.0f" % value
        when 1
          "%.1f" % value
        else
          value.round(decimals).to_s
        end
      end

      private def compact_money(value : Float64?) : String
        return "-" if value.nil?

        if value >= 1_000_000.0
          "%.1fM" % (value / 1_000_000.0)
        elsif value >= 1_000.0
          "%.0fk" % (value / 1_000.0)
        else
          "%.0f" % value
        end
      end

      private def clipped(value : String, width : Int32) : String
        chars = value.chars
        return value if chars.size <= width
        chars.first(width - 3).join + "..."
      end

      private def status_label(status : ProfileStatus) : String
        I18n.t("tools.profile.statuses.#{status.to_s.downcase}")
      end

      private def level_rank(level : ProfileLevel) : Int32
        case level
        in ProfileLevel::Poor
          0
        in ProfileLevel::Unknown
          0
        in ProfileLevel::Weak
          1
        in ProfileLevel::Acceptable
          2
        in ProfileLevel::Good
          3
        in ProfileLevel::Excellent
          4
        end
      end
    end
  end
end
