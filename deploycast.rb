require 'net/http'
require 'open-uri'
require 'active_support/inflector'
require 'active_support/core_ext/object'
require 'tempfile'

module PostTTS

  def post_data
    self.class::POST_DATA.merge({txt: text})
  end

  def download_file(&block)
    fetch self.class::URI, :post, post_data, &block
  end

end

class TTS < Struct.new(:text)

  def extension
    self.class::EXTENSION || 'mp3'
  end

  def url
    self.class::URL_TEMPLATE % URI::encode(text)
  end

  def file_name
    self.class.name.demodulize.underscore
  end

  def fetch(uri, method = :get, query = nil, &block)
    uri = URI(uri)
    request = Net::HTTP.const_get(method.to_s.classify).new(uri)
    request.set_form_data query if query
    Net::HTTP.start(uri.host) do |http|
      response = http.request request
      case response
      when Net::HTTPSuccess then
        yield response
      when Net::HTTPRedirection then
        location = response['location']
        warn "redirected to #{location}"
        new_uri = uri.dup
        new_uri.path = location
        fetch new_uri, &block
      else
        response.value
      end
    end
  end

  def download
    download_file do |file|
      open_file do |dest_file|
        dest_file.print file.body
      end
    end
    self
  end

  def download_file(&block)
    fetch url, &block
  end

  def open_file(&block)
    open(file_name + '.' + extension, "wb", &block)
  end

  class Google < TTS
    URL_TEMPLATE = "http://translate.google.com/translate_tts?ie=UTF-8&q=%s&tl=en-us"
    EXTENSION = 'mp3'
  end

  class ATT < TTS
    include PostTTS
    URI = 'http://192.20.225.36/tts/cgi-bin/nph-nvttsdemo'
    REQUEST_METHOD = :post
    POST_DATA = {voice: :claire, speakButton: 'SPEAK'}
    EXTENSION = 'wav'

    def post_data
      super.merge voice: self.class.name.demodulize.downcase
    end

    class Claire < ATT; end
    class Lauren < ATT; end
    class Crystal < ATT; end
    class Audrey < ATT; end
  end

end

class Reverberizer < Struct.new(:file)
  def reverberize

    `sox #{file.file_name}.#{file.extension} #{file.file_name}_new.#{file.extension} pad 0 3`
    # 3.times { `sox #{file.file_name}_new.#{file.extension} #{file.file_name}_new.#{file.extension} reverb 50 50 100 100 0 0` }
  end
end

classes = [TTS::Google, TTS::ATT::Audrey, TTS::ATT::Claire, TTS::ATT::Lauren, TTS::ATT::Crystal]
#classes = [TTS::Google]

classes.each do |tts|
  sound = tts.new('Stefan deployed ixly inbox to production')
  Reverberizer.new(sound.download).reverberize
end
