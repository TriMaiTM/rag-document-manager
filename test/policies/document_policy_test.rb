require "test_helper"

class DocumentPolicyTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:one)
    @document = build_document(@workspace, users(:one))
  end

  test "owner can manage document" do
    policy = DocumentPolicy.new(
      users(:one),
      @document
    )

    assert policy.index?
    assert policy.show?
    assert policy.download?
    assert policy.create?
    assert policy.destroy?
  end

  test "admin can manage document" do
    policy = DocumentPolicy.new(
      users(:three),
      @document
    )

    assert policy.index?
    assert policy.show?
    assert policy.download?
    assert policy.create?
    assert policy.destroy?
  end

  test "member can only read and download document" do
    policy = DocumentPolicy.new(
      users(:two),
      @document
    )

    assert policy.index?
    assert policy.show?
    assert policy.download?
    assert_not policy.create?
    assert_not policy.destroy?
  end

  test "outsider cannot access document" do
    policy = DocumentPolicy.new(
      users(:four),
      @document
    )

    assert_not policy.index?
    assert_not policy.show?
    assert_not policy.download?
    assert_not policy.create?
    assert_not policy.destroy?
  end

  test "scope only returns documents from joined workspaces" do
    first_document = create_document(
      workspaces(:one),
      users(:one),
      "First Workspace Document"
    )

    second_document = create_document(
      workspaces(:two),
      users(:two),
      "Second Workspace Document"
    )

    scope = DocumentPolicy::Scope.new(
      users(:one),
      Document.all
    ).resolve

    assert_includes scope, first_document
    assert_not_includes scope, second_document
  end

  private

  def build_document(workspace, uploader)
    workspace.documents.new(
      uploaded_by: uploader,
      title: "Policy Test Document"
    )
  end

  def create_document(workspace, uploader, title)
    document = workspace.documents.new(
      uploaded_by: uploader,
      title: title
    )

    document.file.attach(
      io: file_fixture("sample.pdf").open,
      filename: "#{title.parameterize}.pdf",
      content_type: "application/pdf"
    )

    document.save!
    document
  end
end
