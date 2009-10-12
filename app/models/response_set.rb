class ResponseSet < ActiveRecord::Base
  include TinyCode
  
  # Associations
  belongs_to :survey
  belongs_to :user
  has_many :responses, :dependent => :destroy
  
  # Validations
  validates_presence_of :survey_id
  validates_associated :responses
  
  # Attributes
  attr_protected :completed_at
  attr_accessor :current_section_id

  # Callbacks
  after_update :save_responses
  
  # Instance methods
  def initialize(*args)
    super(*args)
    default_args
  end
  
  def default_args
    self.started_at ||= Time.now
    self.access_code = ResponseSet.make_tiny_code
  end
  
  def response_for(question_id, answer_id, group = nil)
    response_group = group.nil? ? nil : group.to_s # for PostgreSql 8.3 compatibility - response_group is a string
    # found = responses.find_by_question_id_and_answer_id_and_response_group(question_id, answer_id, response_group)
    found = responses.detect{|r| r.question_id == question_id && r.answer_id == answer_id && r.response_group == response_group}
    found.blank? ? responses.new(:question_id => question_id, :answer_id => answer_id, :response_group => response_group) : found
  end
  
  def clear_responses
    question_ids = Question.find_all_by_survey_section_id(current_section_id).map(&:id)
    # logger.warn "responses: #{responses.inspect}\n"
    responses.select{|r| question_ids.include? r.question_id}.map(&:destroy)
    responses.reload
    # logger.warn "responses: #{responses.inspect}\n"
  end
  
  # "responses"=>{
  #string   "6"=>{"question_id"=>"6", "20"=>{"string_value"=>"saf"}}, 
  #text   "7"=>{"question_id"=>"7", "21"=>{"text_value"=>""}}, 
  #radio+txt   "1"=>{"question_id"=>"1", "answer_id"=>"1", "4"=>{"string_value"=>""}}, 
  #radio   "2"=>{"answer_id"=>"6"}, 
  #radio   "3"=>{"answer_id"=>"10"}, 
  #check   "4"=>{"question_id"=>"4", "answer_id"=>"15"}, 
  #check+txt   "5"=>{"question_id"=>"5", "16"=>{"selected"=>"1"}, "19"=>{"string_value"=>""}}
  #   },
  # "survey_code"=>"test_survey", 
  # "commit"=>"Next Section (Utensiles and you!) >>", 
  # "authenticity_token"=>"8bee21081eea820ab1c658358c0baaa2e46de5d1", 
  # "_method"=>"put", 
  # "action"=>"update", 
  # "controller"=>"app", 
  # "response_set_code"=>"T2x8HhCQej", 
  # "section"=>"2"

  def response_attributes=(response_attributes)
    response_attributes.each do |question_id, responses_hash|
      # Response.delete_all(["response_set_id =? AND question_id =?", self.id, question_id])
      if (answer_id = responses_hash[:answer_id]) 
        if (!responses_hash[:answer_id].empty?) # Dropdowns return answer id but have an empty value if they are not set... ignoring those.
          #radio or dropdown - only one response
          responses.build({:question_id => question_id, :answer_id => answer_id}.merge(responses_hash[answer_id] || {}))
        end
      else
        #possibly multiples responses - unresponded radios end up here too
        # we use the variable question_id, not the "question_id" in the response_hash
        responses_hash.delete_if{|k,v| k == "question_id"}.each do |answer_id, response_hash|
          unless response_hash.delete_if{|k,v| v.blank?}.empty?
            responses.build({:question_id => question_id, :answer_id => answer_id}.merge(response_hash))
          end
        end
      end
    end
  end
  
  # "24"=>{
  #   "0"=>{"response_group"=>"0", "question_id"=>"24", "answer_id"=>"172"}, "1"=>{"response_group"=>"1", "question_id"=>"24", "answer_id"=>"173"}, 
  #   "2"=>{"response_group"=>"2", "question_id"=>"24", "answer_id"=>""}, "3"=>{"response_group"=>"3", "question_id"=>"24", "answer_id"=>""}, 
  #   "4"=>{"response_group"=>"4", "question_id"=>"24", "answer_id"=>""}},
 #  where "24" is the question id
 
 # Some other examples:
 # "25"=>{
 # "0"=>{"response_group"=>"0", "question_id"=>"25", "179"=>{"string_value"=>"camry"}}, 
 # "1"=>{"response_group"=>"1", "question_id"=>"25", "179"=>{"string_value"=>"f150"}},
 #  "2"=>{"response_group"=>"2", "question_id"=>"25", "179"=>{"string_value"=>""}}, 
 #  "3"=>{"response_group"=>"3", "question_id"=>"25", "179"=>{"string_value"=>""}}, 
 #  "4"=>{"response_group"=>"4", "question_id"=>"25", "179"=>{"string_value"=>""}}}, 
 # 
 # "26"=>{
 # "0"=>{"response_group"=>"0", "question_id"=>"26", "180"=>{"string_value"=>"1999"}},
 #  "1"=>{"response_group"=>"1", "question_id"=>"26", "180"=>{"string_value"=>"2004"}}, 
 #  "2"=>{"response_group"=>"2", "question_id"=>"26", "180"=>{"string_value"=>""}}, 
 #  "3"=>{"response_group"=>"3", "question_id"=>"26", "180"=>{"string_value"=>""}}, 
 #  "4"=>{"response_group"=>"4", "question_id"=>"26", "180"=>{"string_value"=>""}}}, 
 # 
 # "27"=>{
 # "0"=>{"182"=>{"integer_value"=>""}, "response_group"=>"0", "question_id"=>"27", "181"=>{"string_value"=>""}}, 
 # "1"=>{"182"=>{"integer_value"=>""}, "response_group"=>"1", "question_id"=>"27", "181"=>{"string_value"=>""}},
 #  "2"=>{"182"=>{"integer_value"=>""}, "response_group"=>"2", "question_id"=>"27", "181"=>{"string_value"=>""}}, 
 #  "3"=>{"182"=>{"integer_value"=>""}, "response_group"=>"3", "question_id"=>"27", "181"=>{"string_value"=>""}}, 
 #  "4"=>{"182"=>{"integer_value"=>""}, "response_group"=>"4", "question_id"=>"27", "181"=>{"string_value"=>""}}}},
 
 # 0,1,2,3,4 are the response group numbers
 # and anything else in the response group hash is handled normally 
  
  # method to process responses in response groups
  def response_group_attributes=(response_attributes)
    response_attributes.each do |question_id, responses_group_hash|
      # Response.delete_all(["response_set_id =? AND question_id =?", self.id, question_id])
      responses_group_hash.each do |response_group_number, group_hash|
        if (answer_id = group_hash[:answer_id]) # if group_hash has an answer_id key we treat it differently 
          if (!group_hash[:answer_id].empty?) # dropdowns return empty values in answer_ids if they are not selected
            #radio or dropdown - only one response
            responses.build({:question_id => question_id, :answer_id => answer_id, :response_group => response_group_number}.merge(group_hash[answer_id] || {}))
          end
        else
          #possibly multiples responses - unresponded radios end up here too
          # we use the variable question_id in the key, not the "question_id" in the response_hash... same with response_group key
          group_hash.delete_if{|k,v| (k == "question_id") or (k == "response_group")}.each do |answer_id, inner_hash|
            unless inner_hash.delete_if{|k,v| v.blank?}.empty?
              responses.build({:question_id => question_id, :answer_id => answer_id, :response_group => response_group_number}.merge(inner_hash))
            end
          end
        end
        
      end
    end
  end
  
  def find_response(answer_id)
     self.responses.find_by_answer_id(answer_id)
  end
  
  def save_responses
    responses.each do |response|
      response.save(false)
    end
  end

  # ResponseSet has an awareness of its internal state
  def empty?
    self.responses.empty?
  end

  def complete!
    self.completed_at = Time.now
  end
  
  def has_answered_question?(question)
   !has_not_answered_question?(question)
  end
  
  def has_not_answered_question?(question)
    self.responses.find_all_by_question_id(question.id).empty?
  end
    
  # Returns the number of response groups (count of group responses enterted) for this question group
  def count_group_responses(questions)
    questions.map{|q| responses.select{|r| r.question_id == q.id && !r.response_group.nil?}.size }.max
  end
  
  def unanswered_dependencies
    dependencies.select{|d| d.met?(self) and self.has_not_answered_question?(d.question)}.map(&:question)
  end
  def all_dependencies
    arr = dependencies.partition{|d| d.met?(self) }
    {:show => arr[0].map{|d| "question_#{d.question_id}"}, :hide => arr[1].map{|d| "question_#{d.question_id}"}}
  end
  
  protected
  
  def dependencies
    question_ids = Question.find_all_by_survey_section_id(current_section_id).map(&:id)
    Dependency.depending_on_questions(question_ids)
  end
end
