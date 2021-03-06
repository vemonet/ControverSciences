class MyItemsController < ApplicationController
  before_action :logged_in_user, only: [:items, :votes]

  def items
    @summaries = Summary.select(:id, :timeline_id, :content, :balance, :public ).where( user_id: current_user.id)
    @comments = Comment.select(:id, :timeline_id, :reference_id,
                               :title_markdown, :public, :f_0_balance,
                               :f_1_balance, :f_2_balance, :f_3_balance,
                               :f_4_balance, :f_5_balance, :f_6_balance ,
                               :f_7_balance ).where( user_id: current_user.id)
    if params[:private] == "true"
      @summaries = @summaries.where(public: false)
      @comments = @comments.where(public: false)
      @references = []
      @timelines = []
      @frames = []
    else
      @references = Reference.select(:id, :slug, :timeline_id, :title).where( user_id: current_user.id)
      @timelines = Timeline.includes(:tags).select(:id, :slug, :name, :private).where( user_id: current_user.id).where.not(private: true)
      @frames = Frame.select(:id, :name_markdown, :balance).where( user_id: current_user.id ).where.not( timeline_id: @timelines.map{|tim| tim.id} )
    end
  end

  def votes
    @votes = Vote.where( user_id: current_user.id)
    @credits = Credit.where( user_id: current_user.id)
    @frame_credits = FrameCredit.where( user_id: current_user.id)
  end

end
