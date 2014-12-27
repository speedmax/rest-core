
require 'rest-core/test'

describe RC::HttpClient do
  describe 'POST Payload' do
    after do
      WebMock.reset!
    end

    client = RC::Builder.client
    client.builder.run(RC::HttpClient)
    path = 'http://example.com'
    ok   = 'OK'
    c    = client.new

    post = lambda do |payload, body|
      WebMock::API.stub_request(:post, path).
        with(:body => body).to_return(:body => ok)
      c.post(path, payload).should.eq ok
    end

    would 'post with string' do
      post['string', 'string']
    end

    would 'post with file' do
      File.open(__FILE__) do |f|
        b = f.read
        f.rewind
        post[f, b]
      end
    end

    would 'post with socket' do
      rd, wr = IO.pipe
      wr.write('socket')
      wr.close
      post[rd, 'socket']
    end

    would 'not kill the thread if error was coming from the task' do
      mock(HTTPClient).new{ raise 'boom' }.with_any_args
      c.request(RC::ASYNC => true).message.should.eq 'boom'
      Muack.verify
    end
  end
end
