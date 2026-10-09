require "../spec_helper"

# Specs for:
#
#   jedi tools calc <key> <params...>
#
# `tools calc` is a static calculator for Jedi formulas.  These specs exercise
# the calculator class directly because `JediCliSpec.run` executes the command
# but deliberately returns Nil.

private def run_calc(conn : DB::Connection, key : String, *args : String) : String
  memory_conn = DB.connect "sqlite3://%3Amemory%3A"

  begin
    Jedi::Tools::Calc.new(conn, memory_conn).run(key, args.to_a)
  ensure
    memory_conn.close
  end
end

private def fail_calc(conn : DB::Connection, key : String, *args : String) : Jedi::LowLevelError
  memory_conn = DB.connect "sqlite3://%3Amemory%3A"

  begin
    expect_raises(Jedi::LowLevelError) do
      Jedi::Tools::Calc.new(conn, memory_conn).run(key, args.to_a)
    end
  ensure
    memory_conn.close
  end
end

private def seed_type_one_calc_scale(conn : DB::Connection, name : String = "S_TYPE_ONE") : String
  JediSpec.insert_scale(conn, name: name, scale: JediSpec.type_one_scale)
  name
end

private def seed_type_two_calc_scale(conn : DB::Connection, name : String = "S_TYPE_TWO") : String
  JediSpec.insert_scale(conn, name: name, scale: JediSpec.type_two_scale)
  name
end

describe "Jedi::Tools::Calc" do
  describe "spe" do
    it "calculates static exposure from q0, ksp and scale stock coefficient" do
      JediSpec.with_db do |conn|
        scale_name = seed_type_one_calc_scale(conn)

        output = run_calc(conn,
          "spe",
          "scale=#{scale_name},position=0:0:-1,q0=100"
        )

        output.should contain("spe = q0 × ksp × ksₑ = 120.0")
        output.should contain("q0 = 100")
        output.should contain("e = position.e = -1")
        output.should contain("ksₑ = scale.ks(position.e) = 1.2")

        output.should contain("ksp = kcb ÷ kcp = 1.0")
        output.should contain("kcb = (1 + ki)ˣ⁻ʸ = 1.0")
        output.should contain("kcp = kc_emaxˣ × kc_eminʸ = 1.0")
      end
    end

    it "requires q0" do
      JediSpec.with_db do |conn|
        scale_name = seed_type_one_calc_scale(conn)

        ex = fail_calc(conn,
          "spe",
          "scale=#{scale_name},position=0:0:-1"
        )

        ex.key.should eq("infra.field_not_set")
        ex.context[:field].should eq("q0")
      end
    end
  end

  describe "kcb" do
    it "calculates the scale coefficient from the position" do
      JediSpec.with_db do |conn|
        scale_name = seed_type_one_calc_scale(conn)

        output = run_calc(conn,
          "kcb",
          "scale=#{scale_name},position=0:0:-1"
        )

        output.should contain("kcb = (1 + ki)ˣ⁻ʸ = 1.0")
        output.should contain("ki = scale.ki = 0.1")
        output.should contain("kb = scale.kb = 0")
        output.should contain("x = position.x = 0")
        output.should contain("y = position.y = 0")
      end
    end
  end

  describe "kcp" do
    it "calculates the price-position coefficient for a type-one scale" do
      JediSpec.with_db do |conn|
        scale_name = seed_type_one_calc_scale(conn)

        output = run_calc(conn,
          "kcp",
          "scale=#{scale_name},position=0:0:-1"
        )

        output.should contain("kcp = kc_emaxˣ × kc_eminʸ = 1.0")
        output.should contain("kc_emax = scale.kc(scale.emax) = 1.2")
        output.should contain("kc_emin = scale.kc(scale.emin) = 0.8")
      end
    end
  end

  describe "ksp" do
    it "calculates the stock-position coefficient from kcb and kcp" do
      JediSpec.with_db do |conn|
        scale_name = seed_type_one_calc_scale(conn)

        output = run_calc(conn,
          "ksp",
          "scale=#{scale_name},position=0:0:-1"
        )

        output.should contain("ksp = kcb ÷ kcp = 1.0")
        output.should contain("kcb = (1 + ki)ˣ⁻ʸ = 1.0")
        output.should contain("kcp = kc_emaxˣ × kc_eminʸ = 1.0")
      end
    end
  end

  describe "cpe" do
    it "calculates the static price for a type-one scale" do
      JediSpec.with_db do |conn|
        scale_name = seed_type_one_calc_scale(conn)

        output = run_calc(conn,
          "cpe",
          "scale=#{scale_name},position=0:0:-1,c0=10"
        )

        output.should contain("cpe = c0 × kcp × kcₑ = 9.0")
        output.should contain("c0 = 10.0")
        output.should contain("e = position.e = -1")
        output.should contain("kcₑ = scale.kc(e) = 0.9")
      end
    end

    it "requires c0 for a type-one scale" do
      JediSpec.with_db do |conn|
        scale_name = seed_type_one_calc_scale(conn)

        ex = fail_calc(conn,
          "cpe",
          "scale=#{scale_name},position=0:0:-1"
        )

        ex.key.should eq("infra.field_not_set")
        ex.context[:field].should eq("c0")
      end
    end
  end

  describe "mandatory common parameters" do
    it "requires scale" do
      JediSpec.with_db do |conn|
        ex = fail_calc(conn,
          "spe",
          "position=0:0:-1,q0=100"
        )

        ex.key.should eq("tools.calc.missing_scale")
      end
    end

    it "requires position" do
      JediSpec.with_db do |conn|
        scale_name = seed_type_one_calc_scale(conn)

        ex = fail_calc(conn,
          "spe",
          "scale=#{scale_name},q0=100"
        )

        ex.key.should eq("tools.calc.missing_position")
      end
    end
  end

  describe "argument validation" do
    it "rejects malformed key-value arguments" do
      JediSpec.with_db do |conn|
        ex = fail_calc(conn,
          "spe",
          "scale"
        )

        ex.key.should eq("tools.calc.invalid_format")
        ex.context[:arg].should eq("scale")
      end
    end

    it "rejects unknown parameters" do
      JediSpec.with_db do |conn|
        scale_name = seed_type_one_calc_scale(conn)

        ex = fail_calc(conn,
          "spe",
          "scale=#{scale_name},position=0:0:-1,q0=100,foo=bar"
        )

        ex.key.should eq("tools.calc.unknown_parameter")
        ex.context[:arg].should eq("foo")
      end
    end

    it "returns an empty output for unknown calculation keys" do
      JediSpec.with_db do |conn|
        scale_name = seed_type_one_calc_scale(conn)

        # output = run_calc(conn,
        ex = fail_calc(conn,
          "unknown",
          "scale=#{scale_name},position=0:0:-1"
        )

        # output.should eq("")
        ex.key.should eq("tools.calc.unknown_function")
      end
    end
  end
end
