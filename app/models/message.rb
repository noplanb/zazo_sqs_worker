class Message
  DELIVERED_STATUSES = %i(downloaded viewed).freeze
  attr_reader :file_name
  alias_method :id, :file_name

  def self.all_s3_events(options = {})
    events = Event.video_s3_uploaded
    events = events.with_sender(options.fetch(:sender_id)) if options.key?(:sender_id)
    events = events.with_receiver(options.fetch(:receiver_id)) if options.key?(:receiver_id)
    events = events.page(options.fetch(:page, 1))
    events = events.per(options.fetch(:per, 100)) if options.key?(:per)
    order = options.fetch(:reverse, false) ? 'DESC' : 'ASC'
    events.order("triggered_at #{order}")
  end

  def self.build_from_s3_events(s3_events)
    events_cache = Event.with_video_filenames(s3_events.map(&:video_filename))
                   .order(:triggered_at)
                   .group_by(&:video_filename)
    s3_events.map do |s3_event|
      Message.new(s3_event, events_cache[s3_event.video_filename])
    end.uniq(&:id)
  end

  def self.all(options = {})
    build_from_s3_events(all_s3_events(options))
  end

  # @param file_name_or_event
  # @param events
  def initialize(file_name_or_event, events = nil)
    if !file_name_or_event.is_a?(String) &&
       file_name_or_event.is_a?(Event) &&
       file_name_or_event.name != %w(video s3 uploaded)
      fail TypeError, 'value must be either file_name or video:s3:uploaded event'
    end
    if file_name_or_event.is_a?(String)
      @file_name = file_name_or_event
    else
      @s3_event = file_name_or_event
      @file_name = @s3_event.video_filename
    end
    @events ||= events
  end

  def ==(message)
    super || id == message.id
  end

  def inspect
    "#<#{self.class.name} #{file_name}>"
  end

  def s3_event
    @s3_event ||= find_s3_event
  end

  def events
    @events ||= Event.with_video_filename(file_name).order(:triggered_at)
  end

  def to_hash
    { id: id,
      sender_id: data.sender_id,
      receiver_id: data.receiver_id,
      uploaded_at: uploaded_at,
      file_name: file_name,
      file_size: file_size,
      status: status,
      delivered: delivered? }
  end

  def data
    @data ||= Hashie::Mash.new(s3_event.data)
  end

  def raw_params
    @raw_params ||= Hashie::Mash.new(s3_event.raw_params)
  end

  def uploaded_at
    s3_event.triggered_at
  end

  def file_size
    raw_params.s3.object['size']
  end

  def status
    events.last.name.last.to_sym
  end

  def delivered?
    DELIVERED_STATUSES.include?(status)
  end

  def undelivered?
    !delivered?
  end

  protected

  def find_s3_event
    s3_event = events.select { |e| e.name == %w(video s3 uploaded) }.first
    fail ActiveRecord::RecordNotFound, 'no video:s3:uploaded event found' if s3_event.blank?
    s3_event
  end
end
