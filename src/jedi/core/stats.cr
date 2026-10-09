module Jedi
  module Core
    # Fonctions statistiques sur des collections numériques.
    module Stats
      # Arithmetic mean of a numeric collection.
      def self.mean(data) : Float64
        data.sum.to_f / data.size
      end

      # Variance (population by default, sample if `sample: true`).
      def self.variance(data, sample : Bool = false) : Float64
        m = mean(data)
        sum = data.reduce(0.0) { |acc, v| acc + (v - m) ** 2 }
        sum / (data.size - (sample ? 1 : 0))
      end

      # Standard deviation from a pre-computed variance.
      def self.stddev(variance : Number) : Float64
        Math.sqrt(variance.to_f)
      end

      # Standard deviation directly from a collection.
      def self.stddev(data, sample : Bool = false) : Float64
        Math.sqrt(variance(data, sample: sample))
      end

      # Returns {mean, variance, stddev} in a single pass.
      def self.stats(data, sample : Bool = false) : {Float64, Float64, Float64}
        m = mean(data)
        var = data.reduce(0.0) { |acc, v| acc + (v - m) ** 2 } /
              (data.size - (sample ? 1 : 0))
        {m, var, Math.sqrt(var)}
      end

      # Linear regression: returns {slope, intercept} for y = ax + b.
      def self.linear_regression(x, y) : {Float64, Float64}
        n = x.size
        sum_x = x.sum.to_f
        sum_y = y.sum.to_f
        sum_xy = x.zip(y).reduce(0.0) { |acc, (xi, yi)| acc + xi * yi }
        sum_x2 = x.reduce(0.0) { |acc, xi| acc + xi * xi }
        slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x ** 2)
        intercept = (sum_y - slope * sum_x) / n
        {slope, intercept}
      end

      # Pearson correlation coefficient between two collections.
      def self.correlation_coefficient(x, y) : Float64
        mx = mean(x)
        my = mean(y)
        numerator = x.zip(y).reduce(0.0) { |acc, (xi, yi)| acc + (xi - mx) * (yi - my) }
        denominator = stddev(x) * stddev(y) * x.size
        numerator / denominator
      end

      # Daily volatility based on arithmetic returns.
      def self.volatility(prices) : Float64
        returns = (1...prices.size).map { |i| (prices[i] - prices[i - 1]) / prices[i - 1].to_f }
        stddev(returns, sample: false)
      end

      # Annualised volatility (default: 252 trading days).
      def self.annualized_volatility(volatility : Float64, trading_days : Int32 = 252) : Float64
        volatility * Math.sqrt(trading_days.to_f)
      end
    end
  end
end
