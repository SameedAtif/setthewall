require "rails_helper"

RSpec.describe "Media", type: :request do
  let(:dir)  { Rails.root.join("tmp", "gemini_images") }
  let(:file) { dir.join("spec_fixture.png") }

  before do
    dir.mkpath
    File.binwrite(file, "\x89PNG\r\n\x1a\n")
  end

  after { File.delete(file) if File.exist?(file) }

  it "serves a local image under tmp" do
    get "/media/tmp/gemini_images/spec_fixture.png"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("image/png")
  end

  it "refuses image files outside the served roots" do
    get "/media/public/icon.png"

    expect(response).to have_http_status(:not_found)
  end

  it "refuses non-image files under the served roots" do
    path = Rails.root.join("tmp", "spec_not_an_image.txt")
    File.write(path, "hello")
    get "/media/tmp/spec_not_an_image.txt"

    expect(response).to have_http_status(:not_found)
  ensure
    File.delete(path) if File.exist?(path)
  end
end
