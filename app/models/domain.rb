class Domain < ActiveRecord::Base
  
  has_many :users do
    def limited_list(limit = 10)
      all(:limit => limit)
    end
  end
  
end
