class Racer
include ActiveModel::Model
attr_accessor :id, :number, :first_name, :last_name, :gender, :group, :secs

def self.mongo_client
	Mongoid::Clients.default
end

def self.collection
	self.mongo_client['racers']
end

def self.all(prototype={}, sort={:num=>1}, skip=0, limit=nil) 
    #map internal :population term to :pop document term
    tmp = {} #hash needs to stay in stable order provided
    sort.each {|k,v| 
      k = k.to_sym==:num ? :number : k.to_sym
      tmp[k] = v  if [:group,:first_name, :last_name, :gender,:secs,:number].include?(k)
    }
    sort=tmp

    #convert to keys and then eliminate any properties not of interest
    prototype=prototype.symbolize_keys.slice(:_id, :group,:gender,:first_name,:last_name,:number) if !prototype.nil?

    Rails.logger.debug {"getting all zips, prototype=#{prototype}, sort=#{sort}, skip=#{skip}, limit=#{limit}"}

    result=collection.find(prototype)
          .projection({number:true, first_name:true, last_name:true, gender:true,group:true,secs:true})
          .sort(sort)
          .skip(skip)
    result=result.limit(limit) if !limit.nil?

    return result
end

def initialize(params={})
@id=params[:_id].nil? ? params[:id] : params[:_id].to_s 
@number=params[:number].to_i 
@first_name=params[:first_name] 
@last_name=params[:last_name]
@gender=params[:gender]
@group=params[:group]
@secs=params[:secs].to_i
end

def self.find id
result=collection.find(:_id=>BSON::ObjectId.from_string(id))
.projection({number:true, first_name:true, last_name:true, gender:true, group:true,secs:true})
.first
return result.nil? ? nil : Racer.new(result)
end

def save
result=self.class.collection
.insert_one(_id:@id, number:@number, first_name:@first_name, last_name:@last_name, gender:@gender,group:@group,secs:@secs)
@id=result.inserted_id.to_s#store just the string form of the _id
end

def update(params) 
	@number=params[:number].to_i
	@first_name=params[:first_name] 
	@last_name=params[:last_name] 
	@secs=params[:secs].to_i
	@group=params[:group]
	@gender=params[:gender]

    params.slice!(:number, :first_name, :last_name, :gender, :group, :secs)

    # self.class.collection
		  #   .find({first_name:@first_name,last_name:@last_name})
		  #   .update_one(:$set=>params)

		  self.class.collection
		  .find(_id: BSON::ObjectId.from_string(@id))
		  .update_one(params)

		    # pp self.class.collection
		    # .find(@first_name)
		    # .first
end

def destroy
    self.class.collection
              .find(_id: BSON::ObjectId.from_string(@id))
              .delete_one   
end  

def self.paginate(params)
    Rails.logger.debug("paginate(#{params})")
    page=(params[:page] || 1).to_i
    limit=(params[:per_page] || 30).to_i
    skip=(page-1)*limit
    sort=params[:sort] ||= {}
    #get the associated page of Zips -- eagerly convert doc to Zip
    racers=[]
    all(params, sort, skip, limit).each do |doc|
      racers << Racer.new(doc)
    end

    #get a count of all documents in the collection
    total=all(params, sort, 0, 1).count
    
    WillPaginate::Collection.create(page, limit, total) do |pager|
      pager.replace(racers)
    end    
end

def persisted? 
  !@id.nil?
end

def created_at 
  nil
end

def updated_at
  nil
end


end