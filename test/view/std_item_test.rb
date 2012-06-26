require 'test_helper'

class StdItemTest < ActionView::TestCase
    
  
  def test_title_only_item
    item = BentoSearch::ResultItem.new(:title => "Some Title")
        
    render "bento_search/std_item", :item => item
    
    assert_select("div.bento_item", 1) do    
      assert_select "h2", item.title do 
        assert_select "a", false
      end
      # No author/title/etc rows, cause we don't have data
      assert_select "ul.bento_item_authors", false
      assert_select ".bento_item_key_meta", false
      
      assert_select ".bento_item_row", false
      assert_select ".published_in", false
    end  
    
    # No other links in this test
    assert_select(".bento_item_other_links", 0)
  end
  
  def test_complete_article_item
    hash = {}
    hash[:title] = "Some Title"   
    hash[:link] = "http://example.org/1"
    hash[:journal_title] = "Journal of Invalid Results"
    hash[:volume] = "10"
    hash[:issue] = "1"
    hash[:start_page] = "101"
    hash[:end_page] = "120"
    hash[:format] = "MusicRecording"
    item = BentoSearch::ResultItem.new( hash )
    item.authors.push BentoSearch::Author.new(:display => "Smith, J.")
    
    render "bento_search/std_item", :item => item
    
    assert_select("div.bento_item", 1) do    
      assert_select "h2", item.title do |h2|
        assert_select "a[href='#{item.link}']"
      end
      
      # Make sure we have the items for complete citation
      

      assert_select "ul.bento_item_authors"
      assert_select ".bento_item_about" , 
        Regexp.new(Regexp.escape( I18n.t(item.format, :scope => [:bento_search, :format])   ))
        
      
      assert_select ".bento_item_row"
      assert_select ".published_in"
    end              
    
  end
  
  def test_degrades_format_to_titleize
    item = BentoSearch::ResultItem.new(:title => "Foo", :format => :bar)
    
    render "bento_search/std_item", :item => item
    
    assert_select(".bento_item_about", /Bar/)
  end
  
  def test_no_title_link
    item = BentoSearch::ResultItem.new(:title => "Foo")  
    
    render "bento_search/std_item", :item => item
    
    assert_select("h2.bento_item_title") do
      assert_select("a", 0)
    end    
  end
  
  def test_other_links
    item = BentoSearch::ResultItem.new(:title => "Foo")
    item.other_links << BentoSearch::Link.new(:label => "A Link", 
                          :url => "http://example.org/", 
                          :rel => "http://example.org/rel", 
                          :style_classes => [:one, :two])
    
    render "bento_search/std_item", :item => item
    
    assert_select(".bento_item_other_links", 1) do
      assert_select("a.bento_search_link.one.two", :text => "A Link", 
        :attributes => 
          {:rel  => "http://example.org/rel",
           :href => "http://example.org/"})
    end
    
  end
  
  
end
