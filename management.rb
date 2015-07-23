class Management
  attr_accessor :get_links_url, :post_video_url, :get_channels_url, :post_new_link, :post_new_channel, :update_link_progress
  attr_reader :test_flag, :development_flag, :production_flag

  def env_new_link
    if test_flag
      return "http://localhost:3000/api/link"
    elsif development_flag
      return "http://localhost:3000/api/link"
    elsif production_flag
      return "http://ghostify.herokuapp.com/api/link"
    end
  end

  def env_new_channel
    if test_flag
      return "http://localhost:3000/api/channels/create"
    elsif development_flag
      return "http://localhost:3000/api/channels/create"
    elsif production_flag
      return "http://ghostify.herokuapp.com/api/channels/create"
    end
  end

  def env_untouched_links
    if test_flag
      return "http://localhost:3000/links/untouched"
    elsif development_flag
      return "http://localhost:3000/links/untouched"
    elsif production_flag
      return "http://ghostify.herokuapp.com/links/untouched"
    end
  end

  def env_untouched_channels
    if test_flag
      return "http://ghostify.herokuapp.com/channels/untouched"
    elsif development_flag
      return "http://localhost:3000/channels/untouched"
    elsif production_flag
      return "http://ghostify.herokuapp.com/channels/untouched"
    end
  end

  def env_update_link
    if development_flag
      return "http://localhost:3000/links/progress/update"
    elsif test_flag
      return "http://localhost:3000/links/progress/update"
    elsif production_flag
      return "http://ghostify.herokuapp.com/links/progress/update"
    end
  end

  def env_post_vid
    if development_flag
      return "http://localhost:3001/elastic/create"
    elsif test_flag
      return "http://localhost:3001/elastic/create"
    elsif production_flag
      return "http://104.236.65.251:3001/elastic/create"
    end
  end

  def initialize(env)
    @development_flag = false
    @production_flag = false
    @test_flag = false

    if env
      if env.include? "dev"
        @development_flag = true
      elsif env.include? "prod"
        @production_flag = true
      elsif env.include? "test"
        @test_flag = true
      end
    else
      @development_flag = true
    end


    @get_links_url = env_untouched_links
    @post_video_url = env_post_vid
    @get_channels_url = env_untouched_channels
    @post_new_link = env_new_link
    @post_new_channel = env_new_channel
    @update_link_progress = env_update_link
  end

  private

  attr_writer :test_flag, :development_flag_flag, :production_flag

end
