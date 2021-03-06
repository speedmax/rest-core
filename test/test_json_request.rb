
require 'rest-core/test'

describe RC::JsonRequest do
  app = RC::JsonRequest.new(RC::Dry.new, true)
  env = {RC::REQUEST_HEADERS => {}, RC::REQUEST_METHOD => :post}
  request_params = {
    'key' => 'value',
    'array' => [1, 2, 3],
    'nested' => {'k' => 'v', 'a' => [4, 5, 6]}
  }

  would 'encode payload as json' do
    e = env.merge(RC::REQUEST_METHOD  => :post,
                  RC::REQUEST_PAYLOAD => request_params)

    app.call(e){ |res|
      res.should.eq(
        RC::REQUEST_METHOD  => :post,
        RC::REQUEST_HEADERS => {'Content-Type' => 'application/json'},
        RC::REQUEST_PAYLOAD => RC::Json.encode(request_params))}
  end

  would 'encode false and nil' do
    [[nil, 'null'], [false, 'false'], [true, 'true']].each do |(value, exp)|
      [:post, :put, :patch].each do |meth|
        e = env.merge(RC::REQUEST_METHOD  => meth,
                      RC::REQUEST_PAYLOAD => value)
        app.call(e){ |res| res[RC::REQUEST_PAYLOAD].should.eq(exp) }
      end
    end
  end

  would 'do nothing for get, delete, head, options' do
    [:get, :delete, :head, :options].each do |meth|
      e = env.merge(RC::REQUEST_PAYLOAD => {}, RC::REQUEST_METHOD => meth)
      app.call(e){ |res| res.should.eq e }
    end
  end

  would 'do nothing if json_request is false' do
    a = RC::JsonRequest.new(RC::Dry.new, false)
    a.call(env){ |res| res.should.eq env }
  end
end
