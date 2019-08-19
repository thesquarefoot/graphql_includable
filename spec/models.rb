class Client < ActiveRecord::Base
  belongs_to :user
  has_many :client_tasks
  has_many :tasks, through: :client_tasks
end

class User < ActiveRecord::Base
  has_many :clients
end

class ClientTask < ActiveRecord::Base
  belongs_to :client
  belongs_to :task

  def completed
    super || false
  end
end

class Task < ActiveRecord::Base
  has_many :clients
  belongs_to :location
end

class Location < ActiveRecord::Base
end