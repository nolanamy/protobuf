require 'spec_helper'

class FilterTest
  include Protobuf::Rpc::ServiceFilters

  attr_accessor :called

  # Initialize the hash keys as instance vars
  def initialize(ivar_hash)
    @called = []
    ivar_hash.each_pair do |key, value|
      self.class.class_eval do
        attr_accessor key
      end
      __send__("#{key}=", value)
    end
  end

  def endpoint
    @called << :endpoint
  end

  def self.clear_filters!
    @defined_filters = nil
    @filters = nil
    @rescue_filters = nil
  end
end

describe Protobuf::Rpc::ServiceFilters do
  let(:params) { {} }
  subject { FilterTest.new(params) }
  after(:each) { FilterTest.clear_filters! }

  describe '#before_filter' do
    let(:params) { { :before_filter_calls => 0 } }

    before(:all) do
      class FilterTest
        private
        def verify_before
          @called << :verify_before
          @before_filter_calls += 1
        end

        def foo
          @called << :foo
        end
      end
    end

    before do
      FilterTest.before_filter(:verify_before)
      FilterTest.before_filter(:verify_before)
      FilterTest.before_filter(:foo)
    end

    specify { subject.class.should respond_to(:before_filter) }
    specify { subject.class.should respond_to(:before_action) }

    it 'calls filters in the order they were defined' do
      subject.__send__(:run_filters, :endpoint)
      subject.called.should eq [ :verify_before, :foo, :endpoint ]
      subject.before_filter_calls.should eq 1
    end

    context 'when filter is configured with "only"' do
      before(:all) do
        class FilterTest
          private
          def endpoint_with_verify
            @called << :endpoint_with_verify
          end
        end
      end

      before do
        FilterTest.clear_filters!
        FilterTest.before_filter(:verify_before, :only => :endpoint_with_verify)
      end

      context 'when invoking a method defined in "only" option' do
        it 'invokes the filter' do
          subject.__send__(:run_filters, :endpoint_with_verify)
          subject.called.should eq [ :verify_before, :endpoint_with_verify ]
        end
      end

      context 'when invoking a method not defined by "only" option' do
        it 'does not invoke the filter' do
          subject.__send__(:run_filters, :endpoint)
          subject.called.should eq [ :endpoint ]
        end
      end
    end

    context 'when filter is configured with "except"' do
      before(:all) do
        class FilterTest
          private
          def endpoint_without_verify
            @called << :endpoint_without_verify
          end
        end
      end

      before do
        FilterTest.clear_filters!
        FilterTest.before_filter(:verify_before, :except => :endpoint_without_verify)
      end

      context 'when invoking a method not defined in "except" option' do
        it 'invokes the filter' do
          subject.__send__(:run_filters, :endpoint)
          subject.called.should eq [ :verify_before, :endpoint ]
        end
      end

      context 'when invoking a method defined by "except" option' do
        it 'does not invoke the filter' do
          subject.__send__(:run_filters, :endpoint_without_verify)
          subject.called.should eq [ :endpoint_without_verify ]
        end
      end
    end

    context 'when filter is configured with "if"' do
      before(:all) do
        class FilterTest
          private
          def check_true; return true; end
          def check_false; return false; end
          def verify_before; @called << :verify_before; end
        end
      end

      context 'when "if" option is a method that returns true' do
        before do
          FilterTest.clear_filters!
          FilterTest.before_filter(:verify_before, :if => :check_true)
        end

        it 'invokes the filter' do
          subject.__send__(:run_filters, :endpoint)
          subject.called.should eq [ :verify_before, :endpoint ]
        end
      end

      context 'when "if" option is a callable that returns true' do
        before do
          FilterTest.clear_filters!
          FilterTest.before_filter(:verify_before, :if => lambda { |service| true })
        end

        it 'invokes the filter' do
          subject.__send__(:run_filters, :endpoint)
          subject.called.should eq [ :verify_before, :endpoint ]
        end
      end

      context 'when "if" option is a method that returns false' do
        before do
          FilterTest.clear_filters!
          FilterTest.before_filter(:verify_before, :if => :check_false)
        end

        it 'skips the filter' do
          subject.__send__(:run_filters, :endpoint)
          subject.called.should eq [ :endpoint ]
        end
      end

      context 'when "if" option is a callable that returns false' do
        before do
          FilterTest.clear_filters!
          FilterTest.before_filter(:verify_before, :if => lambda { |service| false })
        end

        it 'skips the filter' do
          subject.__send__(:run_filters, :endpoint)
          subject.called.should eq [ :endpoint ]
        end
      end
    end

    context 'when filter is configured with "unless"' do
      before(:all) do
        class FilterTest
          private
          def check_true; return true; end
          def check_false; return false; end
          def verify_before; @called << :verify_before; end
        end
      end

      context 'when "unless" option is a method that returns false' do
        before do
          FilterTest.clear_filters!
          FilterTest.before_filter(:verify_before, :unless => :check_false)
        end

        it 'invokes the filter' do
          subject.__send__(:run_filters, :endpoint)
          subject.called.should eq [ :verify_before, :endpoint ]
        end
      end

      context 'when "unless" option is a callable that returns true' do
        before do
          FilterTest.clear_filters!
          FilterTest.before_filter(:verify_before, :unless => lambda { |service| false })
        end

        it 'invokes the filter' do
          subject.__send__(:run_filters, :endpoint)
          subject.called.should eq [ :verify_before, :endpoint ]
        end
      end

      context 'when "unless" option is a method that returns false' do
        before do
          FilterTest.clear_filters!
          FilterTest.before_filter(:verify_before, :unless => :check_true)
        end

        it 'skips the filter' do
          subject.__send__(:run_filters, :endpoint)
          subject.called.should eq [ :endpoint ]
        end
      end

      context 'when "unless" option is a callable that returns false' do
        before do
          FilterTest.clear_filters!
          FilterTest.before_filter(:verify_before, :unless => lambda { |service| true })
        end

        it 'skips the filter' do
          subject.__send__(:run_filters, :endpoint)
          subject.called.should eq [ :endpoint ]
        end
      end
    end

    context 'when filter returns false' do
      before(:all) do
        class FilterTest
          private
          def short_circuit_filter
            @called << :short_circuit_filter
            return false
          end
        end
      end

      before do
        FilterTest.clear_filters!
        FilterTest.before_filter(:short_circuit_filter)
      end

      it 'does not invoke the rpc method' do
        subject.should_not_receive(:endpoint)
        subject.__send__(:run_filters, :endpoint)
        subject.called.should eq [ :short_circuit_filter ]
      end
    end
  end

  describe '#after_filter' do
    let(:params) { { :after_filter_calls => 0 } }

    before(:all) do
      class FilterTest
        private
        def verify_after
          @called << :verify_after
          @after_filter_calls += 1
        end

        def foo
          @called << :foo
        end
      end
    end

    before do
      FilterTest.after_filter(:verify_after)
      FilterTest.after_filter(:verify_after)
      FilterTest.after_filter(:foo)
    end

    specify { subject.class.should respond_to(:after_filter) }
    specify { subject.class.should respond_to(:after_action) }

    it 'calls filters in the order they were defined' do
      subject.__send__(:run_filters, :endpoint)
      subject.called.should eq [ :endpoint, :verify_after, :foo ]
      subject.after_filter_calls.should eq 1
    end
  end

  describe '#around_filter' do
    let(:params) { {} }

    before(:all) do
      class FilterTest
        private
        def outer_around
          @called << :outer_around_top
          yield
          @called << :outer_around_bottom
        end

        def inner_around
          @called << :inner_around_top
          yield
          @called << :inner_around_bottom
        end
      end
    end

    before do
      FilterTest.around_filter(:outer_around)
      FilterTest.around_filter(:inner_around)
      FilterTest.around_filter(:outer_around)
      FilterTest.around_filter(:inner_around)
    end

    specify { subject.class.should respond_to(:around_filter) }
    specify { subject.class.should respond_to(:around_action) }

    it 'calls filters in the order they were defined' do
      subject.__send__(:run_filters, :endpoint)
      subject.called.should eq([ :outer_around_top,
                                 :inner_around_top,
                                 :endpoint,
                                 :inner_around_bottom,
                                 :outer_around_bottom ])
    end

    context 'when around_filter does not yield' do
      before do
        class FilterTest
          private
          def inner_around
            @called << :inner_around
          end
        end
      end

      before do
        FilterTest.around_filter(:outer_around)
        FilterTest.around_filter(:inner_around)
      end

      it 'cancels calling the rest of the filters and the endpoint' do
        subject.should_not_receive(:endpoint)
        subject.__send__(:run_filters, :endpoint)
        subject.called.should eq([ :outer_around_top,
                                   :inner_around,
                                   :outer_around_bottom ])
      end

    end
  end

  describe '#rescue_from' do
    before do
      class CustomError1 < StandardError; end
      class CustomError2 < StandardError; end
      class CustomError3 < StandardError; end
    end

    before do
      class FilterTest
        private

        def filter_with_error1
          @called << :filter_with_error1
          raise CustomError1, 'Filter 1 failed'
        end

        def filter_with_error2
          @called << :filter_with_error2
          raise CustomError1, 'Filter 2 failed'
        end

        def filter_with_error3
          @called << :filter_with_error3
          raise CustomError3, 'Filter 3 failed'
        end

        def filter_with_runtime_error
          @called << :filter_with_runtime_error
          raise RuntimeError, 'Filter with runtime error failed'
        end

        def custom_error_occurred(ex)
          @ex_class = ex.class
          @called << :custom_error_occurred
        end
      end
    end

    let(:params) { { :ex_class => nil } }

    context 'when defining multiple errors with a given callback' do
      before do
        FilterTest.rescue_from(CustomError1, CustomError2, CustomError3, :with => :custom_error_occurred)
      end
      before { FilterTest.before_filter(:filter_with_error3) }

      it 'short-circuits the call stack' do
        expect {
          subject.should_not_receive(:endpoint)
          subject.__send__(:run_filters, :endpoint)
          subject.called.should eq([ :filter_with_error3, :custom_error_occurred ])
          subject.ex_class.should eq CustomError3
        }.to_not raise_error(CustomError3)
      end
    end

    context 'when defined with options' do
      context 'when :with option is not given' do
        specify do
          expect { FilterTest.rescue_from(CustomError1) }.to raise_error(ArgumentError, /with/)
        end
      end

      context 'when error occurs inside filter' do
        before { FilterTest.rescue_from(CustomError1, :with => :custom_error_occurred) }
        before { FilterTest.before_filter(:filter_with_error1) }

        it 'short-circuits the call stack' do
          expect {
            subject.should_not_receive(:endpoint)
            subject.__send__(:run_filters, :endpoint)
            subject.called.should eq([ :filter_with_error1, :custom_error_occurred ])
            subject.ex_class.should eq CustomError1
          }.to_not raise_error(CustomError1)
        end
      end
    end

    context 'when defined with block' do
      before do
        FilterTest.rescue_from(CustomError1) do |service, ex|
          service.ex_class = ex.class
          service.called << :block_rescue_handler
        end
      end
      before { FilterTest.before_filter(:filter_with_error1) }

      it 'short-circuits the call stack' do
        expect {
          subject.should_not_receive(:endpoint)
          subject.__send__(:run_filters, :endpoint)
          subject.called.should eq([ :filter_with_error1, :block_rescue_handler ])
          subject.ex_class.should eq CustomError1
        }.to_not raise_error(CustomError1)
      end
    end

    context 'when thrown exception inherits from a mapped exception' do
      before do
        FilterTest.rescue_from(StandardError) do |service, ex|
          service.ex_class = ex.class
          service.called << :standard_error_rescue_handler
        end
      end
      before { FilterTest.before_filter(:filter_with_runtime_error) }

      it 'rescues with the given callable' do
        expect {
          subject.should_not_receive(:endpoint)
          subject.__send__(:run_filters, :endpoint)
          subject.called.should eq([ :filter_with_runtime_error, :standard_error_rescue_handler ])
          subject.ex_class.should eq RuntimeError
        }.to_not raise_error
      end
    end
  end

end
