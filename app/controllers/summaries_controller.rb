class SummariesController < ApplicationController
  before_action :logged_in_user, only: [:new, :create, :edit, :update, :destroy]

  def new
    summary = Summary.find_by( user_id: current_user.id, timeline_id: params[:timeline_id] )
    if summary
      redirect_to edit_summary_path( id: summary.id )
    else
      @summary = Summary.new
      if params[:parent_id]
        @parent = Summary.find(params[:parent_id])
        @summary.content = @parent.content
        @summary.timeline_id = @parent.timeline_id
      else
        @summary.timeline_id = params[:timeline_id]
      end
      @list = Reference.where( timeline_id: @summary.timeline_id ).pluck( :title, :id )
      @tim_list = Timeline.where( id: Edge.where(timeline_id:
                                                     @summary.timeline_id ).pluck(:target) ).pluck( :name, :id )
    end
  end

  def create
    @summary = Summary.new( timeline_id: summary_params[:timeline_id],
                            content: summary_params[:content],
                            public: summary_params[:public])
    if summary_params[:has_picture] == 'true' && summary_params[:delete_picture] == 'false'
      @summary.figure_id = Figure.order( :created_at ).where( user_id: current_user.id,
                                                              timeline_id: @summary.timeline_id ).last.id
      @summary.caption = summary_params[:caption]
    end
    @summary.user_id = current_user.id
    parent_id = params[:summary][:parent_id]
    if @summary.save_with_markdown
      if parent_id
        SummaryRelationship.create(parent_id: parent_id, child_id: @summary.id)
      end
      flash[:success] = "Synthèse enregistrée."
      redirect_to summaries_path( filter: "mine", timeline_id: @summary.timeline_id )
    else
      @list = Reference.where( timeline_id: summary_params[:timeline_id] ).pluck( :title, :id )
      @tim_list = Timeline.where( id: Edge.where(timeline_id:
                                                     summary_params[:timeline_id] ).pluck(:target) ).pluck( :name, :id )
      if parent_id
        @parent = Summary.find( parent_id )
      end
      render 'new'
    end
  end

  def edit
    @summary = Summary.find( params[:id] )
    @list = Reference.where( timeline_id: @summary.timeline_id ).pluck( :title, :id )
    @tim_list = Timeline.where( id: Edge.where(timeline_id:
                                                   @summary.timeline_id ).pluck(:target) ).pluck( :name, :id )
  end

  def update
    @summary = Summary.find( params[:id] )
    @my_summary = Summary.find( params[:id] )
    if @summary.user_id == current_user.id || current_user.admin
      @summary.content = summary_params[:content]
      @summary.public = summary_params[:public]
      @summary.caption = summary_params[:caption]
      if summary_params[:delete_picture] == 'true'
        @summary.figure_id = nil
      elsif summary_params[:has_picture] == 'true'
        @summary.figure_id = Figure.order( :created_at ).where( user_id: current_user.id,
                                                                timeline_id: @summary.timeline_id ).last.id
      end
      if @summary.update_with_markdown( timeline_url( @summary.timeline_id ) )
        flash[:success] = "Synthèse modifiée."
        redirect_to @summary
      else
        @list = Reference.where( timeline_id: @summary.timeline_id ).pluck( :title, :id )
        @tim_list = Timeline.where( id: Edge.where(timeline_id:
                                                       @summary.timeline_id ).pluck(:target) ).pluck( :name, :id )
        render 'edit'
      end
    else
      redirect_to @summary
    end
  end

  def show
    @summary = Summary.select( :id, :user_id, :timeline_id,
                               :markdown, :balance, :best, :figure_id, :caption_markdown,
                               :created_at
    ).find(params[:id])
    if logged_in?
      @improve = Summary.where(user_id: current_user.id, timeline_id: @summary.timeline_id ).count == 1 ? false : true
    end
    @timeline = Timeline.select(:id, :nb_summaries, :name ).find( @summary.timeline_id )
  end
  
  def index
    @timeline = Timeline.select(:id, :nb_summaries, :name ).find( params[:timeline_id] )
    if logged_in?
      user_id = current_user.id
      @my_credits = Credit.where( user_id: user_id, timeline_id: params[:timeline_id] ).sum( :value )
      visit = VisiteTimeline.find_by( user_id: user_id, timeline_id: params[:timeline_id] )
      if visit
        visit.update( updated_at: Time.zone.now )
      else
        VisiteTimeline.create( user_id: user_id, timeline_id: params[:timeline_id] )
      end
      @favorites = Credit.where( user_id: user_id, timeline_id: params[:timeline_id] ).count
      @improve = Summary.where(user_id: user_id, timeline_id: params[:timeline_id] ).count == 1 ? false : true
    else
      user_id = nil
    end
    if params[:filter] == "my-vote"
      summary_ids = Credit.where( user_id: user_id, timeline_id: params[:timeline_id] ).pluck( :summary_id )
      @summaries = Summary.where( id: summary_ids, public: true ).page(params[:page]).per(10)
    elsif params[:filter] == "mine"
      @summaries = Summary.where( user_id: user_id, timeline_id: params[:timeline_id] ).page(params[:page]).per(10)
    elsif logged_in?
      if params[:seed]
        @seed = params[:seed]
      else
        @seed = rand
      end
      Summary.connection.execute("select setseed(#{@seed})")
      @summaries = Summary.where(
          timeline_id: params[:timeline_id], public: true ).where.not(
          user_id: user_id).order('random()').page(params[:page]).per(5)
    else
      if !params[:sort].nil?
        if !params[:order].nil?
          @summaries = Summary.order(params[:sort].to_sym => params[:order].to_sym).where(
              timeline_id: params[:timeline_id], public: true).where.not(
              user_id: user_id).page(params[:page]).per(5)
        else
          @summaries = Summary.order(params[:sort].to_sym => :desc).where(
              timeline_id: params[:timeline_id], public: true).where.not(
              user_id: user_id).page(params[:page]).per(5)
        end
      else
        if !params[:order].nil?
          @summaries = Summary.order(:score => params[:order].to_sym).where(
              timeline_id: params[:timeline_id], public: true).where.not(
              user_id: user_id).page(params[:page]).per(5)
        else
          @summaries = Summary.order(:score => :desc).page(params[:page]).where(
              timeline_id: params[:timeline_id], public: true).where.not(
              user_id: user_id).page(params[:page]).per(5)
        end
      end
    end
  end

  def destroy
    summary = Summary.find(params[:id])
    if summary.user_id == current_user.id || current_user.admin
      summary.destroy_with_counters
      redirect_to my_items_items_path
    else
      flash[:danger] = "Cette synthèse est la meilleure et ne peut être supprimée."
      redirect_to summary_path(params[:id])
    end
  end

  private

  def summary_params
    params.require(:summary).permit(:timeline_id, :content, :public, :picture, :caption, :delete_picture, :has_picture )
  end
end
