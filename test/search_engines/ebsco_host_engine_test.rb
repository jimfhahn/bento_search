require 'test_helper'

require 'cgi'
require 'uri'

class EbscoHostEngineTest < ActiveSupport::TestCase
  extend TestWithCassette

  @@profile_id = (ENV['EBSCOHOST_PROFILE'] || 'DUMMY_PROFILE')
  @@profile_pwd = (ENV['EBSCOHOST_PWD'] || 'DUMMY_PWD')
  @@dbs_to_test = (ENV['EBSCOHOST_TEST_DBS'] || %w{a9h awn} )

  VCR.configure do |c|
    c.filter_sensitive_data("prof=DUMMY_PROFILE", :ebscohost) { "prof=#{@@profile_id}" }
    c.filter_sensitive_data("pwd=DUMMY_PWD", :ebscohost) { "pwd=#{@@profile_pwd}" }
  end


  def setup
    @config = {
      :profile_id => @@profile_id,
      :profile_password => @@profile_pwd,
      :databases => @@dbs_to_test
    }

    @engine = BentoSearch::EbscoHostEngine.new( @config )
  end


  def test_url_construction
    url = @engine.query_url(:query => "cancer", :start => 10, :per_page => 5)

    assert_present url

    query_params = CGI.parse( URI.parse(url).query )

    assert_equal [@engine.configuration.profile_id], query_params["prof"]
    assert_equal [@engine.configuration.profile_password], query_params["pwd"]

    assert_equal ["cancer"], query_params["query"]

    assert_equal ["5"], query_params["numrec"]
    assert_equal ["11"], query_params["startrec"]

    # default sort relevance
    assert_equal ["relevance"], query_params["sort"]

    @engine.configuration.databases.each do |db|
      assert_includes query_params["db"], db
    end
  end

  def test_date_sort_construction
    url = @engine.query_url(:query => "cancer", :sort => "date_desc")

    query_params = CGI.parse( URI.parse(url).query )

    assert_equal ["date"], query_params["sort"]
  end

  def test_fielded_construction
    url = @engine.query_url(:query => "cancer", :search_field => "SU")

    query_params = CGI.parse( URI.parse(url).query )

    assert_equal ["(SU cancer)"], query_params["query"]
  end

  def test_peer_review_limit_construction
    url = @engine.query_url(:query => "cancer", :search_field => "SU", :peer_reviewed_only => true)

    query_params = CGI.parse( URI.parse(url).query )

    assert_equal ["(SU cancer) AND (RV Y)"], query_params["query"]
  end

  def test_date_limit_construction
    url = @engine.query_url(:query => "cancer", :pubyear_start => "1980", :pubyear_end => "1989")
    query_params = CGI.parse( URI.parse(url).query )

    assert_equal ["cancer AND (DT 1980-1989)"], query_params["query"]

    # just one
    url = @engine.query_url(:query => "cancer", :pubyear_start => "1980")
    query_params = CGI.parse( URI.parse(url).query )

    assert_equal ["cancer AND (DT 1980-)"], query_params["query"]

  end

  def test_per_search_databases_construction
    url = @engine.query_url(:query => "cancer", :databases => ["aaa", "bbb"])

    query_params = CGI.parse( URI.parse(url).query )

    assert_equal ["aaa", "bbb"].to_set, query_params["db"].to_set
  end

  def test_lookup_by_accession_number_construction
    url = @engine.query_url(:query => "123456", :search_field => "AN")

    query_params = CGI.parse( URI.parse(url).query )

    assert_equal ["(AN 123456)"], query_params["query"]
  end


  def test_prepare_query
    query = @engine.ebsco_query_prepare('one :. ; two "three four" and NOT OR five')

    assert_equal 'one AND two AND "three four" AND "and" AND "NOT" AND "OR" AND five', query
  end

  def test_removes_paren_literals
    url = @engine.query_url(:query => "cancer)", :sort => "date_desc")

    query_params = CGI.parse( URI.parse(url).query )

    assert_equal ["cancer "], query_params["query"]
  end

  def test_removes_question_marks
    # who knows why, ebsco doesn't like question marks even inside
    # quoted phrases, some special char to ebsco.
    url = @engine.query_url(:query => "cancer?", :sort => "date_desc")
    query_params = CGI.parse( URI.parse(url).query )
    assert_equal ["cancer "], query_params["query"]

    url = @engine.query_url(:query => '"cancer?"', :sort => "date_desc")
    query_params = CGI.parse( URI.parse(url).query )
    assert_equal ['"cancer "'], query_params["query"]
  end

  def test_removes_brackets
    # Ebsco don't like brackets either
    url = @engine.query_url(:query => "[cancer]")
    query_params = CGI.parse( URI.parse(url).query )
    assert_equal [" cancer "], query_params["query"]
  end

  def test_has_http_timeout_set
    assert_equal BentoSearch::EbscoHostEngine::HttpTimeout, @engine.http_client.receive_timeout
    assert_equal BentoSearch::EbscoHostEngine::HttpTimeout, @engine.http_client.send_timeout
    assert_equal BentoSearch::EbscoHostEngine::HttpTimeout, @engine.http_client.connect_timeout
  end


  test_with_cassette("live search smoke test", :ebscohost) do

    results = @engine.search(:query => "cancer")

    assert_present results
    assert ! results.failed?

    first = results.first

    assert_present first.title
    assert_present first.authors
    assert_present first.year

    assert_present first.format
    assert_present first.format_str

    assert_present first.language_code
    assert_present first.language_str

    assert_present first.unique_id
    # db name, colon, accession number.
    assert_match /.+\:.+/, first.unique_id
  end

  test_with_cassette("get_info", :ebscohost) do
    xml = @engine.get_info

    assert_present xml

    assert_present xml.xpath("./info/dbInfo/db")
  end

  test_with_cassette("error bad password", :ebscohost) do
    error_engine = BentoSearch::EbscoHostEngine.new(
      :profile_id       => "bad",
      :profile_password => "bad",
      :databases        => @@dbs_to_test
      )

    results = error_engine.search(:query => "cancer")
    assert results.failed?
    assert_present results.error[:error_info]
  end


  test_with_cassette("error bad db", :ebscohost) do
    error_engine = BentoSearch::EbscoHostEngine.new(
      :profile_id => @@profile_id,
      :profile_password => @@profile_pwd,
      :databases => ["bad", "does_not_exist"]
    )

    results = error_engine.search(:query => "cancer")
    assert results.failed?
    assert_present results.error[:error_info]

  end

  test_with_cassette("fulltext info", :ebscohost) do
    # We count on SOME records from first 10 for this query having fulltext,
    # if you need to re-record VCR cassette and this query doesn't work
    # for that anymore, then pick a different query.
    results = @engine.search("cancer")

    results_with_fulltext = results.find_all {|r| r.custom_data["fulltext_formats"] }

    assert_present results_with_fulltext

    results_with_fulltext.each do |record|
      array = record.custom_data["fulltext_formats"]
      # it's an array
      assert_kind_of Array, array
      # who's only legal values are P, T, and C, the EBSCO vocab for formats.
      assert_equal array.length, array.find_all {|v| %w{P C T}.include?(v)}.length

      assert record.link_is_fulltext?, "#link_is_fulltext set"
    end

  end

  test_with_cassette("live book example", :ebscohost) do
    # We keep adjusting the EBSCOHost heuristics for guessing format,
    # and causing regressions, this test guards against them.

    # This particular example from RILM is a book, but
    # is getting listed as a book chapter, sort of.

    engine = BentoSearch::EbscoHostEngine.new( @config.merge(:databases => ["rih"]) )

    results = engine.search('"Funk: The music, the people, and the rhythm of the one"', :per_page => 1)

    result = results.first

    assert_equal "Book", result.format
    assert_equal "St. Martin's Press", result.publisher
    assert_equal "1996", result.year

    assert_blank result.source_title
  end

  test_with_cassette("live pathological book_item example", :ebscohost) do
    # this guy from RILM has really crappy metadata on EBSCO,
    # but we still want to detect it as a book_item, not a book.

    a = 'Heidegger and the management of the Haymarket Opera, 1713-1717'

    engine = BentoSearch::EbscoHostEngine.new( @config.merge(:databases => ["rih"]) )
    results = engine.search('"Heidegger and the management of the Haymarket Opera, 1713-1717"')
    result = results.first

    assert_equal :book_item, result.format


    # for reasons I can't figure out, weird encoding in the hyphen makes us
    # test start_with instead
    assert result.title.starts_with?("Heidegger and the management of the Haymarket Opera, 1713")
    assert result.source_title.starts_with?("Opera remade (1700")
  end

  test_with_cassette("dissertation example", :ebscohost) do
    # yeah, all the weird ones are from RILM
    engine = BentoSearch::EbscoHostEngine.new( @config.merge(:databases => ["rih"]) )

    results = engine.search('"Research into free jazz in France, 1960-1975"')
    result = results.first

    assert_equal "Research into free jazz in France, 1960-1975", result.title
    assert_equal :dissertation, result.format
  end

  test_with_cassette("another dissertation", :ebscohost) do
    # yeah, all the weird edge cases that make good tests are from RILM, it's
    # got weird data.

    engine = BentoSearch::EbscoHostEngine.new( @config.merge(:databases => ["rih"]) )
    results = engine.search('"Machine gun voices: Bandits, favelas, and utopia in Brazilian funk"')
    result = results.first

    assert_equal :dissertation, result.format
    assert_equal "Machine gun voices: Bandits, favelas, and utopia in Brazilian funk", result.title
  end

  test_with_cassette("live #get(identifier) round trip", :ebscohost) do
    results = @engine.search("cancer")

    assert (! results.failed?)

    item = @engine.get( results.first.unique_id )

    assert_not_nil  item
    assert_kind_of  BentoSearch::ResultItem, item
  end

  test_with_cassette("live get(id) with no results raises", :ebscohost) do
    assert_raise(BentoSearch::NotFound) do
      results = @engine.get("a9h:bar")
    end
  end

  test_with_cassette("live get(id) on bad db raises", :ebscohost) do
    assert_raise(Exception) do
      results = @engine.get("badbad:bar")
    end
  end

  test_with_cassette("multi-field author title", :ebscohost) do
    results = @engine.search(:query => {:title => '"Reflections on the History of Debt Resistance"',
                              :author => "Caffentzis"})

    assert ! results.failed?

    assert_equal 1, results.total_items

    result = results.first

    assert_equal "10.1215/00382876-2345315", result.doi
  end

  test_with_cassette("multi-field citation numbers", :ebscohost) do
    results = @engine.search(:query => {
      :issn       => "00382876",
      :volume     => "112",
      :issue      => "4",
      :start_page => "824"
    })

    assert ! results.failed?
    
    assert_equal 1, results.total_items

    result = results.first

    assert_equal "10.1215/00382876-2345315", result.doi
  end


  test("illegal arg for get with id with no colon") do
    assert_raise ArgumentError do
      @engine.get("no_colon_in_here")
    end
  end

  test_with_cassette("RILM record with ISSN in <jid> element", :ebscohost) do
    engine = BentoSearch::EbscoHostEngine.new( @config.merge(:databases => ["rih"]) )
    results = engine.search('"Schumann\'s Dichterliebe and early Romantic poetics: Fragmentation of desire"')

    assert_present results

    first = results.first

    assert_present first.issn
  end

  test_with_cassette("affiliation search", :ebscohost) do
    results = @engine.search('"johns hopkins"', :semantic_search_field => :author_affiliation)

    assert ! results.failed?

    assert_present results
  end



end
