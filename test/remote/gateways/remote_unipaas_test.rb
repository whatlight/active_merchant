require 'test_helper'

class RemoteUnipaasTest < Test::Unit::TestCase
  def setup
    @gateway = UnipaasGateway.new(fixtures(:unipaas))

    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('4000300011112220')
    @options = {
        billing_address: address,
        email: 'test@example.com',
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_with_token
    store = @gateway.store(@credit_card, @options)
    assert_success store

    response = @gateway.purchase(@amount, store.authorization, @options)
    assert_equal 'Success', response.message
  end

  def test_successful_recurring_purchase_flow_with_token
    store = @gateway.store(@credit_card, @options)
    assert_success store

    @recurring_options = {
        is_recurring: true,
    }

    initial = @gateway.purchase(@amount, store.authorization,  @options.merge(@recurring_options))
    assert_equal 'Success', initial.message

    @initial_transaction_otptions = {
        initial_transaction_id: initial.authorization,
    }

    second = @gateway.purchase(@amount, store.authorization,  @options.merge(@recurring_options).merge(@initial_transaction_otptions))
    assert_equal 'Success', second.message

    third = @gateway.purchase(@amount, store.authorization,  @options.merge(@recurring_options).merge(@initial_transaction_otptions))
    assert_equal 'Success', third.message
  end


  def test_successful_purchase_with_more_options
    options = {
        billing_address: address,
        order_id: '1',
        ip: "127.0.0.1",
        email: "joe@example.com",
        description: 'Store Purchase'

    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Decline', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Success', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Decline', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount - 1, auth.authorization)
    assert_success capture
  end

  # def test_failed_capture
  #   response = @gateway.capture(@amount, '')
  #   assert_failure response
  #   assert_equal 'REPLACE WITH FAILED REFUND MESSAGE', response.message
  # end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Success', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount - 1, purchase.authorization)
    assert_success refund
  end

  # def test_failed_refund
  #   response = @gateway.refund(@amount, '')
  #   assert_failure response
  #   assert_equal 'REPLACE WITH FAILED REFUND MESSAGE', response.message
  # end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Success', void.message
  end

  # def test_failed_void
  #   response = @gateway.void('')
  #   assert_failure response
  #   assert_equal 'REPLACE WITH FAILED VOID MESSAGE', response.message
  # end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Success}, response.message
  end

  # def test_failed_verify
  #   response = @gateway.verify(@declined_card, @options)
  #   assert_failure response
  #   assert_match %r{REPLACE WITH FAILED PURCHASE MESSAGE}, response.message
  # end

  # def test_invalid_login
  #   gateway = UnipaasGateway.new(private_key: '')
  #
  #   response = gateway.purchase(@amount, @credit_card, @options)
  #   assert_failure response
  #   assert_match %r{REPLACE WITH FAILED LOGIN MESSAGE}, response.message
  # end

  # def test_dump_transcript
  #   # This test will run a purchase transaction on your gateway
  #   # and dump a transcript of the HTTP conversation so that
  #   # you can use that transcript as a reference while
  #   # implementing your scrubbing logic.  You can delete
  #   # this helper after completing your scrub implementation.
  #   dump_transcript_and_fail(@gateway, @amount, @credit_card, @options)
  # end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:private_key], transcript)
  end

end
