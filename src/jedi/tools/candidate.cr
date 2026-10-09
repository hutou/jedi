module Jedi
  module Tools
    class Candidate
      def initialize(
        @conn_main : DB::Connection,
        @conn_memory : DB::Connection,
      )
      end

      def run(
        *,
        isin : String,
        price : Float64? = nil,
        scaledef : String,
        amount : Float64?,
        money : TradingSystem::Money?,
        capital : Float64?,
        minimum_quantity : Int32,
        operability_steps : Int32,
        extended : Bool,
      ) : String
        evaluation = CandidateEvaluator.new(@conn_main, @conn_memory).call(
          isin: isin,
          price: price,
          scaledef: scaledef,
          amount: amount,
          money: money,
          capital: capital,
          minimum_quantity: minimum_quantity,
          operability_steps: operability_steps,
        )
        CandidateReporter.new(evaluation).render(extended: extended)
      end
    end
  end
end
