class Api::V1::MetricsController < ApplicationController
  def show
    @metric = Metric.find(params[:id]).new(metric_parameters)
    if @metric.valid?
      render json: @metric.generate
    else
      render_errors @metric.errors
    end
  rescue Metric::UnknownMetric => error
    render json: { error: error.message }, status: :not_found
  end

  def index
    render json: Metric.all.map { |klass| klass.name.demodulize.underscore }
  end

  private

  def metric_parameters
    params.permit(:group_by, :user_id)
  end
end
