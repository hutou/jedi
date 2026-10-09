require "../spec_helper"

module I18nIntegritySpec
  extend self

  def locale_leaves(locale : String) : Hash(String, String)
    root = File.expand_path("../../src/jedi/locales/#{locale}", __DIR__)
    leaves = {} of String => String

    Dir[File.join(root, "*.yml")].sort.each do |filename|
      document = YAML.parse(File.read(filename))
      flatten(document[locale], "", leaves)
    end

    leaves
  end

  def source_literal_translation_keys : Array(String)
    root = File.expand_path("../../src", __DIR__)
    keys = [] of String

    Dir[File.join(root, "**/*.cr")].sort.each do |filename|
      source = File.read(filename).lines
        .reject { |line| line.lstrip.starts_with?("#") }
        .join

      source.scan(/I18n\.t\(\s*"([^"]+)"/m) do |match|
        key = match[1]
        keys << key unless key.includes?('#')
      end
    end

    keys.sort.uniq
  end

  def interpolation_signature(value : String)
    named = value.scan(/%\{([A-Za-z0-9_]+)\}/)
      .map { |match| match[1] }
      .sort
    printf = value.scan(/%(?![%{])[-+0#]*\d*(?:\.\d+)?([diouxXeEfFgGsc])/)
      .map { |match| match[1] }

    {named: named, printf: printf}
  end

  private def flatten(
    node : YAML::Any,
    prefix : String,
    leaves : Hash(String, String),
  ) : Nil
    if mapping = node.as_h?
      mapping.each do |raw_key, value|
        key = raw_key.as_s
        child_prefix = prefix.empty? ? key : "#{prefix}.#{key}"
        flatten(value, child_prefix, leaves)
      end
    elsif sequence = node.as_a?
      sequence.each_with_index do |value, index|
        flatten(value, "#{prefix}.#{index}", leaves)
      end
    else
      leaves[prefix] = node.raw.to_s
    end
  end
end

describe "I18n locale integrity" do
  it "defines exactly the same leaf keys in English and French" do
    en = I18nIntegritySpec.locale_leaves("en")
    fr = I18nIntegritySpec.locale_leaves("fr")

    en.keys.sort.should eq(fr.keys.sort)
  end

  it "defines every literal I18n key used by the source code" do
    source_keys = I18nIntegritySpec.source_literal_translation_keys

    {"en", "fr"}.each do |locale|
      leaves = I18nIntegritySpec.locale_leaves(locale)
      missing = source_keys.reject { |key| leaves.has_key?(key) }
      missing.should be_empty
    end
  end

  it "keeps named and printf interpolation parameters consistent" do
    en = I18nIntegritySpec.locale_leaves("en")
    fr = I18nIntegritySpec.locale_leaves("fr")
    mismatches = [] of String

    en.each do |key, value|
      en_signature = I18nIntegritySpec.interpolation_signature(value)
      fr_signature = I18nIntegritySpec.interpolation_signature(fr[key])
      unless en_signature == fr_signature
        mismatches << "#{key}: en=#{en_signature}, fr=#{fr_signature}"
      end
    end

    mismatches.should be_empty
  end

  it "resolves representative report keys in both locales" do
    keys = [
      "tools.backtest.table.title",
      "tools.backtest.table.cell_execution.conservative",
      "tools.backtest.plot.title",
      "tools.play.orders.title",
      "tools.play.results.title",
      "tools.plot.title",
      "tools.statistics.volatility",
    ]

    begin
      {"en", "fr"}.each do |locale|
        Jedi.init_i18n(locale)
        output = keys.map { |key| I18n.t(key) }.join("\n")
        output.should_not contain("missing translation")
      end
    ensure
      Jedi.init_i18n("en")
    end
  end
end
