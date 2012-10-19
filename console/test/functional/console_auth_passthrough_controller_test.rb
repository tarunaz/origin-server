require File.expand_path('../../test_helper', __FILE__)

class ConsoleAuthPassthroughControllerTest < ActionController::TestCase
  uses_http_mock :sometimes

  class ConsoleAuthPassthroughController < ActionController::Base
    include Console::Rescue
    include Console::Auth::Passthrough

    before_filter :authenticate_user!, :except => :unprotected

    def protected
      render :status => 200, :nothing => true
    end
    def unprotected
      render :status => 200, :nothing => true
    end
    def restapi
      @user = User.find :one, :as => current_user
      render :status => 200, :nothing => true
    end
  end

  setup{ Rails.application.routes.draw{ match ':action' => ConsoleAuthPassthroughController } }
  teardown{ Rails.application.reload_routes! }

  setup{ Console.config.expects(:passthrough_user_header).at_least_once.returns('X-Remote-User') }
  setup{ Console.config.stubs(:passthrough_headers).returns(['X-Remote-User']) }

  tests ConsoleAuthPassthroughController

  test 'should redirect when protected' do
    get :protected
    assert_redirected_to @controller.unauthorized_path
  end

  test 'should render when protected' do
    @request.env['HTTP_X_REMOTE_USER'] = 'bob'

    get :protected

    assert_response :success
    assert assigns(:authenticated_user)
    assert_equal 'bob', @controller.current_user.login
    assert_equal 'bob', assigns(:authenticated_user).login
  end

  test 'should pass headers to REST API' do
    @request.env['HTTP_X_REMOTE_USER'] = 'bob'

    allow_http_mock
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get '/broker/rest/user.json', anonymous_json_header.merge('X-Remote-User' => 'bob'), {:login => 'foo'}.to_json
    end

    get :restapi
    assert_response :success
    assert user = assigns(:user)
    assert_equal 'foo', user.login
  end

  test 'should redirect when misconfigured' do
    @request.env['HTTP_X_REMOTE_USER'] = 'bob'

    allow_http_mock
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get '/broker/rest/user.json', anonymous_json_header.merge('X-Remote-User' => 'bob'), nil, 401
    end

    get :restapi
    assert_redirected_to  @controller.unauthorized_path
  end
end
