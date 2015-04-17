class Review < ActiveRecord::Base
  include ModelsModule

  REVIEW_TYPES = %w(6-Month 12-Month 18-Month 24-Month)

  attr_accessible \
      :associate_consultant_id,
      :feedback_deadline,
      :review_date,
      :review_type

  validates :review_type, :presence => true,
            :inclusion => { :in => REVIEW_TYPES }
  validates :associate_consultant_id, :presence => true
  validates :associate_consultant_id, :uniqueness => {:scope => [:review_type]}
  validates :feedback_deadline, :presence => true
  validates :review_date, :presence => true

  belongs_to :associate_consultant
  has_one    :reviewee, through: :associate_consultant, source: :user

  has_many   :feedbacks,        :dependent => :destroy
  has_many   :self_assessments, :dependent => :destroy
  has_many   :invitations,      :dependent => :destroy

  after_validation :check_errors
  after_initialize :set_new_review_format

  def self.default_load
    self.includes({ associate_consultant: :user },
                  { associate_consultant: :reviewing_group })
  end

  def self.create_default_reviews(associate, reviews = [])
    [6, 12, 18, 24].each do |n|
      review_params = {
        associate_consultant_id: associate.id,
        review_type: "#{n}-Month",
        review_date: associate.program_start_date + n.months,
        feedback_deadline: associate.program_start_date + n.months - 7.days
      }

      reviews << Review.create(review_params)
    end
    reviews
  end

  def in_the_future?
    self.review_date > Date.today
  end

  def questions
    @questions ||= QuestionBuilder.build(associate_consultant)
  end

  def headings
    if self.new_review_format
      Review::Heading::NEW_FORMAT
    else
      Review::Heading::OLD_FORMAT
    end
  end

  def heading_title(heading)
    if questions[heading].present?
      questions[heading].title
    end
  end

  def description(heading)
    result = ""
    if questions[heading].present?
      if heading != "Comments"
       result += "<p>Here are some questions to consider... </p>"
      end
      result += questions[heading].description
    end
    result
  end

  def fields_for_heading(heading)
    if questions[heading].present?
      questions[heading].fields
    else
      []
    end
  end

  def has_scale(heading)
    scale_field(heading).present?
  end

  def scale_field(heading)
    if questions[heading].present?
      questions[heading].scale_field
    else
      nil
    end
  end

  def to_s
    self.pretty_print_with(nil)
  end

  def pretty_print_with(user)
    if user.present? && user == self.reviewee
      "Your #{review_type} Review"
    else
      "#{self.reviewee.name}'s #{review_type} Review"
    end
  end

  def has_existing_feedbacks?
    feedbacks.size > 0
  end

  def upcoming?
    self.review_date.present? && in_next_six_months?
  end

  private

  def check_errors
    update_errors(self)
  end

  def in_next_six_months?
    self.review_date.between?(Date.today, Date.today + 6.months)
  end

  def set_new_review_format
    self.new_review_format = true if new_record?
  end
end