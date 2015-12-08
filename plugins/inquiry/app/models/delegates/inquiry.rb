class Delegates::Inquiry

  delegate :description, :payload, :aasm_state, :requester, to: :real_inquiry

  def initialize inquiry
    @real_inquiry = inquiry
  end

  private
  attr_reader :real_inquiry

end