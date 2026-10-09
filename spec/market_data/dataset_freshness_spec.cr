require "./spec_helper"

private def freshness_isin(index : Int32) : String
  "FR#{(index + 1).to_s.rjust(10, '0')}"
end

private def freshness_rows(indices : Array(Int32) | Range(Int32, Int32), date : Time) : String
  String.build do |io|
    indices.each do |index|
      io << freshness_isin(index) << ';' << date.to_s("%Y%m%d")
      io << ";10;11;9;10;100\n"
    end
  end
end

private def import_freshness_dataset(
  workspace : JediMarketSpec::Workspace,
  database : Jedi::MarketData::Database,
  dates : Array(Time),
  code : String = "dataset_a",
) : Nil
  labels = workspace.write(
    "#{code}_labels.csv",
    String.build do |io|
      io << "ISIN;nom;ticker\n"
      dates.each_index do |index|
        io << freshness_isin(index) << ";Security " << index << ";SEC" << index << '\n'
      end
    end,
  )
  quotes = workspace.write(
    "#{code}_quotes.csv",
    String.build do |io|
      dates.each_with_index do |date, index|
        io << freshness_rows([index], date)
      end
    end,
  )
  Jedi::MarketData::MarketImporter.new(
    database, code, quotes, labels,
    date_order: Jedi::MarketData::DateOrder::Ymd,
  ).run
end

private def update_freshness_dataset(
  workspace : JediMarketSpec::Workspace,
  database : Jedi::MarketData::Database,
  indices : Array(Int32) | Range(Int32, Int32),
  date : Time,
  code : String = "dataset_a",
) : Nil
  quotes = workspace.write("#{code}_update.csv", freshness_rows(indices, date))
  Jedi::MarketData::DatasetUpdater.new(
    database, code, quotes, workspace.path("#{code}_labels.csv"),
    date_order: Jedi::MarketData::DateOrder::Ymd,
  ).run
end

private def dataset_freshness(
  database : Jedi::MarketData::Database,
  code : String = "dataset_a",
) : Time?
  value = nil.as(Time?)
  database.with_connection do |conn|
    value = Jedi::MarketData::DatasetRepository.new(conn).freshness_date_last(code)
  end
  value
end

describe "dataset global freshness" do
  it "uses real coverage on a full import rather than the latest isolated quotation" do
    JediMarketSpec.with_workspace do |workspace|
      database = JediMarketSpec.initialized_database
      old_date = Time.utc(2026, 9, 30)
      new_date = Time.utc(2026, 10, 2)
      dates = Array.new(600) { |index| index < 10 ? new_date : old_date }
      import_freshness_dataset(workspace, database, dates)

      dataset_freshness(database).should eq(old_date)
      info = Jedi::MarketData::MarketInfo.new(database).run.datasets.first
      info.import_date_last.should eq(new_date)
      info.current_date_last.should eq(new_date)
      info.freshness_date_last.should eq(old_date)
    end
  end

  it "advances after updating almost all 600 securities despite a few delayed securities" do
    JediMarketSpec.with_workspace do |workspace|
      database = JediMarketSpec.initialized_database
      old_date = Time.utc(2026, 9, 30)
      new_date = Time.utc(2026, 10, 2)
      import_freshness_dataset(workspace, database, Array.new(600, old_date))
      before = Jedi::MarketData::MarketInfo.new(database).run.datasets.first

      update_freshness_dataset(workspace, database, 0...595, new_date)
      update_freshness_dataset(workspace, database, 595...598, Time.utc(2026, 10, 1))

      dataset_freshness(database).should eq(new_date)
      after = Jedi::MarketData::MarketInfo.new(database).run.datasets.first
      after.import_date_last.should eq(old_date)
      after.imported_at.should eq(before.imported_at)
      after.current_date_last.should eq(new_date)
      after.freshness_date_last.should eq(new_date)
    end
  end

  it "does not advance after updating only 10 of 600 securities" do
    JediMarketSpec.with_workspace do |workspace|
      database = JediMarketSpec.initialized_database
      old_date = Time.utc(2026, 9, 30)
      new_date = Time.utc(2026, 10, 2)
      import_freshness_dataset(workspace, database, Array.new(600, old_date))

      update_freshness_dataset(workspace, database, 0...10, new_date)

      dataset_freshness(database).should eq(old_date)
      info = Jedi::MarketData::MarketInfo.new(database).run.datasets.first
      info.current_date_last.should eq(new_date)
      info.import_date_last.should eq(old_date)
      info.freshness_date_last.should eq(old_date)
    end
  end

  it "advances at exactly 95% coverage but not immediately below it" do
    JediMarketSpec.with_workspace do |workspace|
      database = JediMarketSpec.initialized_database
      old_date = Time.utc(2026, 9, 30)
      new_date = Time.utc(2026, 10, 2)
      import_freshness_dataset(workspace, database, Array.new(600, old_date))

      update_freshness_dataset(workspace, database, 0...569, new_date)
      dataset_freshness(database).should eq(old_date)
      update_freshness_dataset(workspace, database, [569], new_date)
      dataset_freshness(database).should eq(new_date)
    end
  end

  it "rounds the required coverage up for a dataset of 21 securities" do
    JediMarketSpec.with_workspace do |workspace|
      database = JediMarketSpec.initialized_database
      old_date = Time.utc(2026, 9, 30)
      new_date = Time.utc(2026, 10, 2)
      import_freshness_dataset(workspace, database, Array.new(21, old_date))

      update_freshness_dataset(workspace, database, 0...19, new_date)
      dataset_freshness(database).should eq(old_date)
      update_freshness_dataset(workspace, database, [19], new_date)
      dataset_freshness(database).should eq(new_date)
    end
  end

  it "requires every security when the dataset contains fewer than 20 securities" do
    JediMarketSpec.with_workspace do |workspace|
      database = JediMarketSpec.initialized_database
      old_date = Time.utc(2026, 9, 30)
      new_date = Time.utc(2026, 10, 2)
      import_freshness_dataset(workspace, database, Array.new(19, old_date))

      update_freshness_dataset(workspace, database, 0...18, new_date)
      dataset_freshness(database).should eq(old_date)
      update_freshness_dataset(workspace, database, [18], new_date)
      dataset_freshness(database).should eq(new_date)
    end
  end

  it "computes coverage independently for datasets sharing the same securities" do
    JediMarketSpec.with_workspace do |workspace|
      database = JediMarketSpec.initialized_database
      old_date = Time.utc(2026, 9, 30)
      new_date = Time.utc(2026, 10, 2)
      import_freshness_dataset(workspace, database, Array.new(20, old_date))
      import_freshness_dataset(workspace, database, Array.new(20, old_date), "dataset_b")

      update_freshness_dataset(workspace, database, 0...20, new_date)
      database.with_connection do |conn|
        Jedi::MarketData::DatasetRepository.new(conn).refresh_stats("dataset_b")
      end

      dataset_freshness(database).should eq(new_date)
      dataset_freshness(database, "dataset_b").should eq(old_date)
    end
  end

  it "counts securities without dataset quotations in the coverage population" do
    JediMarketSpec.with_workspace do |workspace|
      database = JediMarketSpec.initialized_database
      date = Time.utc(2026, 10, 2)
      import_freshness_dataset(workspace, database, Array.new(20, date))

      database.with_connection do |conn|
        conn.exec("DELETE FROM quote_datasets WHERE isin IN (?, ?)", args: [freshness_isin(0), freshness_isin(1)])
        datasets = Jedi::MarketData::DatasetRepository.new(conn)
        datasets.refresh_stats("dataset_a")
        datasets.freshness_date_last("dataset_a").should be_nil

        Jedi::MarketData::QuoteRepository.new(conn).link_dataset("dataset_a", freshness_isin(0), date)
        datasets.refresh_stats("dataset_a")
        datasets.freshness_date_last("dataset_a").should eq(date)
      end
    end
  end

  it "has no freshness reference for an empty dataset" do
    JediMarketSpec.with_workspace do
      database = JediMarketSpec.initialized_database
      database.with_connection do |conn|
        datasets = Jedi::MarketData::DatasetRepository.new(conn)
        datasets.insert("empty", "Empty", nil, "quotes.csv", "labels.csv")
        datasets.refresh_stats("empty")
        datasets.freshness_date_last("empty").should be_nil
      end
    end
  end
end
