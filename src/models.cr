require "./cfg"
require "jennifer"
require "jennifer/adapter/postgres"

Jennifer::Config.configure do |conf|
  conf.adapter = "postgres"
  conf.logger.level = :debug
  conf.user = CFG.postgres.user
  conf.db = CFG.postgres.db
end

class Comment < Jennifer::Model::Base
  mapping(
    id: Primary64,
    name: String,
    body: String,
    article_path: String,
    article_title: String,
    ip: String?,
    ua: String?,
    time_added: Time,
    time_changed: Time?,
    reply_to: Int64?,
    user_id: Int64?,
  )
  belongs_to :parent, Comment, foreign: :reply_to
  has_many :replies, Comment, foreign: :reply_to
  has_many :subs, Subscription
  belongs_to :user, User
  alias CommentJson = Int64 | String | Bool | Time | Nil | Array(Hash(String, CommentJson))

  def dict(user = nil, raw = false, recursion = 5) : Hash(String, CommentJson)
    cmt = {
      "id"           => @id,
      "name"         => @name,
      "reply_to"     => @reply_to,
      "body"         => (raw ? @body : Util.markdown @body.as(String)),
      "time_added"   => @time_added,
      "time_changed" => @time_changed,
      "replies"      => recursion > 0 ? self.replies_query.order(time_added: :desc).to_a.map &.dict(
        user: user, raw: raw, recursion: recursion - 1) : self.replies.size.to_i64,
    } of String => CommentJson
    # If a user is provided, attach whether they're subscribed to the comment and whether it's theirs.
    if !user.nil?
      cmt["sub"] = self.subs_query.where{_user_id == user.id}.first.try &.sub || nil
      cmt["owned"] = user.id == self.user.try &.id
    end
    cmt
  end

  def summary_dict
    {
      "id"            => @id,
      "name"          => @name,
      "article_title" => @article_title,
      "link"          => "#{@article_path}?c=#{@id}#comment-section",
      "time_added"    => @time_added,
    }
  end

  # Raises exception if the comment is invalid.
  def validate
    raise UserErr.new(400, "You need a name") if self.name == ""
    raise UserErr.new(400, "Your name can't be longer than 30 characters") if self.name.size > 30
    raise UserErr.new(400, "That name is taken by a registered user.") \
       if (name_owner = User.find_by(name: self.name)) && name_owner.id != self.user.id
    # One can be missing, but not both.
    raise UserErr.new(400) if @reply_to.nil? && @article_path.nil?
  end
end

class User < Jennifer::Model::Base
  mapping(
    id: Primary64,
    email: String,
    auth: String,
    name: String?,
    pw: String?,
    disable_reset: Bool,
    admin: Bool,
    autosub: Bool,
    sub_site: Bool,
  )
  has_many :comments, Comment
  has_many :comment_subs, Subscription
  has_many :article_subs, ArticleSubscription
end

class Subscription < Jennifer::Model::Base
  mapping(
    id: Primary64,
    sub: Bool,
  )
  belongs_to :comment, Comment
  belongs_to :user, User
  def dict
    {
      "comment" => self.comment.not_nil!.summary_dict,
      "sub"     => @sub,
    }
  end
end

class ArticleSubscription < Jennifer::Model::Base
  mapping(
  id: Primary64,
  path: String,
  title: String,
  )
  belongs_to :user, User
  def dict
    {
      "path"  => @path,
      "title" => @title,
    }
  end
end
