require 'confstruct'

module BentoSearch
  class Error < ::StandardError ; end
end 

require "bento_search/engine"
require 'bento_search/routes'

require 'bento_search/util'

# ugh, sorry:
require File.dirname(__FILE__) + '/../app/models/bento_search/registrar'

# Crazy workaround to the fact that some versions of Hashie::Mash,
# when used with SafeAssignment as Confstruct does, don't let
# you use :id as a key. 
# https://github.com/intridea/hashie/issues/290
# We fix by removing the unused method with vary hacky meta programming
# sorry. 
require 'hashie/mash'
if Hashie::Mash.instance_methods(false).include?(:id)
  Hashie::Mash.send(:remove_method, :id)
end


module BentoSearch      
  def self.global_registrar
    @@global_registrar ||= BentoSearch::Registrar.new
  end
       
  # See BentoSearch::Registrar#register_engine, this is a
  # default global registrar. 
  def self.register_engine(id, data = nil, &block)
    global_registrar.register_engine(id, data, &block)    
  end
  
  def self.get_engine(id)
    global_registrar.get_engine(id)
  end
      
  # Mostly just used for testing
  def self.reset_engine_registrations!
    global_registrar.reset_engine_registrations!
  end

end


