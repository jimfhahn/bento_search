require 'test_helper'

class JournalTocsForJournalTest < ActiveSupport::TestCase
  extend TestWithCassette

  JournalTocsForJournal = BentoSearch::JournalTocsForJournal

  @@registered_email   = (ENV['JOURNAL_TOCS_REGISTERED_EMAIL'] || 'nobody@example.com')


  VCR.configure do |c|
    c.filter_sensitive_data("nobody@example.com", :journal_tocs) { @@registered_email }
  end

  def setup
    @test_engine_id       = "test_journal_tocs_engine_id"
    @test_decorator_name  = "MockDecorator"
  	@engine = JournalTocsForJournal.new(:registered_email => @@registered_email, 
      :id => @test_engine_id,
      :for_display => {:one => "one", :two => "two", :decorator => @test_decorator_name})
    @test_display_config = @engine.configuration.for_display
  end


 test_with_cassette("fetch_xml with hits", :journal_tocs) do
    xml = @engine.fetch_xml("1533290X")

    assert_not_nil xml
    assert_kind_of Nokogiri::XML::Document, xml
  end

  test_with_cassette("error on bad base url", :journal_tocs) do
  	engine = JournalTocsForJournal.new(:base_url => "http://doesnotexist.jhu.edu/", :registered_email => @@registered_email)

    assert_raise JournalTocsForJournal::FetchError do
      xml = engine.fetch_xml("1533290X")
    end
  end

  test_with_cassette("error on error response", :journal_tocs) do
    engine = JournalTocsForJournal.new(:base_url => "http://www.journaltocs.ac.uk/bad_url", :registered_email => @@registered_email)

    assert_raise JournalTocsForJournal::FetchError do
      xml = engine.fetch_xml("1533290X")
    end
  end

  test_with_cassette("error on bad registered email", :journal_tocs) do
    engine = JournalTocsForJournal.new(:registered_email => "unregistered@nowhere.com")

    error = assert_raise JournalTocsForJournal::FetchError do
      xml = engine.fetch_xml("1533290X")
    end

    assert error.message =~ /account is invalid/
  end

  test_with_cassette("smoke test", :journal_tocs) do
    items = @engine.fetch_by_issn("1533290X")

    assert_present items
    assert_kind_of Array, items
    assert_kind_of BentoSearch::Results, items

    assert_equal @test_engine_id,           items.engine_id
    assert_equal @test_display_config.to_h, items.display_configuration.to_h

    items.each do |item|
      assert_kind_of BentoSearch::ResultItem, item

      assert_equal @test_engine_id, item.engine_id
      assert_equal @test_display_config.to_h, item.display_configuration.to_h
      assert_equal @test_decorator_name, item.decorator
    end
  end

  test_with_cassette("fills out metadata", :journal_tocs) do
    # this ISSN has reasonably complete data in RSS feed
    items = @engine.fetch_by_issn("1600-5740")

    assert_present items.first

    first = items.first

    assert_present first.title
    assert_present first.authors
    assert_present first.authors.first.display
    assert_present first.abstract
    assert_present first.link
    assert_present first.doi
    assert_present first.publisher
    assert_present first.source_title
    assert_present first.volume
    assert_present first.issue
    assert_present first.start_page
    assert_present first.end_page
    assert_present first.publication_date

  end

  test_with_cassette("empty results on bad ISSN", :journal_tocs) do
    items = @engine.fetch_by_issn("badissn")

    assert items.empty?
  end

  test_with_cassette("sorts by date", :journal_tocs) do
    items = @engine.fetch_by_issn("0026-2617")

    (1..(items.length - 1)).each do |i|
      assert items[i].publication_date <= items[i-1].publication_date, "Expected sorted in reverse date order"
    end
  end


end

