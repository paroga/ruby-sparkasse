require 'json'
require 'mechanize'

LOGIN_URL = 'https://login.sparkasse.at/sts/oauth/authorize?client_id=georgeclient&response_type=token'

class Sparkasse

  def self.login(*args)
    h = new(*args)
    yield h
    h.logout
  end

  def initialize(username, password)
    @agent = Mechanize.new
    @agent.redirect_ok = false

    @agent.get(LOGIN_URL)

    @agent.post(LOGIN_URL, 'j_username' => username, 'javaScript' => 'jsOK')
    loginForm = @agent.page.form_with(:name => 'anmelden')
    exponent = loginForm.field_with(:name => 'exponent').value
    modulus = loginForm.field_with(:name => 'modulus').value
    saltCode = loginForm.field_with(:name => 'saltCode').value

    rsa = OpenSSL::PKey::RSA.new
    rsa.set_key(OpenSSL::BN.new(modulus.to_i(16)), OpenSSL::BN.new(exponent.to_i(16)), nil)
    encrypted = rsa.public_encrypt("#{saltCode}\t#{password}")
    rsaEncrypted = encrypted.unpack("H*").join.upcase

    @agent.post(LOGIN_URL, 'rsaEncrypted' => rsaEncrypted, 'saltCode' => saltCode)
    uri = URI.parse(@agent.page.header['location'])
    @accessToken = URI.decode_www_form(uri.fragment).assoc('access_token').last
    @accounts = api('accounts')
  end

  def balance(iban)
    item = account iban
    return amount(item[:balance]) if item
  end

  def transactions(iban, from = '', &block)
    item = account iban
    return nil unless item

    acountId = item[:id]

    result = api("transactions?pageSize=5000&suggest=true&id=#{acountId}")

    items = []
    result[:collection].each do |item|
      break if item[:id] <= from

      text = item[:receiverReference]
      text = item[:senderReference] if text.empty?
      text = item[:subtitle] if text.empty?

      items << {
        id: item[:id],
        type: item[:bookingType],
        date: Time.at(item[:bookingDate] / 1000).to_date.to_s,
        amount: amount(item[:amount]),
        name: item[:title],
        iban: item[:partner][:iban],
        text: text
      }
    end

    items.sort_by! { |item| item[:date] }
    items.each &block
    items.last && items.last[:id]
  end

  def logout
    @agent.delete('https://api.sparkasse.at/rest/netbanking/auth/token/invalidate', nil, headers)
  end

  private

  def account(iban)
    @accounts[:collection].each do |item|
      return item if item[:accountno][:iban] == iban
    end
    nil
  end

  def amount(value)
    value[:value] / 10 ** value[:precision]
  end

  def headers
    { 'Authorization' => "bearer #{@accessToken}"}
  end

  def get(url)
    JSON.parse @agent.get(url, [], nil, headers).body, symbolize_names: true
  end

  def api(url)
    get("https://api.sparkasse.at/proxy/g/api/my/#{url}")
  end

end
