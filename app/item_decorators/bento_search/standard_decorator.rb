module BentoSearch
  class StandardDecorator < DecoratorBase
    
    
    # convenience method that returns true if any of the keys
    # are #present?  eg
    # item.any_present?(:source_title, :authors) === item.source_title.present? || item.authors.present?
    #
    # note present? is false for nil, empty strings, and empty arrays. 
    def any_present?(*keys)
      keys.each do |key|
        return true if self.send(key).present?
      end
      return false
    end
    
    # How to display a BentoSearch::Author object as a name    
    def author_display(author)
      if (author.first.present? && author.last.present?)
        "#{author.last}, #{author.first.slice(0,1)}"
      elsif author.display.present?
        author.display
      elsif author.last.present?
        author.last
      else
        nil
      end
    end
    
    # display multiple authors, with HTML markup, returns html_safe string.
    # experimentally trying this as a decorator helper method rather
    # than a view partial, not sure which is best. 
    #
    # Will limit to first three authors, with elipsis if there are more.
    #
    # Over-ride if you want to format authors names differently, or
    # show more or less than first 3, etc. 
    def render_authors_list
      parts = []
      
      first_three = self.authors.slice(0,3) 
          
      first_three.each_with_index do |author, index|
        parts << _h.content_tag("span", :class => "author") do
          self.author_display(author)
        end
        if (index + 1) < first_three.length
          parts << "; "
        end      
      end
      
      if self.authors.length > 3
        parts << I18n.t("bento_search.authors_et_al")
      end
      
      return _h.safe_join(parts, "")
    end
    
    # Returns source publication name OR publisher, along with volume/issue/pages
    # if present, all wrapped in various tags and labels. Returns html_safe
    # with tags. 
    #
    # Experiment to do this in a decorator helper instead of a partial template,
    # might be more convenient we think. 
    def render_source_info
      parts = []
      
      if self.source_title.present?
        parts << _h.content_tag("span", I18n.t("bento_search.published_in"), :class=> "source_label")        
        parts << _h.content_tag("span", self.source_title, :class => "source_title")  
        parts << ". "
      elsif self.publisher.present?
        parts << _h.content_tag("span", self.publisher, :class => "publisher")
        parts << ". "
      end
      
      if text = self.render_citation_details
        parts << text << "."
      end
          
      return _h.safe_join(parts, "")
    end
    
    # if enough info is present that there will be non-empty render_source_info
    # should be over-ridden to match display_source_info
    def has_source_info?
      self.any_present?(:source_title, :publisher, :start_page)
    end
    
    # Put together title and subtitle if neccesary. 
    def complete_title
      t = self.title
      if self.subtitle
        t = safe_join([t, ": ", self.subtitle], "")        
      end
      
      if t.blank?
        t = I18n.translate("bento_search.missing_title")
      end
      
      return t
    end
    
    
    
    # volume, issue, and page numbers. With prefixed labels from I18n. 
    # That's it.
    def render_citation_details
      # \u00A0 is unicode non-breaking space to keep labels and values from
      # getting separated. 
      result_elements = []
      
      result_elements.push("#{I18n.t('bento_search.volume')}\u00A0#{volume}") if volume.present?
      
      result_elements.push("#{I18n.t('bento_search.issue')}\u00A0#{issue}") if issue.present?
            
      if (! start_page.blank?) && (! end_page.blank?)
        result_elements.push html_escape "#{I18n.t('bento_search.pages')}\u00A0#{start_page}-#{end_page}"
      elsif ! start_page.blank?
        result_elements.push html_escape "#{I18n.t('bento_search.page')}\u00A0#{start_page}"
      end
                  
      return nil if result_elements.empty?
      
      return result_elements.join(", ").html_safe
    end
    
        # A display method, this is like #langauge_str, but will be nil if
    # the language_code matches the current default locale, used
    # for printing language only when not "English" normally. 
    #
    #(Sorry, will be 'Spanish' never 'Espa~nol", we don't
    # have a data source for language names in other languages right now. )
    def display_language
      return nil unless self.language_code
      
      default = I18n.locale.try {|l| l.to_s.gsub(/\-.*$/, '')} || "en" 
      
      this_doc = self.language_obj.try(:iso_639_1)
      
      return nil if this_doc == default
      
      self.language_str
    end
    
    # format string to display to user. Uses #format_str if present,
    # otherwise finds an i18n label from #format. Returns nil if none
    # available. 
    def display_format      
      value = self.format_str || 
        I18n.t(self.format, :scope => [:bento_search, :format], :default => self.format.to_s.titleize)
        
      return value.blank? ? nil : value        
    end

    
    ###################
    # turn into a representative OpenURL
    #
    #  use to_openurl_kev to go straight there, 
    #  or to_openurl to get a ruby OpenURL object.
    ###################
    

    # Returns a ruby OpenURL::ContextObject (NISO Z39.88).  
    # or nil if none avail. 
    def to_openurl
      return nil if openurl_disabled
      
      BentoSearch::OpenurlCreator.new(self).to_openurl
    end
    
    # Returns a kev encoded openurl, that is a URL query string representing
    # openurl. Or nil if none available. 
    #
    # Right now just calls #to_openurl.kev, can conceivably
    # be modified to do things more efficient, without a ruby openurl
    # obj. Law of demeter, represent.     
    def to_openurl_kev
      to_openurl.try(:kev)      
    end
    
  end
end
