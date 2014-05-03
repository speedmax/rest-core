
require 'thread'
require 'rest-core'

class RestCore::Promise
  include RestCore

  class Future < BasicObject
    def initialize promise, target
      @promise, @target = promise, target
    end

    def method_missing msg, *args, &block
      @promise.yield[@target].__send__(msg, *args, &block)
    end
  end

  def initialize env, k=RC.id, immediate=false, &job
    self.env       = env
    self.k         = k
    self.immediate = immediate

    self.body, self.status, self.headers,
      self.socket, self.response, self.error, = nil

    self.condv     = ConditionVariable.new
    self.mutex     = Mutex.new

    defer(&job) if job
  end

  def inspect
    "<#{self.class.name} for #{env[REQUEST_PATH]}>"
  end

  def future_body    ; Future.new(self, RESPONSE_BODY   ); end
  def future_status  ; Future.new(self, RESPONSE_STATUS ); end
  def future_headers ; Future.new(self, RESPONSE_HEADERS); end
  def future_socket  ; Future.new(self, RESPONSE_SOCKET ); end
  def future_failures; Future.new(self, FAIL)            ; end

  # called in client thread
  def defer &job
    if pool_size < 0 # negative number for blocking call
      job.call
    elsif pool_size > 0
      self.task = client_class.thread_pool.defer do
        synchronized_yield{ job.call }
      end
    else
      Thread.new{ synchronized_yield{ job.call } }
    end
    env[TIMER].on_timeout{ reject(env[TIMER].error) } if env[TIMER]
  end

  # called in client thread (client.wait)
  def wait
    # it might be awaken by some other futures!
    mutex.synchronize{ condv.wait(mutex) until !!status } unless !!status
  end

  # called in client thread (from the future (e.g. body))
  def yield
    wait
    callback
  end

  # called in requesting thread after the request is done
  def fulfill body, status, headers, socket=nil
    env[TIMER].cancel if env[TIMER]
    self.body, self.status, self.headers, self.socket =
      body, status, headers, socket
    # under ASYNC callback, should call immediately
    callback_in_async if immediate
    condv.broadcast # client or response might be waiting
  end

  # called in requesting thread if something goes wrong or timed out
  def reject error
    task.cancel if task

    self.error = if error.kind_of?(Exception)
                   error
                 else
                   Error.new(error || 'unknown')
                 end
    fulfill('', 0, {})
  end

  protected
  attr_accessor :env, :k, :immediate,
                :response, :body, :status, :headers, :socket, :error,
                :condv, :mutex, :task

  private
  # called in a new thread if pool_size == 0, otherwise from the pool
  # i.e. requesting thread
  def synchronized_yield
    mutex.synchronize{ yield }
  rescue Exception => e
    # nothing we can do here for an asynchronous exception,
    # so we just log the error
    # TODO: add error_log_method
    warn "RestCore: ERROR: #{e}\n  from #{e.backtrace.inspect}"
    reject(e)   # should never deadlock someone
  end

  # called in client thread, when yield is called
  def callback
    self.response ||= k.call(
      env.merge(RESPONSE_BODY    => body  ,
                RESPONSE_STATUS  => status,
                RESPONSE_HEADERS => headers,
                RESPONSE_SOCKET  => socket,
                FAIL             => ((env[FAIL]||[]) + [error]).compact,
                LOG              =>   env[LOG] ||[]))
  end

  # called in requesting thread, whenever the request is done
  def callback_in_async
    callback
  rescue Exception => e
    # nothing we can do here for an asynchronous exception,
    # so we just log the error
    # TODO: add error_log_method
    warn "RestCore: ERROR: #{e}\n  from #{e.backtrace.inspect}"
  end

  def client_class; env[CLIENT].class; end
  def pool_size
    @pool_size ||= if client_class.respond_to?(:pool_size)
                     client_class.pool_size
                   else
                     0
                   end
  end
end
